import Foundation

public enum PetSpeechBubbleHitTesting {
    public static func openableBubble(
        at point: PetWanderPoint,
        bubbles: [PetSpeechBubble],
        framesByBubbleId: [String: PetDragFrame]
    ) -> PetSpeechBubble? {
        let visible = Array(bubbles.prefix(PetSpeechBubbleLayout.productionVisibleLimit))
        return visible.first { bubble in
            guard bubble.threadId != nil, let frame = framesByBubbleId[bubble.id] else { return false }
            return PetInteractionHitRegion.containsBubble(point: point, in: frame)
        }
    }
}
