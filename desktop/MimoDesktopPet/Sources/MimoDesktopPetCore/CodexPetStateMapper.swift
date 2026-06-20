import Foundation

public struct PetPresentationState: Equatable, Sendable {
    public let animation: PetAnimationState
    public let bubbleText: String
    public let isOffline: Bool

    public init(animation: PetAnimationState, bubbleText: String, isOffline: Bool = false) {
        self.animation = animation
        self.bubbleText = bubbleText
        self.isOffline = isOffline
    }
}

public enum PetSpeechBubbleRole: String, Equatable, Sendable {
    case status
    case conversation
}

public struct PetSpeechBubble: Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let role: PetSpeechBubbleRole

    public init(id: String, text: String, role: PetSpeechBubbleRole) {
        self.id = id
        self.text = text
        self.role = role
    }
}

public enum CodexPetStateMapper {
    public static func presentation(
        threadStatus: CodexThreadStatus?,
        latestTurnStatus: CodexTurnStatus?,
        hasRecentAssistantFinal: Bool,
        connectionAvailable: Bool = true
    ) -> PetPresentationState {
        guard connectionAvailable else {
            return PetPresentationState(animation: .idle, bubbleText: "Codex 接続待ち", isOffline: true)
        }

        if case .systemError = threadStatus {
            return PetPresentationState(animation: .failed, bubbleText: "Codex で問題が発生")
        }

        if latestTurnStatus == .failed {
            return PetPresentationState(animation: .failed, bubbleText: "実行に失敗しました")
        }

        if case let .active(flags) = threadStatus {
            if flags.contains(.waitingOnApproval) || flags.contains(.waitingOnUserInput) {
                return PetPresentationState(animation: .waiting, bubbleText: "確認を待っています")
            }
            return PetPresentationState(animation: .running, bubbleText: "Codex が作業中")
        }

        if latestTurnStatus == .completed && hasRecentAssistantFinal {
            return PetPresentationState(animation: .review, bubbleText: "レビューできます")
        }

        return PetPresentationState(animation: .idle, bubbleText: "待機中")
    }

    public static func dragPresentation(deltaX: Double) -> PetPresentationState {
        let animation: PetAnimationState = deltaX < 0 ? .runningLeft : .runningRight
        return PetPresentationState(animation: animation, bubbleText: "移動中")
    }
}
