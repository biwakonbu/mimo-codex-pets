import Foundation
import MimoDesktopPetCore

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var presentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    @Published var clickThrough = false

    private var lastCodexPresentation = PetPresentationState(animation: .idle, bubbleText: "待機中")

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
        presentation = presentationState
    }

    func setConnectionAvailable(_ available: Bool) {
        guard !available else { return }
        let offline = CodexPetStateMapper.presentation(
            threadStatus: nil,
            latestTurnStatus: nil,
            hasRecentAssistantFinal: false,
            connectionAvailable: false
        )
        lastCodexPresentation = offline
        presentation = offline
    }

    func beginDrag(deltaX: CGFloat) {
        presentation = CodexPetStateMapper.dragPresentation(deltaX: Double(deltaX))
    }

    func beginDrag(animation: PetAnimationState) {
        let next = PetPresentationState(animation: animation, bubbleText: "移動中")
        guard presentation != next else { return }
        presentation = next
    }

    func endDrag() {
        presentation = lastCodexPresentation
    }

    func toggleClickThrough() {
        clickThrough.toggle()
    }
}
