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
    public static let productionWindowWidth = 360.0
    public static let productionWindowHeight = 360.0
    public static let productionStackWidth = 348.0
    public static let productionStackHeight = 146.0
    public static let productionSpriteWidth = 192.0
    public static let productionSpriteHeight = 208.0
    public static let productionVisibleLimit = 3
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
        let topOffset: Double
        let middleOffset: Double
        switch count {
        case 1:
            topOffset = 0
            middleOffset = 0
        case 2:
            topOffset = -48
            middleOffset = 0
        default:
            topOffset = -86
            middleOffset = -42
        }

        let horizontalOffset: Double
        let verticalOffset: Double
        switch normalizedIndex {
        case 0:
            horizontalOffset = 0
            verticalOffset = topOffset
        case 1:
            horizontalOffset = count == 2 ? -32 : -46
            verticalOffset = middleOffset
        default:
            horizontalOffset = 42
            verticalOffset = 0
        }

        return PetSpeechBubblePlacement(
            index: normalizedIndex,
            role: role,
            maxTextWidth: role == .status ? 292 : 246,
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            fillOpacity: role == .status ? 0.96 : 0.9,
            zIndex: Double(productionVisibleLimit - normalizedIndex)
        )
    }
}
