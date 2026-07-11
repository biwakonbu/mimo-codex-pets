import Foundation

public enum PetInteractionHitTarget: Equatable, Sendable {
    case none
    case sprite
    case bubble
}

public enum PetInteractionAction: Equatable, Sendable {
    case ignore
    case clickBubble
    case dragSprite
}

public enum PetInteractionActionPolicy {
    public static func action(
        for target: PetInteractionHitTarget,
        debugOverlay: Bool
    ) -> PetInteractionAction {
        if debugOverlay || target == .sprite {
            return .dragSprite
        }
        if target == .bubble {
            return .clickBubble
        }
        return .ignore
    }
}

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
        return containsSprite(point: point, bounds: bounds)
    }

    public static func target(
        point: PetWanderPoint,
        bounds: PetDragFrame,
        bubbleFrames: [PetDragFrame],
        debugOverlay: Bool
    ) -> PetInteractionHitTarget {
        guard point.x >= 0, point.y >= 0, point.x <= bounds.width, point.y <= bounds.height else {
            return .none
        }
        if debugOverlay {
            return .sprite
        }
        if containsSprite(point: point, bounds: bounds) {
            return .sprite
        }
        if bubbleFrames.contains(where: { containsBubble(point: point, in: $0) }) {
            return .bubble
        }
        return .none
    }

    public static func containsBubble(
        point: PetWanderPoint,
        in frame: PetDragFrame,
        cornerRadius: Double = 10
    ) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }
        let radius = min(max(cornerRadius, 0), min(frame.width, frame.height) / 2)
        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2
        let localX = point.x - (frame.x + halfWidth)
        let localY = point.y - (frame.y + halfHeight)
        let innerHalfWidth = halfWidth - radius
        let innerHalfHeight = halfHeight - radius
        let outsideX = max(abs(localX) - innerHalfWidth, 0)
        let outsideY = max(abs(localY) - innerHalfHeight, 0)
        return outsideX * outsideX + outsideY * outsideY <= radius * radius
    }

    public static func containsSprite(point: PetWanderPoint, bounds: PetDragFrame) -> Bool {
        guard point.x >= 0, point.y >= 0, point.x <= bounds.width, point.y <= bounds.height else {
            return false
        }
        let spriteFrame = PetKataribeStageLayout.spriteFrame
        let topLeadingY = bounds.height - point.y
        let localX = (point.x - spriteFrame.x) / spriteFrame.width
        let localY = (topLeadingY - spriteFrame.y) / spriteFrame.height
        guard localX >= 0, localX <= 1, localY >= 0, localY <= 1 else {
            return false
        }

        // The sprite image is centered inside its cell with transparent margins.
        // Use a union of the visible character masses so empty panel space does
        // not become a drag handle while wings, backpack, halo, and feet remain
        // easy to grab.
        return containsEllipse(localX, localY, centerX: 0.50, centerY: 0.06, radiusX: 0.22, radiusY: 0.055) ||
            containsEllipse(localX, localY, centerX: 0.50, centerY: 0.28, radiusX: 0.30, radiusY: 0.25) ||
            containsEllipse(localX, localY, centerX: 0.50, centerY: 0.57, radiusX: 0.34, radiusY: 0.31) ||
            containsEllipse(localX, localY, centerX: 0.29, centerY: 0.53, radiusX: 0.17, radiusY: 0.22) ||
            containsEllipse(localX, localY, centerX: 0.71, centerY: 0.53, radiusX: 0.17, radiusY: 0.22) ||
            containsEllipse(localX, localY, centerX: 0.38, centerY: 0.88, radiusX: 0.17, radiusY: 0.14) ||
            containsEllipse(localX, localY, centerX: 0.62, centerY: 0.88, radiusX: 0.17, radiusY: 0.14)
    }

    private static func containsEllipse(
        _ x: Double,
        _ y: Double,
        centerX: Double,
        centerY: Double,
        radiusX: Double,
        radiusY: Double
    ) -> Bool {
        let normalizedX = (x - centerX) / radiusX
        let normalizedY = (y - centerY) / radiusY
        return normalizedX * normalizedX + normalizedY * normalizedY <= 1
    }
}
