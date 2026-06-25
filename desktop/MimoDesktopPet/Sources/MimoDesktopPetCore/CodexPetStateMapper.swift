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
    case focus
    case conversation
    case overflow
}

public enum PetSpeechBubbleTone: String, Equatable, Sendable {
    case neutral
    case active
    case waiting
    case review
    case failed
    case overflow
}

public struct PetSpeechBubble: Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let role: PetSpeechBubbleRole
    public let tone: PetSpeechBubbleTone
    public let activityKind: CodexConversationActivityKind?

    public init(
        id: String,
        text: String,
        role: PetSpeechBubbleRole,
        tone: PetSpeechBubbleTone = .neutral,
        activityKind: CodexConversationActivityKind? = nil
    ) {
        self.id = id
        self.text = text
        self.role = role
        self.tone = tone
        self.activityKind = activityKind
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
            return PetPresentationState(animation: .idle, bubbleText: CodexMimoStatusSpeech.connecting, isOffline: true)
        }

        if case .systemError = threadStatus {
            return PetPresentationState(animation: .failed, bubbleText: CodexMimoStatusSpeech.systemError)
        }

        if latestTurnStatus == .failed {
            return PetPresentationState(animation: .failed, bubbleText: CodexMimoStatusSpeech.failed)
        }

        if case let .active(flags) = threadStatus {
            if flags.contains(.waitingOnApproval) || flags.contains(.waitingOnUserInput) {
                return PetPresentationState(animation: .waiting, bubbleText: CodexMimoStatusSpeech.waiting)
            }
            return PetPresentationState(animation: .running, bubbleText: CodexMimoStatusSpeech.active)
        }

        if latestTurnStatus == .completed && hasRecentAssistantFinal {
            return PetPresentationState(animation: .review, bubbleText: CodexMimoStatusSpeech.review)
        }

        return PetPresentationState(animation: .idle, bubbleText: CodexMimoStatusSpeech.idle)
    }

    public static func dragPresentation(deltaX: Double) -> PetPresentationState {
        let animation: PetAnimationState = deltaX < 0 ? .runningLeft : .runningRight
        return PetPresentationState(animation: animation, bubbleText: CodexMimoStatusSpeech.moving)
    }
}
