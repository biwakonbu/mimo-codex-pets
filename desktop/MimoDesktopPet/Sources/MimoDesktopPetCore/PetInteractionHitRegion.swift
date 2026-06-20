import Foundation

public enum PetInteractionHitRegion {
    public static func contains(
        point: PetWanderPoint,
        bounds: PetDragFrame,
        debugOverlay: Bool
    ) -> Bool {
        guard point.x >= 0, point.y >= 0, point.x <= bounds.width, point.y <= bounds.height else {
            return false
        }
        if debugOverlay {
            return true
        }

        let bubbleHeight = min(PetSpeechBubbleLayout.productionStackHeight + 12.0, bounds.height)
        let bubbleRect = HitRect(
            x: max(0, (bounds.width - PetSpeechBubbleLayout.productionStackWidth) / 2),
            y: max(0, bounds.height - bubbleHeight),
            width: min(PetSpeechBubbleLayout.productionStackWidth, bounds.width),
            height: bubbleHeight
        )
        let spriteRect = HitRect(
            x: max(0, (bounds.width - (PetSpeechBubbleLayout.productionSpriteWidth + 38.0)) / 2),
            y: 18,
            width: min(PetSpeechBubbleLayout.productionSpriteWidth + 38.0, bounds.width),
            height: min(226, max(0, bounds.height - bubbleHeight + 18))
        )

        return bubbleRect.contains(point) || spriteRect.contains(point)
    }
}

private struct HitRect {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func contains(_ point: PetWanderPoint) -> Bool {
        point.x >= x &&
            point.x <= x + width &&
            point.y >= y &&
            point.y <= y + height
    }
}
