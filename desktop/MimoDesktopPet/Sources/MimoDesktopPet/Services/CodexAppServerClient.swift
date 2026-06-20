import Darwin
import Foundation
import MimoDesktopPetCore

final class CodexAppServerClient {
    var onStateSnapshot: ((CodexStateSnapshot) -> Void)?
    var onConnectionState: ((Bool) -> Void)?

    private enum RequestKind {
        case initialize
        case loadedList
        case threadList
        case threadRead(threadId: String)
    }

    private enum DaemonStartResult {
        case available
        case unavailable
    }

    private let queue = DispatchQueue(label: "MimoDesktopPet.CodexAppServerClient")
    private let decoder = JSONDecoder()
    private let invocation = CodexCommandLocator.resolve()
    private var proxyProcess: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var proxyIsRunning = false
    private var outgoingFraming: CodexJSONRPCStreamParser.Framing = .jsonLines
    private var streamParser = CodexJSONRPCStreamParser()
    private var nextRequestId = 1
    private var pendingRequests: [Int: RequestKind] = [:]
    private var selectedThreadId: String?
    private var latestThreadStatus: CodexThreadStatus?
    private var latestTurnStatus: CodexTurnStatus?
    private var hasRecentAssistantFinal = false
    private var threadTitlesById: [String: String] = [:]
    private var conversationByThread: [String: [CodexConversationLine]] = [:]
    private var threadActivityById: [String: CodexConversationLine] = [:]
    private var threadStatusesById: [String: CodexThreadStatus] = [:]
    private var threadTurnStatusesById: [String: CodexTurnStatus] = [:]
    private var threadAssistantFinalById: [String: Bool] = [:]
    private var threadDisplayOrder: [String] = []
    private var loadedThreadIds: [String] = []
    private var listedThreadIds: [String] = []
    private var suppressedThreadIds = Set<String>()
    private var offlineBubbleText: String?
    private var pollTimer: DispatchSourceTimer?
    private var handshakeTimer: DispatchSourceTimer?

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked()
            self.onConnectionState?(false)
            switch self.startDaemonBestEffort() {
            case .available:
                self.startAppServerStdio()
            case .unavailable:
                self.startAppServerStdio()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func startDaemonBestEffort() -> DaemonStartResult {
        let process = Process()
        let stderr = Pipe()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.argumentsPrefix + ["app-server", "daemon", "start"]
        process.environment = CodexCommandLocator.launchEnvironment()
        process.standardOutput = Pipe()
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .available
            }
            return .unavailable
        } catch {
            return .unavailable
        }
    }

    private func startAppServerStdio() {
        let process = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()

        process.executableURL = invocation.executableURL
        process.arguments = invocation.argumentsPrefix + ["app-server", "--stdio"]
        process.environment = CodexCommandLocator.launchEnvironment()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { [weak self, weak process] _ in
            self?.queue.async {
                guard let process, self?.proxyProcess === process else { return }
                self?.transitionToOfflineLocked(terminateProxy: false, offlineBubbleText: "Codex 接続切れ")
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async {
                self?.consumeOutput(data)
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try process.run()
            proxyProcess = process
            stdinPipe = stdin
            stdoutPipe = stdout
            stderrPipe = stderr
            proxyIsRunning = true
            outgoingFraming = .jsonLines
            streamParser.reset()
            sendInitialize()
            startHandshakeTimeout()
        } catch {
            transitionToOfflineLocked(terminateProxy: false, offlineBubbleText: "Codex 接続待ち")
        }
    }

    private func stopLocked() {
        clearProxyLocked(terminate: true)
        resetThreadTrackingLocked()
    }

    private func transitionToOfflineLocked(terminateProxy: Bool, offlineBubbleText: String?) {
        clearProxyLocked(terminate: terminateProxy)
        resetThreadTrackingLocked()
        self.offlineBubbleText = offlineBubbleText
        onConnectionState?(false)
        emitSnapshot(connectionAvailable: false)
    }

    private func clearProxyLocked(terminate: Bool) {
        handshakeTimer?.cancel()
        handshakeTimer = nil
        pollTimer?.cancel()
        pollTimer = nil

        proxyProcess?.terminationHandler = nil
        if terminate, proxyProcess?.isRunning == true {
            proxyProcess?.terminate()
        }
        proxyProcess = nil
        proxyIsRunning = false
        stdinPipe = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe = nil
        streamParser.reset()
        outgoingFraming = .jsonLines
        pendingRequests.removeAll()
    }

    private func resetThreadTrackingLocked() {
        selectedThreadId = nil
        latestThreadStatus = nil
        latestTurnStatus = nil
        hasRecentAssistantFinal = false
        threadTitlesById.removeAll()
        conversationByThread.removeAll()
        threadActivityById.removeAll()
        threadStatusesById.removeAll()
        threadTurnStatusesById.removeAll()
        threadAssistantFinalById.removeAll()
        threadDisplayOrder.removeAll()
        loadedThreadIds.removeAll()
        listedThreadIds.removeAll()
        suppressedThreadIds.removeAll()
    }

    private func startHandshakeTimeout() {
        handshakeTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5.0)
        timer.setEventHandler { [weak self] in
            guard let self, self.handshakeTimer != nil else { return }
            self.transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続タイムアウト")
        }
        timer.resume()
        handshakeTimer = timer
    }

    private func cancelHandshakeTimeout() {
        handshakeTimer?.cancel()
        handshakeTimer = nil
    }

    private func startPolling() {
        pollTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2.0, repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.refreshVisibleThreads()
        }
        timer.resume()
        pollTimer = timer
    }

    private func refreshVisibleThreads() {
        sendRequest(method: "thread/loaded/list", params: ["limit": 10], kind: .loadedList)
    }

    private func sendInitialize() {
        sendRequest(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "mimo_desktop_pet",
                    "title": "Mimo Desktop Pet",
                    "version": "0.1.0"
                ],
                "capabilities": [
                    "experimentalApi": true
                ]
            ],
            kind: .initialize
        )
    }

    private func sendRequest(method: String, params: [String: Any], kind: RequestKind) {
        let id = nextRequestId
        nextRequestId += 1
        pendingRequests[id] = kind
        writeJSONObject(["method": method, "id": id, "params": params])
    }

    private func sendNotification(method: String, params: [String: Any]? = nil) {
        var object: [String: Any] = ["method": method]
        if let params {
            object["params"] = params
        }
        writeJSONObject(object)
    }

    private func writeJSONObject(_ object: [String: Any]) {
        guard
            proxyIsRunning,
            proxyProcess?.isRunning == true,
            let stdinPipe
        else {
            transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            let framedData: Data
            switch outgoingFraming {
            case .jsonLines:
                var lineData = data
                lineData.append(0x0A)
                framedData = lineData
            case .contentLength:
                let header = "Content-Length: \(data.count)\r\n\r\n"
                guard var contentLengthData = header.data(using: .utf8) else {
                    transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
                    return
                }
                contentLengthData.append(data)
                framedData = contentLengthData
            case .undecided:
                var lineData = data
                lineData.append(0x0A)
                framedData = lineData
            }
            guard writeData(framedData, to: stdinPipe.fileHandleForWriting.fileDescriptor) else {
                transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
                return
            }
        } catch {
            transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
        }
    }

    private func writeData(_ data: Data, to fileDescriptor: Int32) -> Bool {
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return true }
            var offset = 0

            while offset < buffer.count {
                let written = Darwin.write(fileDescriptor, baseAddress.advanced(by: offset), buffer.count - offset)
                if written > 0 {
                    offset += Int(written)
                    continue
                }

                if written == -1, errno == EINTR {
                    continue
                }

                return false
            }

            return true
        }
    }

    private func consumeOutput(_ data: Data) {
        do {
            let messages = try streamParser.append(data)
            if streamParser.framing == .contentLength {
                outgoingFraming = .contentLength
            }
            for message in messages where !message.isEmpty {
                handleLine(message)
            }
        } catch {
            transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
        }
    }

    private func handleLine(_ data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }

        if let method = object["method"] as? String {
            handleNotification(method: method, params: object["params"])
            return
        }

        guard let id = object["id"] as? Int else { return }
        let kind = pendingRequests.removeValue(forKey: id)
        guard object["error"] == nil else {
            if !isInitializeRequest(kind) {
                emitSnapshot(connectionAvailable: false)
            }
            return
        }
        handleResponse(kind: kind, result: object["result"])
    }

    private func handleResponse(kind: RequestKind?, result: Any?) {
        guard let kind else { return }
        switch kind {
        case .initialize:
            cancelHandshakeTimeout()
            onConnectionState?(true)
            sendNotification(method: "initialized")
            sendRequest(method: "thread/loaded/list", params: ["limit": 10], kind: .loadedList)
            startPolling()
        case .loadedList:
            handleLoadedList(result)
        case .threadList:
            handleThreadList(result)
        case .threadRead(let threadId):
            handleThreadRead(result, expectedThreadId: threadId)
        }
    }

    private func isInitializeRequest(_ kind: RequestKind?) -> Bool {
        if case .initialize = kind {
            return true
        }
        return false
    }

    private func handleLoadedList(_ result: Any?) {
        guard
            let dict = result as? [String: Any],
            let ids = dict["data"] as? [String]
        else {
            loadedThreadIds.removeAll()
            pruneThreadTracking(keeping: currentVisibleThreadIds())
            sendRequest(method: "thread/list", params: ["limit": 4, "archived": false], kind: .threadList)
            return
        }

        loadedThreadIds = Array(ids.prefix(4))
        if let first = loadedThreadIds.first, selectedThreadId == nil || !currentVisibleThreadIds().contains(selectedThreadId ?? "") {
            selectedThreadId = first
        }
        rememberThreadOrder(loadedThreadIds)
        pruneThreadTracking(keeping: currentVisibleThreadIds())
        for id in loadedThreadIds {
            sendThreadRead(threadId: id)
        }
        sendRequest(method: "thread/list", params: ["limit": 4, "archived": false], kind: .threadList)
    }

    private func handleThreadList(_ result: Any?) {
        guard
            let dict = result as? [String: Any],
            let threads = dict["data"] as? [[String: Any]]
        else {
            listedThreadIds.removeAll()
            pruneThreadTracking(keeping: currentVisibleThreadIds())
            latestThreadStatus = nil
            latestTurnStatus = nil
            hasRecentAssistantFinal = false
            emitSnapshot(connectionAvailable: true)
            return
        }

        let visibleThreads = Array(threads.prefix(4))
        listedThreadIds = visibleThreads.compactMap { $0["id"] as? String }
        rememberThreadOrder(listedThreadIds)
        pruneThreadTracking(keeping: currentVisibleThreadIds())

        guard !visibleThreads.isEmpty else {
            latestThreadStatus = nil
            latestTurnStatus = nil
            hasRecentAssistantFinal = false
            emitSnapshot(connectionAvailable: true)
            return
        }

        for thread in visibleThreads {
            guard let id = thread["id"] as? String else { continue }
            let title = threadTitle(from: thread)
            threadTitlesById[id] = title
            let lines = CodexConversationExtractor.lines(from: thread)
            if !lines.isEmpty {
                conversationByThread[id] = lines
            }
            if let snapshot = decodeThreadSnapshot(from: thread) {
                updateThreadActivity(
                    threadId: snapshot.id,
                    title: title,
                    threadStatus: snapshot.status,
                    latestTurnStatus: snapshot.turns.last?.status,
                    hasRecentAssistantFinal: snapshot.turns.last?.status == .completed
                )
            }
        }

        selectedThreadId = selectedThreadId.flatMap { currentVisibleThreadIds().contains($0) ? $0 : nil } ?? listedThreadIds.first ?? loadedThreadIds.first
        if let first = visibleThreads.first,
           selectedThreadId == first["id"] as? String,
           let snapshot = decodeThreadSnapshot(from: first) {
            apply(snapshot: snapshot)
        }
        for thread in visibleThreads {
            guard let id = thread["id"] as? String else { continue }
            sendThreadRead(threadId: id)
        }
    }

    private func handleThreadRead(_ result: Any?, expectedThreadId: String) {
        guard !suppressedThreadIds.contains(expectedThreadId) else {
            emitSnapshot(connectionAvailable: true)
            return
        }
        guard
            let dict = result as? [String: Any],
            let threadObject = dict["thread"] as? [String: Any],
            let snapshot = decodeThreadSnapshot(from: threadObject)
        else {
            emitSnapshot(connectionAvailable: true)
            return
        }

        let title = threadTitle(from: threadObject)
        threadTitlesById[snapshot.id] = title
        rememberThreadOrder([snapshot.id])
        let lines = CodexConversationExtractor.lines(from: threadObject)
        if !lines.isEmpty {
            conversationByThread[snapshot.id] = lines
        }
        updateThreadActivity(
            threadId: snapshot.id,
            title: title,
            threadStatus: snapshot.status,
            latestTurnStatus: snapshot.turns.last?.status,
            hasRecentAssistantFinal: snapshot.turns.last?.status == .completed
        )

        if selectedThreadId == nil {
            selectedThreadId = snapshot.id
        }
        if selectedThreadId == snapshot.id {
            apply(snapshot: snapshot)
        } else {
            emitSnapshot(connectionAvailable: true)
        }
    }

    private func handleNotification(method: String, params: Any?) {
        guard let method = CodexNotificationMethod(rawValue: method) else { return }

        switch method {
        case .threadStatusChanged:
            if let payload = decodeNotificationParams(ThreadStatusChangedNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                selectedThreadId = selectedThreadId ?? payload.threadId
                rememberThreadOrder([payload.threadId])
                sendThreadRead(threadId: payload.threadId)
                if selectedThreadId == payload.threadId {
                    latestThreadStatus = payload.status
                    if case .systemError = payload.status {
                        latestTurnStatus = .failed
                        hasRecentAssistantFinal = false
                    }
                }
                updateThreadActivity(
                    threadId: payload.threadId,
                    title: threadTitlesById[payload.threadId] ?? "Codex Thread",
                    threadStatus: payload.status,
                    latestTurnStatus: threadTurnStatusesById[payload.threadId],
                    hasRecentAssistantFinal: threadAssistantFinalById[payload.threadId] ?? false
                )
                emitSnapshot(connectionAvailable: true)
            }
        case .threadNameUpdated:
            if let payload = decodeNotificationParams(ThreadNameUpdatedNotification.self, from: params) {
                let title = CodexThreadTitleFormatter.title(from: [payload.threadName, "Codex Thread"])
                retitleThread(threadId: payload.threadId, title: title)
                sendThreadRead(threadId: payload.threadId)
                emitSnapshot(connectionAvailable: true)
            }
        case .threadArchived, .threadClosed, .threadDeleted:
            if let payload = decodeNotificationParams(ThreadIdNotification.self, from: params) {
                removeThreadTracking(threadId: payload.threadId, suppressPendingReads: true)
                emitSnapshot(connectionAvailable: true)
            }
        case .threadUnarchived:
            if let payload = decodeNotificationParams(ThreadIdNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                rememberThreadOrder([payload.threadId])
                sendThreadRead(threadId: payload.threadId)
                emitSnapshot(connectionAvailable: true)
            }
        case .turnStarted:
            if let payload = decodeNotificationParams(TurnNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                selectedThreadId = payload.threadId
                rememberThreadOrder([payload.threadId])
                latestTurnStatus = .inProgress
                hasRecentAssistantFinal = false
                updateThreadActivity(
                    threadId: payload.threadId,
                    title: threadTitlesById[payload.threadId] ?? "Codex Thread",
                    threadStatus: threadStatusesById[payload.threadId] ?? .active(activeFlags: []),
                    latestTurnStatus: .inProgress,
                    hasRecentAssistantFinal: false
                )
                sendThreadRead(threadId: payload.threadId)
                emitSnapshot(connectionAvailable: true)
            }
        case .turnCompleted:
            if let payload = decodeNotificationParams(TurnNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                selectedThreadId = payload.threadId
                rememberThreadOrder([payload.threadId])
                latestTurnStatus = payload.turn.status
                hasRecentAssistantFinal = payload.turn.status == .completed
                updateThreadActivity(
                    threadId: payload.threadId,
                    title: threadTitlesById[payload.threadId] ?? "Codex Thread",
                    threadStatus: threadStatusesById[payload.threadId],
                    latestTurnStatus: payload.turn.status,
                    hasRecentAssistantFinal: payload.turn.status == .completed
                )
                sendThreadRead(threadId: payload.threadId)
                emitSnapshot(connectionAvailable: true)
            }
        case .turnPlanUpdated:
            appendProgressLine(from: params, kind: "turnPlanUpdated")
        case .itemStarted:
            if let dict = params as? [String: Any],
               let threadId = dict["threadId"] as? String {
                suppressedThreadIds.remove(threadId)
                selectedThreadId = selectedThreadId ?? threadId
                appendConversationLine(from: dict["item"], threadId: threadId)
                sendThreadRead(threadId: threadId)
                guard selectedThreadId == threadId else {
                    emitSnapshot(connectionAvailable: true)
                    return
                }
                latestTurnStatus = .inProgress
                hasRecentAssistantFinal = false
                emitSnapshot(connectionAvailable: true)
            }
        case .itemCompleted:
            if let dict = params as? [String: Any],
               let threadId = dict["threadId"] as? String {
                suppressedThreadIds.remove(threadId)
                selectedThreadId = selectedThreadId ?? threadId
                appendConversationLine(from: dict["item"], threadId: threadId)
                sendThreadRead(threadId: threadId)
                guard selectedThreadId == threadId else {
                    emitSnapshot(connectionAvailable: true)
                    return
                }
                if itemLooksLikeAssistantFinal(dict["item"]) {
                    hasRecentAssistantFinal = true
                }
                emitSnapshot(connectionAvailable: true)
            }
        case .agentMessageDelta:
            appendProgressLine(from: params, kind: "agentMessageDelta")
        case .planDelta:
            appendProgressLine(from: params, kind: "planDelta")
        case .reasoningSummaryPartAdded, .reasoningSummaryTextDelta, .reasoningTextDelta:
            appendProgressLine(from: params, kind: "reasoningDelta")
        case .commandExecutionOutputDelta:
            appendProgressLine(from: params, kind: "commandExecutionOutputDelta")
        case .fileChangeOutputDelta:
            appendProgressLine(from: params, kind: "fileChangeOutputDelta")
        case .mcpToolCallProgress:
            appendProgressLine(from: params, kind: "mcpToolCallProgress")
        }
    }

    private func sendThreadRead(threadId: String) {
        sendRequest(
            method: "thread/read",
            params: ["threadId": threadId, "includeTurns": true],
            kind: .threadRead(threadId: threadId)
        )
    }

    private func decodeThreadSnapshot(from object: [String: Any]) -> CodexThreadSnapshot? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? decoder.decode(CodexThreadSnapshot.self, from: data)
    }

    private func decodeNotificationParams<T: Decodable>(_ type: T.Type, from params: Any?) -> T? {
        guard
            let params,
            JSONSerialization.isValidJSONObject(params),
            let data = try? JSONSerialization.data(withJSONObject: params)
        else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }

    private func apply(snapshot: CodexThreadSnapshot) {
        latestThreadStatus = snapshot.status
        latestTurnStatus = snapshot.turns.last?.status
        hasRecentAssistantFinal = snapshot.turns.last?.status == .completed
        emitSnapshot(connectionAvailable: true)
    }

    private func updateThreadActivity(
        threadId: String,
        title: String,
        threadStatus: CodexThreadStatus?,
        latestTurnStatus: CodexTurnStatus?,
        hasRecentAssistantFinal: Bool
    ) {
        if let threadStatus {
            threadStatusesById[threadId] = threadStatus
        }
        if let latestTurnStatus {
            threadTurnStatusesById[threadId] = latestTurnStatus
        } else {
            threadTurnStatusesById.removeValue(forKey: threadId)
        }
        threadAssistantFinalById[threadId] = hasRecentAssistantFinal

        if let line = CodexConversationExtractor.statusLine(
            threadId: threadId,
            threadTitle: title,
            threadStatus: threadStatus,
            latestTurnStatus: latestTurnStatus,
            hasRecentAssistantFinal: hasRecentAssistantFinal
        ) {
            threadActivityById[threadId] = line
        } else {
            threadActivityById.removeValue(forKey: threadId)
        }
    }

    private func emitSnapshot(connectionAvailable: Bool) {
        cancelHandshakeTimeout()
        onStateSnapshot?(
            CodexStateSnapshot(
                threadStatus: latestThreadStatus,
                latestTurnStatus: latestTurnStatus,
                hasRecentAssistantFinal: hasRecentAssistantFinal,
                connectionAvailable: connectionAvailable,
                offlineBubbleText: connectionAvailable ? nil : offlineBubbleText,
                conversationLines: connectionAvailable ? combinedConversationLines() : [],
                focusedConversationLine: connectionAvailable ? focusedConversationLine() : nil
            )
        )
    }

    private func rememberThreadOrder(_ ids: [String]) {
        for id in ids {
            suppressedThreadIds.remove(id)
            threadDisplayOrder.removeAll { $0 == id }
            threadDisplayOrder.append(id)
        }
        if threadDisplayOrder.count > 6 {
            threadDisplayOrder = Array(threadDisplayOrder.suffix(6))
        }
    }

    private func currentVisibleThreadIds() -> Set<String> {
        Set(loadedThreadIds + listedThreadIds)
    }

    private func pruneThreadTracking(keeping ids: Set<String>) {
        guard !ids.isEmpty else {
            threadTitlesById.removeAll()
            conversationByThread.removeAll()
            threadActivityById.removeAll()
            threadStatusesById.removeAll()
            threadTurnStatusesById.removeAll()
            threadAssistantFinalById.removeAll()
            threadDisplayOrder.removeAll()
            selectedThreadId = nil
            latestThreadStatus = nil
            latestTurnStatus = nil
            hasRecentAssistantFinal = false
            return
        }

        threadTitlesById = threadTitlesById.filter { ids.contains($0.key) }
        conversationByThread = conversationByThread.filter { ids.contains($0.key) }
        threadActivityById = threadActivityById.filter { ids.contains($0.key) }
        threadStatusesById = threadStatusesById.filter { ids.contains($0.key) }
        threadTurnStatusesById = threadTurnStatusesById.filter { ids.contains($0.key) }
        threadAssistantFinalById = threadAssistantFinalById.filter { ids.contains($0.key) }
        threadDisplayOrder = threadDisplayOrder.filter { ids.contains($0) }
        if let selectedThreadId, !ids.contains(selectedThreadId) {
            self.selectedThreadId = threadDisplayOrder.last ?? ids.first
            latestThreadStatus = nil
            latestTurnStatus = nil
            hasRecentAssistantFinal = false
        }
    }

    private func removeThreadTracking(threadId: String, suppressPendingReads: Bool) {
        if suppressPendingReads {
            suppressedThreadIds.insert(threadId)
        }
        loadedThreadIds.removeAll { $0 == threadId }
        listedThreadIds.removeAll { $0 == threadId }
        threadTitlesById.removeValue(forKey: threadId)
        conversationByThread.removeValue(forKey: threadId)
        threadActivityById.removeValue(forKey: threadId)
        threadStatusesById.removeValue(forKey: threadId)
        threadTurnStatusesById.removeValue(forKey: threadId)
        threadAssistantFinalById.removeValue(forKey: threadId)
        threadDisplayOrder.removeAll { $0 == threadId }
        if selectedThreadId == threadId {
            selectedThreadId = threadDisplayOrder.last
            latestThreadStatus = nil
            latestTurnStatus = nil
            hasRecentAssistantFinal = false
        }
    }

    private func retitleThread(threadId: String, title: String) {
        threadTitlesById[threadId] = title
        if let lines = conversationByThread[threadId] {
            conversationByThread[threadId] = lines.map { line in
                CodexConversationLine(
                    threadId: line.threadId,
                    threadTitle: title,
                    speaker: line.speaker,
                    text: line.text,
                    isAssistant: line.isAssistant
                )
            }
        }
        if let activity = threadActivityById[threadId] {
            threadActivityById[threadId] = CodexConversationLine(
                threadId: activity.threadId,
                threadTitle: title,
                speaker: activity.speaker,
                text: activity.text,
                isAssistant: activity.isAssistant
            )
        }
    }

    private func combinedConversationLines() -> [CodexConversationLine] {
        let orderedLines = threadDisplayOrder.flatMap { threadId in
            var lines = Array((conversationByThread[threadId] ?? []).suffix(3))
            if let activity = threadActivityById[threadId] {
                lines.append(activity)
            }
            return lines
        }
        return Array(orderedLines.suffix(12))
    }

    private func focusedConversationLine() -> CodexConversationLine? {
        CodexConversationFocus.select(
            from: combinedConversationLines(),
            preferredThreadId: selectedThreadId
        )
    }

    private func appendConversationLine(from item: Any?, threadId: String) {
        guard let item = item as? [String: Any] else { return }
        let title = threadTitlesById[threadId] ?? "Codex Thread"
        guard let line = CodexConversationExtractor.line(from: item, threadId: threadId, threadTitle: title) else { return }
        var lines = conversationByThread[threadId] ?? []
        lines.append(line)
        conversationByThread[threadId] = Array(lines.suffix(6))
        rememberThreadOrder([threadId])
        updateThreadActivity(
            threadId: threadId,
            title: title,
            threadStatus: threadStatusesById[threadId] ?? .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )
    }

    private func appendProgressLine(from params: Any?, kind: String) {
        guard let dict = params as? [String: Any],
              let threadId = dict["threadId"] as? String
        else { return }

        selectedThreadId = selectedThreadId ?? threadId
        let title = threadTitlesById[threadId] ?? "Codex Thread"
        let line = CodexConversationExtractor.progressLine(
            threadId: threadId,
            threadTitle: title,
            kind: kind
        )
        var lines = conversationByThread[threadId] ?? []
        lines.append(line)
        conversationByThread[threadId] = Array(lines.suffix(6))
        rememberThreadOrder([threadId])
        latestTurnStatus = .inProgress
        hasRecentAssistantFinal = false
        updateThreadActivity(
            threadId: threadId,
            title: title,
            threadStatus: threadStatusesById[threadId] ?? .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )
        emitSnapshot(connectionAvailable: true)
    }

    private func threadTitle(from threadObject: [String: Any]) -> String {
        CodexThreadTitleFormatter.title(from: [
            threadObject["name"],
            threadObject["preview"],
            "Codex Thread"
        ])
    }

    private func itemLooksLikeAssistantFinal(_ item: Any?) -> Bool {
        guard let item = item as? [String: Any] else { return false }
        let type = item["type"] as? String
        if type == "agentMessage" || type == "agent_message" {
            return true
        }
        if type == "message", item["role"] as? String == "assistant" {
            return true
        }
        return false
    }
}
