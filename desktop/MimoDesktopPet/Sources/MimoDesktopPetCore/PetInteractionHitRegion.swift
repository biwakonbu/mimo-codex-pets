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

        let bubbleHeight = min(62.0, bounds.height)
        let bubbleRect = HitRect(
            x: 4,
            y: max(0, bounds.height - bubbleHeight),
            width: max(0, bounds.width - 8),
            height: bubbleHeight
        )
        let spriteRect = HitRect(
            x: max(0, (bounds.width - 220) / 2),
            y: 18,
            width: min(220, bounds.width),
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
