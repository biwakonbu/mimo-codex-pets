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

    private enum StreamFraming {
        case jsonLines
        case contentLength
    }

    private let queue = DispatchQueue(label: "MimoDesktopPet.CodexAppServerClient")
    private let decoder = JSONDecoder()
    private let invocation = CodexCommandLocator.resolve()
    private var proxyProcess: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var proxyIsRunning = false
    private var streamFraming: StreamFraming = .jsonLines
    private var stdoutBuffer = Data()
    private var nextRequestId = 1
    private var pendingRequests: [Int: RequestKind] = [:]
    private var selectedThreadId: String?
    private var latestThreadStatus: CodexThreadStatus?
    private var latestTurnStatus: CodexTurnStatus?
    private var hasRecentAssistantFinal = false
    private var threadTitlesById: [String: String] = [:]
    private var conversationByThread: [String: [CodexConversationLine]] = [:]
    private var threadDisplayOrder: [String] = []
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
            streamFraming = .jsonLines
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
        stdoutBuffer.removeAll()
        pendingRequests.removeAll()
    }

    private func resetThreadTrackingLocked() {
        selectedThreadId = nil
        latestThreadStatus = nil
        latestTurnStatus = nil
        hasRecentAssistantFinal = false
        threadTitlesById.removeAll()
        conversationByThread.removeAll()
        threadDisplayOrder.removeAll()
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
            self?.refreshCurrentThread()
        }
        timer.resume()
        pollTimer = timer
    }

    private func refreshCurrentThread() {
        if let selectedThreadId {
            sendRequest(
                method: "thread/read",
                params: ["threadId": selectedThreadId, "includeTurns": true],
                kind: .threadRead(threadId: selectedThreadId)
            )
        } else {
            sendRequest(method: "thread/loaded/list", params: ["limit": 10], kind: .loadedList)
        }
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
            switch streamFraming {
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
        stdoutBuffer.append(data)

        switch streamFraming {
        case .jsonLines:
            consumeJSONLines()
        case .contentLength:
            consumeContentLengthMessages()
        }
    }

    private func consumeJSONLines() {
        while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
            var lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newlineIndex)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineIndex)
            if lineData.last == 0x0D {
                lineData.removeLast()
            }
            guard !lineData.isEmpty else { continue }
            handleLine(lineData)
        }
    }

    private func consumeContentLengthMessages() {
        let headerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        while let headerRange = stdoutBuffer.range(of: headerSeparator) {
            let headerData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<headerRange.lowerBound)
            guard
                let headerText = String(data: headerData, encoding: .utf8),
                let contentLength = parseContentLength(from: headerText)
            else {
                transitionToOfflineLocked(terminateProxy: true, offlineBubbleText: "Codex 接続切れ")
                return
            }

            let bodyStart = headerRange.upperBound
            let bodyEnd = bodyStart + contentLength
            guard stdoutBuffer.count >= bodyEnd else {
                return
            }

            let body = stdoutBuffer.subdata(in: bodyStart..<bodyEnd)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex..<bodyEnd)
            handleLine(body)
        }
    }

    private func parseContentLength(from headerText: String) -> Int? {
        for line in headerText.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                continue
            }
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }
        return nil
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
            let ids = dict["data"] as? [String],
            let first = ids.first
        else {
            sendRequest(method: "thread/list", params: ["limit": 4, "archived": false], kind: .threadList)
            return
        }

        selectedThreadId = first
        rememberThreadOrder(ids)
        for id in ids.prefix(4) {
            sendRequest(
                method: "thread/read",
                params: ["threadId": id, "includeTurns": true],
                kind: .threadRead(threadId: id)
            )
        }
        sendRequest(method: "thread/list", params: ["limit": 4, "archived": false], kind: .threadList)
    }

    private func handleThreadList(_ result: Any?) {
        guard
            let dict = result as? [String: Any],
            let threads = dict["data"] as? [[String: Any]],
            let first = threads.first,
            let threadId = first["id"] as? String
        else {
            latestThreadStatus = nil
            latestTurnStatus = nil
            hasRecentAssistantFinal = false
            emitSnapshot(connectionAvailable: true)
            return
        }

        let visibleThreads = Array(threads.prefix(4))
        rememberThreadOrder(visibleThreads.compactMap { $0["id"] as? String })

        for thread in visibleThreads {
            guard let id = thread["id"] as? String else { continue }
            threadTitlesById[id] = threadTitle(from: thread)
            let lines = CodexConversationExtractor.lines(from: thread)
            if !lines.isEmpty {
                conversationByThread[id] = lines
            }
        }

        selectedThreadId = selectedThreadId ?? threadId
        if selectedThreadId == threadId, let snapshot = decodeThreadSnapshot(from: first) {
            apply(snapshot: snapshot)
        }
        for thread in visibleThreads {
            guard let id = thread["id"] as? String else { continue }
            sendRequest(
                method: "thread/read",
                params: ["threadId": id, "includeTurns": true],
                kind: .threadRead(threadId: id)
            )
        }
    }

    private func handleThreadRead(_ result: Any?, expectedThreadId: String) {
        guard
            let dict = result as? [String: Any],
            let threadObject = dict["thread"] as? [String: Any],
            let snapshot = decodeThreadSnapshot(from: threadObject)
        else {
            emitSnapshot(connectionAvailable: true)
            return
        }

        threadTitlesById[snapshot.id] = threadTitle(from: threadObject)
        rememberThreadOrder([snapshot.id])
        let lines = CodexConversationExtractor.lines(from: threadObject)
        if !lines.isEmpty {
            conversationByThread[snapshot.id] = lines
        }

        if selectedThreadId == nil || selectedThreadId == expectedThreadId || selectedThreadId == snapshot.id {
            selectedThreadId = snapshot.id
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
                selectedThreadId = selectedThreadId ?? payload.threadId
                guard selectedThreadId == payload.threadId else { return }
                latestThreadStatus = payload.status
                if case .systemError = payload.status {
                    latestTurnStatus = .failed
                    hasRecentAssistantFinal = false
                }
                emitSnapshot(connectionAvailable: true)
            }
        case .turnStarted:
            if let payload = decodeNotificationParams(TurnNotification.self, from: params) {
                selectedThreadId = payload.threadId
                latestTurnStatus = .inProgress
                hasRecentAssistantFinal = false
                emitSnapshot(connectionAvailable: true)
            }
        case .turnCompleted:
            if let payload = decodeNotificationParams(TurnNotification.self, from: params) {
                selectedThreadId = payload.threadId
                latestTurnStatus = payload.turn.status
                hasRecentAssistantFinal = payload.turn.status == .completed
                emitSnapshot(connectionAvailable: true)
            }
        case .itemStarted:
            if let dict = params as? [String: Any],
               let threadId = dict["threadId"] as? String {
                selectedThreadId = selectedThreadId ?? threadId
                appendConversationLine(from: dict["item"], threadId: threadId)
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
                selectedThreadId = selectedThreadId ?? threadId
                appendConversationLine(from: dict["item"], threadId: threadId)
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
        case .commandExecutionOutputDelta:
            appendProgressLine(from: params, kind: "commandExecutionOutputDelta")
        case .fileChangeOutputDelta:
            appendProgressLine(from: params, kind: "fileChangeOutputDelta")
        case .mcpToolCallProgress:
            appendProgressLine(from: params, kind: "mcpToolCallProgress")
        }
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
        for id in ids where !threadDisplayOrder.contains(id) {
            threadDisplayOrder.append(id)
        }
        if threadDisplayOrder.count > 6 {
            threadDisplayOrder = Array(threadDisplayOrder.prefix(6))
        }
    }

    private func combinedConversationLines() -> [CodexConversationLine] {
        let orderedLines = threadDisplayOrder.flatMap { conversationByThread[$0] ?? [] }
        return Array(orderedLines.suffix(6))
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
