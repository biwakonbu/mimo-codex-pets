import Foundation

public struct PetSpeechBubblePlacement: Equatable, Sendable {
    public let index: Int
    public let role: PetSpeechBubbleRole
    public let maxTextWidth: Double
    public let horizontalOffset: Double
    public let verticalOffset: Double
    public let fillOpacity: Double
    public let zIndex: Double

    public init(
        index: Int,
        role: PetSpeechBubbleRole,
        maxTextWidth: Double,
        horizontalOffset: Double,
        verticalOffset: Double,
        fillOpacity: Double,
        zIndex: Double
    ) {
        self.index = index
        self.role = role
        self.maxTextWidth = maxTextWidth
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.fillOpacity = fillOpacity
        self.zIndex = zIndex
    }
}

public enum PetSpeechBubbleLayout {
    public static let productionWindowWidth = 392.0
    public static let productionWindowHeight = 408.0
    public static let productionStackWidth = 384.0
    public static let productionStackHeight = 188.0
    public static let productionSpriteWidth = 192.0
    public static let productionSpriteHeight = 208.0
    public static let productionVisibleLimit = 4
    public static let statusTextLimit = 44
    public static let conversationTextLimit = 34

    public static func textLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .status:
            return statusTextLimit
        case .conversation:
            return conversationTextLimit
        }
    }

    public static func lineLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .status:
            return 2
        case .conversation:
            return 1
        }
    }

    public static func placement(
        for index: Int,
        role: PetSpeechBubbleRole,
        visibleCount: Int
    ) -> PetSpeechBubblePlacement {
        let count = max(1, min(visibleCount, productionVisibleLimit))
        let normalizedIndex = max(0, min(index, count - 1))
        let offsets: [(x: Double, y: Double)]
        switch count {
        case 1:
            offsets = [(0, 0)]
        case 2:
            offsets = [(0, -52), (-30, 0)]
        case 3:
            offsets = [(0, -100), (-54, -50), (48, 0)]
        default:
            offsets = [(0, -136), (-58, -92), (58, -46), (-18, 0)]
        }
        let offset = offsets[normalizedIndex]

        return PetSpeechBubblePlacement(
            index: normalizedIndex,
            role: role,
            maxTextWidth: role == .status ? 308 : 246,
            horizontalOffset: offset.x,
            verticalOffset: offset.y,
            fillOpacity: role == .status ? 0.96 : 0.9,
            zIndex: Double(productionVisibleLimit - normalizedIndex)
        )
    }
}
