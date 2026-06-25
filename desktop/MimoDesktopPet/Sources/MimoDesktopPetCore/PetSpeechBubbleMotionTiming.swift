import Foundation

public struct PetSpeechBubbleAnimationTiming: Equatable, Sendable {
    public let response: Double
    public let dampingFraction: Double
    public let delay: Double

    public init(response: Double, dampingFraction: Double, delay: Double) {
        self.response = response
        self.dampingFraction = dampingFraction
        self.delay = delay
    }
}

public enum PetSpeechBubbleMotionTiming {
    public static func stackTiming(for index: Int) -> PetSpeechBubbleAnimationTiming {
        let resolvedIndex = max(0, min(index, PetSpeechBubbleLayout.productionVisibleLimit - 1))
        let indexValue = Double(resolvedIndex)
        return PetSpeechBubbleAnimationTiming(
            response: PetSpeechBubbleLayout.stackAnimationResponse +
                indexValue * PetSpeechBubbleLayout.stackAnimationResponseStep,
            dampingFraction: max(
                PetSpeechBubbleLayout.stackAnimationMinimumDampingFraction,
                PetSpeechBubbleLayout.stackAnimationDampingFraction -
                    indexValue * PetSpeechBubbleLayout.stackAnimationDampingStep
            ),
            delay: min(
                PetSpeechBubbleLayout.stackAnimationMaxStaggerDelay,
                indexValue * PetSpeechBubbleLayout.stackAnimationStaggerDelay
            )
        )
    }
}
