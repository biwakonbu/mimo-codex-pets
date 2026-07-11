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
            return frame.contains(point)
        }
    }
}

private extension PetDragFrame {
    func contains(_ point: PetWanderPoint) -> Bool {
        point.x >= x && point.x <= x + width &&
            point.y >= y && point.y <= y + height
    }
}
