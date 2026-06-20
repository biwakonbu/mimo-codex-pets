import Foundation
import MimoDesktopPetCore

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var presentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    @Published private(set) var visibleBubbles: [PetSpeechBubble] = [
        PetSpeechBubble(id: "0-待機中", text: "待機中", role: .status)
    ]
    @Published private(set) var conversationLines: [CodexConversationLine] = []
    @Published var clickThrough = false
    @Published var debugOverlay: Bool
    var hasPendingConversationBubbles: Bool {
        conversationBubbleActive || !pendingConversationLines.isEmpty
    }

    private let conversationBubbleDuration: TimeInterval
    private let presentationLogURL: URL?
    private var lastCodexPresentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    private var momentToken = UUID()
    private var shownConversationSignatures: Set<String> = []
    private var pendingConversationLines: [CodexConversationLine] = []
    private var conversationBubbleActive = false
    private var focusedThreadId: String?

    init(debugOverlay: Bool = ProcessInfo.processInfo.environment["MIMO_DEBUG_OVERLAY"] == "1") {
        self.debugOverlay = debugOverlay
        conversationBubbleDuration = ProcessInfo.processInfo.environment["MIMO_BUBBLE_TEST_MODE"] == "1" ? 1.15 : 3.4
        if let path = ProcessInfo.processInfo.environment["MIMO_PRESENTATION_LOG"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            presentationLogURL = url
            try? FileManager.default.removeItem(at: url)
            FileManager.default.createFile(atPath: path, contents: nil)
            appendPresentationLog(presentation)
        } else {
            presentationLogURL = nil
        }
    }

    func apply(snapshot: CodexStateSnapshot) {
        let next = CodexPetStateMapper.presentation(
            threadStatus: snapshot.threadStatus,
            latestTurnStatus: snapshot.latestTurnStatus,
            hasRecentAssistantFinal: snapshot.hasRecentAssistantFinal,
            connectionAvailable: snapshot.connectionAvailable
        )
        let presentationState: PetPresentationState
        if !snapshot.connectionAvailable, let offlineBubbleText = snapshot.offlineBubbleText {
            presentationState = PetPresentationState(
                animation: next.animation,
                bubbleText: offlineBubbleText,
                isOffline: next.isOffline
            )
        } else {
            presentationState = next
        }
        lastCodexPresentation = presentationState
        conversationLines = Array(snapshot.conversationLines.suffix(8))
        focusedThreadId = snapshot.focusedConversationLine?.threadId

        if snapshot.connectionAvailable {
            enqueueConversationLines(
                snapshot.conversationLines,
                preferredThreadId: focusedThreadId
            )
        } else {
            clearConversationQueue()
        }

        if !conversationBubbleActive {
            if !pendingConversationLines.isEmpty {
                showNextConversationBubble()
            } else {
                momentToken = UUID()
                setPresentation(presentationState)
            }
        }
    }

    private func enqueueConversationLines(_ lines: [CodexConversationLine], preferredThreadId: String?) {
        let candidates = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: preferredThreadId
        )
        let pendingSignatures = Set(pendingConversationLines.map(CodexConversationBubblePlanner.signature(for:)))

        for line in candidates {
            let signature = CodexConversationBubblePlanner.signature(for: line)
            guard !shownConversationSignatures.contains(signature), !pendingSignatures.contains(signature) else {
                continue
            }
            shownConversationSignatures.insert(signature)
            pendingConversationLines.insert(
                line,
                at: CodexConversationBubblePlanner.insertionIndex(
                    for: line,
                    preferredThreadId: preferredThreadId,
                    pendingLines: pendingConversationLines
                )
            )
        }
    }

    private func showNextConversationBubble() {
        guard !pendingConversationLines.isEmpty else {
            conversationBubbleActive = false
            setPresentation(lastCodexPresentation)
            return
        }

        let line = pendingConversationLines.removeFirst()
        let token = UUID()
        momentToken = token
        conversationBubbleActive = true
        setPresentation(
            PetPresentationState(
                animation: CodexConversationBubblePlanner.animation(
                    for: line,
                    fallback: lastCodexPresentation.animation
                ),
                bubbleText: CodexBubbleFormatter.bubbleText(for: line),
                isOffline: lastCodexPresentation.isOffline
            )
        )

        Task { @MainActor [weak self] in
            let duration = self?.conversationBubbleDuration ?? 3.4
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.finishConversationBubble(token: token)
        }
    }

    private func finishConversationBubble(token: UUID) {
        guard momentToken == token else { return }
        if pendingConversationLines.isEmpty {
            conversationBubbleActive = false
            setPresentation(lastCodexPresentation)
        } else {
            showNextConversationBubble()
        }
    }

    private func clearConversationQueue() {
        pendingConversationLines.removeAll()
        conversationBubbleActive = false
    }

    func setConnectionAvailable(_ available: Bool) {
        guard !available else { return }
        clearConversationQueue()
        conversationLines.removeAll()
        focusedThreadId = nil
        momentToken = UUID()
        let offline = CodexPetStateMapper.presentation(
            threadStatus: nil,
            latestTurnStatus: nil,
            hasRecentAssistantFinal: false,
            connectionAvailable: false
        )
        lastCodexPresentation = offline
        setPresentation(offline)
    }

    func beginDrag(deltaX: CGFloat) {
        clearConversationQueue()
        momentToken = UUID()
        setPresentation(CodexPetStateMapper.dragPresentation(deltaX: Double(deltaX)))
    }

    func beginDrag(animation: PetAnimationState) {
        clearConversationQueue()
        momentToken = UUID()
        let next = PetPresentationState(animation: animation, bubbleText: "移動中")
        guard presentation != next else { return }
        setPresentation(next)
    }

    func beginAmbientMovement(animation: PetAnimationState) {
        let next = PetPresentationState(
            animation: animation,
            bubbleText: presentation.bubbleText,
            isOffline: presentation.isOffline
        )
        guard presentation != next else { return }
        setPresentation(next)
    }

    func endDrag() {
        clearConversationQueue()
        momentToken = UUID()
        setPresentation(lastCodexPresentation)
    }

    func endAmbientMovement() {
        guard !conversationBubbleActive else { return }
        setPresentation(lastCodexPresentation)
    }

    func playMoment(animation: PetAnimationState, bubbleText: String? = nil, duration: TimeInterval = 1.8) {
        clearConversationQueue()
        let token = UUID()
        momentToken = token
        showTemporaryPresentation(
            PetPresentationState(
                animation: animation,
                bubbleText: bubbleText ?? lastCodexPresentation.bubbleText,
                isOffline: lastCodexPresentation.isOffline
            ),
            token: token,
            duration: duration
        )
    }

    func toggleClickThrough() {
        clickThrough.toggle()
    }

    func toggleDebugOverlay() {
        debugOverlay.toggle()
    }

    private func showTemporaryPresentation(
        _ state: PetPresentationState,
        token: UUID = UUID(),
        duration: TimeInterval
    ) {
        momentToken = token
        setPresentation(state)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, self.momentToken == token else { return }
            self.setPresentation(PetPresentationState(
                animation: self.lastCodexPresentation.animation,
                bubbleText: self.lastCodexPresentation.bubbleText,
                isOffline: self.lastCodexPresentation.isOffline
            ))
        }
    }

    private func setPresentation(_ state: PetPresentationState) {
        presentation = state
        visibleBubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: state.bubbleText,
            conversationLines: conversationLines,
            preferredThreadId: focusedThreadId
        )
        appendPresentationLog(state)
    }

    private func appendPresentationLog(_ state: PetPresentationState) {
        guard let presentationLogURL else { return }
        let object: [String: Any] = [
            "animation": state.animation.rawValue,
            "bubbleText": state.bubbleText,
            "bubbleTexts": visibleBubbles.map(\.text),
            "isOffline": state.isOffline
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: object),
            let newline = "\n".data(using: .utf8)
        else { return }

        if let handle = try? FileHandle(forWritingTo: presentationLogURL) {
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
            _ = try? handle.write(contentsOf: newline)
            _ = try? handle.close()
        } else {
            var line = data
            line.append(newline)
            try? line.write(to: presentationLogURL)
        }
    }
}
