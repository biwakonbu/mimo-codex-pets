import Foundation
import MimoDesktopPetCore

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var presentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    @Published private(set) var conversationLines: [CodexConversationLine] = []
    @Published var clickThrough = false
    @Published var debugOverlay: Bool

    private let presentationLogURL: URL?
    private var lastCodexPresentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    private var momentToken = UUID()
    private var lastConversationSignature: String?

    init(debugOverlay: Bool = ProcessInfo.processInfo.environment["MIMO_DEBUG_OVERLAY"] == "1") {
        self.debugOverlay = debugOverlay
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
        momentToken = UUID()
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
        conversationLines = Array(snapshot.conversationLines.suffix(5))
        if let line = snapshot.focusedConversationLine ?? conversationLines.last,
           shouldShowConversation(line) {
            showTemporaryPresentation(
                PetPresentationState(
                    animation: presentationState.animation,
                    bubbleText: CodexBubbleFormatter.bubbleText(for: line),
                    isOffline: presentationState.isOffline
                ),
                duration: 4.0
            )
        } else {
            setPresentation(presentationState)
        }
    }

    func setConnectionAvailable(_ available: Bool) {
        guard !available else { return }
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
        momentToken = UUID()
        setPresentation(CodexPetStateMapper.dragPresentation(deltaX: Double(deltaX)))
    }

    func beginDrag(animation: PetAnimationState) {
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
        momentToken = UUID()
        setPresentation(lastCodexPresentation)
    }

    func playMoment(animation: PetAnimationState, bubbleText: String? = nil, duration: TimeInterval = 1.8) {
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

    private func shouldShowConversation(_ line: CodexConversationLine) -> Bool {
        let signature = "\(line.threadId)|\(line.speaker)|\(line.text)"
        guard signature != lastConversationSignature else { return false }
        lastConversationSignature = signature
        return true
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
        appendPresentationLog(state)
    }

    private func appendPresentationLog(_ state: PetPresentationState) {
        guard let presentationLogURL else { return }
        let object: [String: Any] = [
            "animation": state.animation.rawValue,
            "bubbleText": state.bubbleText,
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
