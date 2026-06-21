import Foundation
import MimoDesktopPetCore

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var presentation: PetPresentationState
    @Published private(set) var visibleBubbles: [PetSpeechBubble]
    @Published private(set) var conversationLines: [CodexConversationLine]
    @Published var clickThrough = false
    @Published var debugOverlay: Bool
    var hasPendingConversationBubbles: Bool {
        coordinator.hasPendingConversationBubbles
    }

    private let conversationBubbleDuration: TimeInterval
    private let presentationLogURL: URL?
    private var coordinator = PetPresentationCoordinator()
    private var momentToken = UUID()

    init(debugOverlay: Bool = PetDebugOverlayPolicy.isEnabled()) {
        self.debugOverlay = debugOverlay
        presentation = coordinator.presentation
        visibleBubbles = coordinator.visibleBubbles
        conversationLines = coordinator.conversationLines
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
        let change = coordinator.apply(
            snapshot: PetCodexSnapshot(
                threadStatus: snapshot.threadStatus,
                latestTurnStatus: snapshot.latestTurnStatus,
                hasRecentAssistantFinal: snapshot.hasRecentAssistantFinal,
                connectionAvailable: snapshot.connectionAvailable,
                offlineBubbleText: snapshot.offlineBubbleText,
                conversationLines: snapshot.conversationLines,
                focusedConversationLine: snapshot.focusedConversationLine
            )
        )
        if !coordinator.hasActiveConversationBubble {
            momentToken = UUID()
        }
        apply(change: change)
    }

    private func finishConversationBubble(token: UUID) {
        guard momentToken == token else { return }
        apply(change: coordinator.finishConversationBubble())
    }

    func setConnectionAvailable(_ available: Bool) {
        guard !available else { return }
        momentToken = UUID()
        apply(change: coordinator.setConnectionAvailable(available))
    }

    func beginDrag(deltaX: CGFloat) {
        momentToken = UUID()
        apply(change: coordinator.beginDrag(deltaX: Double(deltaX)))
    }

    func beginDrag(animation: PetAnimationState) {
        momentToken = UUID()
        apply(change: coordinator.beginDrag(animation: animation))
    }

    func beginAmbientMovement(animation: PetAnimationState) {
        apply(change: coordinator.beginAmbientMovement(animation: animation))
    }

    func endDrag() {
        momentToken = UUID()
        apply(change: coordinator.endDrag())
    }

    func endAmbientMovement() {
        apply(change: coordinator.endAmbientMovement())
    }

    func playMoment(animation: PetAnimationState, bubbleText: String? = nil, duration: TimeInterval = 1.8) {
        let token = UUID()
        momentToken = token
        apply(change: coordinator.playMoment(animation: animation, bubbleText: bubbleText))

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, self.momentToken == token else { return }
            self.apply(change: self.coordinator.finishTemporaryPresentation())
        }
    }

    func toggleClickThrough() {
        clickThrough.toggle()
    }

    func toggleDebugOverlay() {
        debugOverlay.toggle()
    }

    private func apply(change: PetPresentationCoordinatorChange) {
        presentation = coordinator.presentation
        visibleBubbles = coordinator.visibleBubbles
        conversationLines = coordinator.conversationLines
        if change.changed {
            appendPresentationLog(presentation)
        }
        if change.shouldScheduleConversationTimeout {
            scheduleConversationBubbleTimeout()
        }
    }

    private func scheduleConversationBubbleTimeout() {
        let token = UUID()
        momentToken = token
        Task { @MainActor [weak self] in
            let duration = self?.conversationBubbleDuration ?? 3.4
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.finishConversationBubble(token: token)
        }
    }

    private func appendPresentationLog(_ state: PetPresentationState) {
        guard let presentationLogURL else { return }
        let object: [String: Any] = [
            "animation": state.animation.rawValue,
            "bubbleText": state.bubbleText,
            "bubbleTexts": visibleBubbles.map(\.text),
            "bubbleRoles": visibleBubbles.map { $0.role.rawValue },
            "bubbleTones": visibleBubbles.map { $0.tone.rawValue },
            "bubbleActivityKinds": visibleBubbles.map { $0.activityKind?.rawValue ?? "none" },
            "debugOverlay": debugOverlay,
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
