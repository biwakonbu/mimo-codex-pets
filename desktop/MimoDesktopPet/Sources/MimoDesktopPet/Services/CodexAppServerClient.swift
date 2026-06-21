import Darwin
import Foundation
import MimoDesktopPetCore

final class CodexAppServerClient {
    var onStateSnapshot: ((CodexStateSnapshot) -> Void)?
    var onConnectionState: ((Bool) -> Void)?

    private enum ThreadContext {
        static let requestLimit = 6
        static let loadedRequestLimit = 10
        static let notificationTrackingTTLSeconds = 30.0
    }

    private enum RequestKind {
        case initialize
        case loadedList
        case threadList
        case threadRead(threadId: String)
    }

    private struct PendingRequest {
        let kind: RequestKind
        let sentAt: DispatchTime
    }

    private enum ThreadReadReason {
        case refresh
        case notification
    }

    private enum DaemonStartResult {
        case available
        case unavailable
    }

    private enum AppServerTransportMode {
        case proxy
        case stdio

        var arguments: [String] {
            switch self {
            case .proxy:
                return ["app-server", "proxy"]
            case .stdio:
                return ["app-server", "--stdio"]
            }
        }
    }

    private let queue = DispatchQueue(label: "MimoDesktopPet.CodexAppServerClient")
    private let decoder = JSONDecoder()
    private let invocation = CodexCommandLocator.resolve()
    private let requestTimeoutSeconds = CodexAppServerClient.requestTimeoutInterval()
    private let reconnectDelaySeconds = CodexAppServerClient.reconnectDelayInterval()
    private let daemonStartTimeoutSeconds = CodexAppServerClient.daemonStartTimeoutInterval()
    private var proxyProcess: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var proxyIsRunning = false
    private var currentTransportMode: AppServerTransportMode?
    private var transportInitialized = false
    private var outgoingFraming: CodexJSONRPCStreamParser.Framing = .jsonLines
    private var streamParser = CodexJSONRPCStreamParser()
    private var nextRequestId = 1
    private var pendingRequests: [Int: PendingRequest] = [:]
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
    private var notificationThreadLastSeenById: [String: DispatchTime] = [:]
    private var loadedThreadIds: [String] = []
    private var listedThreadIds: [String] = []
    private var suppressedThreadIds = Set<String>()
    private var threadReadIdsInRefreshCycle = Set<String>()
    private var offlineBubbleText: String?
    private var pollTimer: DispatchSourceTimer?
    private var handshakeTimer: DispatchSourceTimer?
    private var requestTimeoutTimer: DispatchSourceTimer?
    private var reconnectTimer: DispatchSourceTimer?
    private var shouldReconnect = false

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = true
            self.cancelReconnectLocked()
            self.clearProxyLocked(terminate: true)
            self.resetThreadTrackingLocked()
            self.onConnectionState?(false)
            self.connectLocked()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.shouldReconnect = false
            self?.stopLocked()
        }
    }

    private func connectLocked() {
        cancelReconnectLocked()
        switch startDaemonBestEffort() {
        case .available:
            startAppServerTransport(.proxy)
        case .unavailable:
            startAppServerTransport(.stdio)
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
            let deadline = Date().addingTimeInterval(daemonStartTimeoutSeconds)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.025)
            }
            if process.isRunning {
                process.terminate()
                let killDeadline = Date().addingTimeInterval(0.2)
                while process.isRunning && Date() < killDeadline {
                    Thread.sleep(forTimeInterval: 0.025)
                }
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                return .unavailable
            }
            if process.terminationStatus == 0 {
                return .available
            }
            return .unavailable
        } catch {
            return .unavailable
        }
    }

    private func startAppServerTransport(_ mode: AppServerTransportMode) {
        let process = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()

        process.executableURL = invocation.executableURL
        process.arguments = invocation.argumentsPrefix + mode.arguments
        process.environment = CodexCommandLocator.launchEnvironment()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { [weak self, weak process] _ in
            self?.queue.async {
                guard let self, let process, self.proxyProcess === process else { return }
                self.handleAppServerTerminationLocked(process: process, mode: mode)
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
            currentTransportMode = mode
            transportInitialized = false
            outgoingFraming = .jsonLines
            streamParser.reset()
            startRequestTimeoutWatchdog()
            sendInitialize()
            startHandshakeTimeout()
        } catch {
            if mode == .proxy {
                startAppServerTransport(.stdio)
            } else {
                transitionToOfflineLocked(terminateProxy: false, offlineBubbleText: "Codex 接続待ち")
            }
        }
    }

    private func handleAppServerTerminationLocked(process: Process, mode: AppServerTransportMode) {
        guard proxyProcess === process else { return }
        if mode == .proxy, !transportInitialized, shouldReconnect {
            fallbackToDirectStdioLocked()
        } else {
            transitionToOfflineLocked(terminateProxy: false, offlineBubbleText: "Codex 接続切れ")
        }
    }

    private func fallbackToDirectStdioLocked() {
        guard shouldReconnect else { return }
        clearProxyLocked(terminate: true)
        startAppServerTransport(.stdio)
    }

    private func stopLocked() {
        cancelReconnectLocked()
        clearProxyLocked(terminate: true)
        resetThreadTrackingLocked()
    }

    private func transitionToOfflineLocked(terminateProxy: Bool, offlineBubbleText: String?) {
        clearProxyLocked(terminate: terminateProxy)
        resetThreadTrackingLocked()
        self.offlineBubbleText = offlineBubbleText
        onConnectionState?(false)
        emitSnapshot(connectionAvailable: false)
        scheduleReconnectLocked()
    }

    private func clearProxyLocked(terminate: Bool) {
        handshakeTimer?.cancel()
        handshakeTimer = nil
        pollTimer?.cancel()
        pollTimer = nil
        requestTimeoutTimer?.cancel()
        requestTimeoutTimer = nil

        proxyProcess?.terminationHandler = nil
        if terminate, proxyProcess?.isRunning == true {
            proxyProcess?.terminate()
        }
        proxyProcess = nil
        proxyIsRunning = false
        currentTransportMode = nil
        transportInitialized = false
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
        notificationThreadLastSeenById.removeAll()
        loadedThreadIds.removeAll()
        listedThreadIds.removeAll()
        suppressedThreadIds.removeAll()
        threadReadIdsInRefreshCycle.removeAll()
    }

    private func startHandshakeTimeout() {
        handshakeTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5.0)
        timer.setEventHandler { [weak self] in
            guard let self, self.handshakeTimer != nil else { return }
            if self.currentTransportMode == .proxy {
                self.fallbackToDirectStdioLocked()
            } else {
                self.transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続タイムアウト")
            }
        }
        timer.resume()
        handshakeTimer = timer
    }

    private func cancelHandshakeTimeout() {
        handshakeTimer?.cancel()
        handshakeTimer = nil
    }

    private func scheduleReconnectLocked() {
        guard shouldReconnect, reconnectTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + reconnectDelaySeconds)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.reconnectTimer = nil
            guard self.shouldReconnect, !self.proxyIsRunning else { return }
            self.connectLocked()
        }
        timer.resume()
        reconnectTimer = timer
    }

    private func cancelReconnectLocked() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func startRequestTimeoutWatchdog() {
        requestTimeoutTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + requestTimeoutSeconds, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.expireTimedOutRequests()
        }
        timer.resume()
        requestTimeoutTimer = timer
    }

    private func expireTimedOutRequests() {
        guard proxyIsRunning, proxyProcess?.isRunning == true else { return }
        let now = DispatchTime.now()
        for request in pendingRequests.values {
            guard !isInitializeRequest(request.kind) else { continue }
            if secondsBetween(request.sentAt, now) >= requestTimeoutSeconds {
                transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続タイムアウト")
                return
            }
        }
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
        threadReadIdsInRefreshCycle.removeAll()
        sendRequest(method: "thread/loaded/list", params: ["limit": ThreadContext.loadedRequestLimit], kind: .loadedList)
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
        pendingRequests[id] = PendingRequest(kind: kind, sentAt: .now())
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
            handleTransportWriteFailureLocked()
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
                    handleTransportWriteFailureLocked()
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
                handleTransportWriteFailureLocked()
                return
            }
        } catch {
            handleTransportWriteFailureLocked()
        }
    }

    private func handleTransportWriteFailureLocked() {
        if currentTransportMode == .proxy, !transportInitialized {
            fallbackToDirectStdioLocked()
        } else {
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
        let kind = pendingRequests.removeValue(forKey: id)?.kind
        guard object["error"] == nil else {
            if !isInitializeRequest(kind) {
                transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
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
            transportInitialized = true
            onConnectionState?(true)
            sendNotification(method: "initialized")
            threadReadIdsInRefreshCycle.removeAll()
            sendRequest(method: "thread/loaded/list", params: ["limit": ThreadContext.loadedRequestLimit], kind: .loadedList)
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
            sendRequest(method: "thread/list", params: ["limit": ThreadContext.requestLimit, "archived": false], kind: .threadList)
            return
        }

        loadedThreadIds = Array(ids.prefix(ThreadContext.requestLimit))
        if let first = loadedThreadIds.first, selectedThreadId == nil || !currentVisibleThreadIds().contains(selectedThreadId ?? "") {
            selectedThreadId = first
        }
        rememberThreadOrder(loadedThreadIds)
        pruneThreadTracking(keeping: currentVisibleThreadIds())
        for id in loadedThreadIds {
            sendThreadRead(threadId: id, reason: .refresh)
        }
        sendRequest(method: "thread/list", params: ["limit": ThreadContext.requestLimit, "archived": false], kind: .threadList)
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

        let visibleThreads = Array(threads.prefix(ThreadContext.requestLimit))
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
            sendThreadRead(threadId: id, reason: .refresh)
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
        guard let method = CodexNotificationMethod(rawValue: method) else {
            _ = CodexIgnoredNotificationMethod(rawValue: method)
            return
        }

        switch method {
        case .error:
            appendProgressLine(from: params, kind: "error")
        case .threadStarted:
            if let dict = params as? [String: Any],
               let threadObject = dict["thread"] as? [String: Any],
               let snapshot = decodeThreadSnapshot(from: threadObject) {
                suppressedThreadIds.remove(snapshot.id)
                selectedThreadId = snapshot.id
                rememberNotificationThread(snapshot.id)
                let title = threadTitle(from: threadObject)
                threadTitlesById[snapshot.id] = title
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
                sendThreadRead(threadId: snapshot.id, reason: .notification)
                apply(snapshot: snapshot)
            }
        case .threadStatusChanged:
            if let payload = decodeNotificationParams(ThreadStatusChangedNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                selectedThreadId = selectedThreadId ?? payload.threadId
                rememberNotificationThread(payload.threadId)
                sendThreadRead(threadId: payload.threadId, reason: .notification)
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
                rememberNotificationThread(payload.threadId)
                retitleThread(threadId: payload.threadId, title: title)
                sendThreadRead(threadId: payload.threadId, reason: .notification)
                emitSnapshot(connectionAvailable: true)
            }
        case .threadGoalUpdated:
            appendProgressLine(from: params, kind: "threadGoalUpdated")
        case .threadGoalCleared:
            appendProgressLine(from: params, kind: "threadGoalCleared")
        case .threadArchived, .threadClosed, .threadDeleted:
            if let payload = decodeNotificationParams(ThreadIdNotification.self, from: params) {
                removeThreadTracking(threadId: payload.threadId, suppressPendingReads: true)
                emitSnapshot(connectionAvailable: true)
            }
        case .threadUnarchived:
            if let payload = decodeNotificationParams(ThreadIdNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                rememberNotificationThread(payload.threadId)
                sendThreadRead(threadId: payload.threadId, reason: .notification)
                emitSnapshot(connectionAvailable: true)
            }
        case .threadCompacted:
            appendProgressLine(from: params, kind: "threadCompacted")
        case .hookStarted:
            appendProgressLine(from: params, kind: "hookStarted")
        case .hookCompleted:
            appendProgressLine(from: params, kind: "hookCompleted")
        case .turnStarted:
            if let payload = decodeNotificationParams(TurnNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                selectedThreadId = payload.threadId
                rememberNotificationThread(payload.threadId)
                latestTurnStatus = .inProgress
                hasRecentAssistantFinal = false
                updateThreadActivity(
                    threadId: payload.threadId,
                    title: threadTitlesById[payload.threadId] ?? "Codex Thread",
                    threadStatus: threadStatusesById[payload.threadId] ?? .active(activeFlags: []),
                    latestTurnStatus: .inProgress,
                    hasRecentAssistantFinal: false
                )
                sendThreadRead(threadId: payload.threadId, reason: .notification)
                emitSnapshot(connectionAvailable: true)
            }
        case .turnCompleted:
            if let payload = decodeNotificationParams(TurnNotification.self, from: params) {
                suppressedThreadIds.remove(payload.threadId)
                selectedThreadId = payload.threadId
                rememberNotificationThread(payload.threadId)
                latestTurnStatus = payload.turn.status
                hasRecentAssistantFinal = payload.turn.status == .completed
                updateThreadActivity(
                    threadId: payload.threadId,
                    title: threadTitlesById[payload.threadId] ?? "Codex Thread",
                    threadStatus: threadStatusesById[payload.threadId],
                    latestTurnStatus: payload.turn.status,
                    hasRecentAssistantFinal: payload.turn.status == .completed
                )
                sendThreadRead(threadId: payload.threadId, reason: .notification)
                emitSnapshot(connectionAvailable: true)
            }
        case .turnPlanUpdated:
            appendProgressLine(from: params, kind: "turnPlanUpdated")
        case .turnDiffUpdated:
            appendProgressLine(from: params, kind: "turnDiffUpdated")
        case .turnModerationMetadata:
            appendProgressLine(from: params, kind: "turnModerationMetadata")
        case .itemStarted:
            if let dict = params as? [String: Any],
               let threadId = dict["threadId"] as? String {
                suppressedThreadIds.remove(threadId)
                selectedThreadId = selectedThreadId ?? threadId
                rememberNotificationThread(threadId)
                appendConversationLine(from: dict["item"], threadId: threadId)
                sendThreadRead(threadId: threadId, reason: .notification)
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
                rememberNotificationThread(threadId)
                appendConversationLine(from: dict["item"], threadId: threadId)
                sendThreadRead(threadId: threadId, reason: .notification)
                guard selectedThreadId == threadId else {
                    emitSnapshot(connectionAvailable: true)
                    return
                }
                if itemLooksLikeAssistantFinal(dict["item"]) {
                    hasRecentAssistantFinal = true
                }
                emitSnapshot(connectionAvailable: true)
            }
        case .autoApprovalReviewStarted:
            appendProgressLine(from: params, kind: "autoApprovalReviewStarted")
        case .autoApprovalReviewCompleted:
            appendProgressLine(from: params, kind: "autoApprovalReviewCompleted")
        case .agentMessageDelta:
            appendProgressLine(from: params, kind: "agentMessageDelta")
        case .planDelta:
            appendProgressLine(from: params, kind: "planDelta")
        case .reasoningSummaryPartAdded, .reasoningSummaryTextDelta, .reasoningTextDelta:
            appendProgressLine(from: params, kind: "reasoningDelta")
        case .commandExecutionOutputDelta:
            appendProgressLine(from: params, kind: "commandExecutionOutputDelta")
        case .commandExecutionTerminalInteraction:
            appendProgressLine(from: params, kind: "commandExecutionTerminalInteraction")
        case .fileChangeOutputDelta:
            appendProgressLine(from: params, kind: "fileChangeOutputDelta")
        case .fileChangePatchUpdated:
            appendProgressLine(from: params, kind: "fileChangePatchUpdated")
        case .mcpToolCallProgress:
            appendProgressLine(from: params, kind: "mcpToolCallProgress")
        case .serverRequestResolved:
            appendProgressLine(from: params, kind: "serverRequestResolved")
        case .mcpServerStartupStatusUpdated:
            appendProgressLine(from: params, kind: "mcpServerStartupStatusUpdated")
        case .modelRerouted:
            appendProgressLine(from: params, kind: "modelRerouted")
        case .modelVerification:
            appendProgressLine(from: params, kind: "modelVerification")
        case .warning:
            appendProgressLine(from: params, kind: "warning")
        case .guardianWarning:
            appendProgressLine(from: params, kind: "guardianWarning")
        }
    }

    private func sendThreadRead(threadId: String, reason: ThreadReadReason) {
        if reason == .refresh {
            guard !threadReadIdsInRefreshCycle.contains(threadId) else { return }
            threadReadIdsInRefreshCycle.insert(threadId)
        }
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

    private func rememberNotificationThread(_ id: String) {
        notificationThreadLastSeenById[id] = .now()
        rememberThreadOrder([id])
        if notificationThreadLastSeenById.count > 6 {
            let orderedTrackedIds = threadDisplayOrder.filter { notificationThreadLastSeenById[$0] != nil }
            for staleId in orderedTrackedIds.dropLast(6) {
                notificationThreadLastSeenById.removeValue(forKey: staleId)
            }
        }
    }

    private func pruneExpiredNotificationThreads() {
        let now = DispatchTime.now()
        notificationThreadLastSeenById = notificationThreadLastSeenById.filter { _, lastSeen in
            secondsBetween(lastSeen, now) < ThreadContext.notificationTrackingTTLSeconds
        }
    }

    private func currentVisibleThreadIds() -> Set<String> {
        pruneExpiredNotificationThreads()
        return Set(loadedThreadIds + listedThreadIds + Array(notificationThreadLastSeenById.keys))
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
            notificationThreadLastSeenById.removeAll()
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
        notificationThreadLastSeenById = notificationThreadLastSeenById.filter { ids.contains($0.key) }
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
        notificationThreadLastSeenById.removeValue(forKey: threadId)
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
                    isAssistant: line.isAssistant,
                    activityKind: line.activityKind
                )
            }
        }
        if let activity = threadActivityById[threadId] {
            threadActivityById[threadId] = CodexConversationLine(
                threadId: activity.threadId,
                threadTitle: title,
                speaker: activity.speaker,
                text: activity.text,
                isAssistant: activity.isAssistant,
                activityKind: activity.activityKind
            )
        }
    }

    private func combinedConversationLines() -> [CodexConversationLine] {
        CodexConversationLineCombiner.combinedConversationLines(
            threadDisplayOrder: threadDisplayOrder,
            conversationByThread: conversationByThread,
            threadActivityById: threadActivityById,
            preferredThreadId: selectedThreadId
        )
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
        rememberNotificationThread(threadId)
        let title = threadTitlesById[threadId] ?? "Codex Thread"
        let line = CodexConversationExtractor.progressLine(
            threadId: threadId,
            threadTitle: title,
            kind: kind
        )
        var lines = conversationByThread[threadId] ?? []
        lines.append(line)
        conversationByThread[threadId] = Array(lines.suffix(6))
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

    private static func requestTimeoutInterval(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        guard
            let value = environment["MIMO_APP_SERVER_REQUEST_TIMEOUT"],
            let seconds = TimeInterval(value),
            seconds > 0
        else {
            return 12.0
        }
        return max(0.25, seconds)
    }

    private static func reconnectDelayInterval(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        guard
            let value = environment["MIMO_APP_SERVER_RECONNECT_DELAY"],
            let seconds = TimeInterval(value),
            seconds >= 0
        else {
            return 4.0
        }
        return max(0.1, seconds)
    }

    private static func daemonStartTimeoutInterval(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        guard
            let value = environment["MIMO_APP_SERVER_DAEMON_START_TIMEOUT"],
            let seconds = TimeInterval(value),
            seconds > 0
        else {
            return 2.0
        }
        return max(0.05, seconds)
    }

    private func secondsBetween(_ start: DispatchTime, _ end: DispatchTime) -> TimeInterval {
        TimeInterval(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }
}
