import Foundation

public struct PetSpeechBubblePlacement: Equatable, Sendable {
    public let index: Int
    public let role: PetSpeechBubbleRole
    public let maxTextWidth: Double
    public let minTextWidth: Double?
    public let horizontalOffset: Double
    public let verticalOffset: Double
    public let fillOpacity: Double
    public let scale: Double
    public let zIndex: Double

    public init(
        index: Int,
        role: PetSpeechBubbleRole,
        maxTextWidth: Double,
        minTextWidth: Double? = nil,
        horizontalOffset: Double,
        verticalOffset: Double,
        fillOpacity: Double,
        scale: Double,
        zIndex: Double
    ) {
        self.index = index
        self.role = role
        self.maxTextWidth = maxTextWidth
        self.minTextWidth = minTextWidth
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.fillOpacity = fillOpacity
        self.scale = scale
        self.zIndex = zIndex
    }
}

public enum PetSpeechBubbleLayout {
    public static let productionWindowWidth = 432.0
    public static let productionWindowHeight = 438.0
    public static let productionStackWidth = 424.0
    public static let productionStackHeight = 226.0
    public static let productionSpriteWidth = 192.0
    public static let productionSpriteHeight = 208.0
    public static let productionVisibleLimit = 5
    public static let productionRowSpacing = 5.0
    public static let statusTextLimit = 44
    public static let focusTextLimit = 48
    public static let conversationTextLimit = 34
    public static let overflowTextLimit = 22

    public static func textLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .status:
            return statusTextLimit
        case .focus:
            return focusTextLimit
        case .conversation:
            return conversationTextLimit
        case .overflow:
            return overflowTextLimit
        }
    }

    public static func lineLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .status, .focus:
            return 2
        case .conversation, .overflow:
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
        let isPrimary = normalizedIndex == 0

        return PetSpeechBubblePlacement(
            index: normalizedIndex,
            role: role,
            maxTextWidth: maxTextWidth(role: role),
            minTextWidth: minTextWidth(role: role, isPrimary: isPrimary, visibleCount: count),
            horizontalOffset: horizontalOffset(for: normalizedIndex, visibleCount: count),
            verticalOffset: -rowOffset(for: normalizedIndex),
            fillOpacity: fillOpacity(role: role),
            scale: 1,
            zIndex: isPrimary ? 10 : Double(productionVisibleLimit - normalizedIndex)
        )
    }

    private static func maxTextWidth(role: PetSpeechBubbleRole) -> Double {
        switch role {
        case .status, .focus:
            return 344
        case .conversation:
            return 318
        case .overflow:
            return 288
        }
    }

    private static func minTextWidth(
        role: PetSpeechBubbleRole,
        isPrimary: Bool,
        visibleCount: Int
    ) -> Double? {
        switch role {
        case .status:
            return isPrimary && visibleCount > 1 ? 326 : nil
        case .focus:
            return 326
        case .conversation:
            return 302
        case .overflow:
            return 238
        }
    }

    private static func fillOpacity(role: PetSpeechBubbleRole) -> Double {
        switch role {
        case .status, .focus:
            return 0.96
        case .conversation:
            return 0.88
        case .overflow:
            return 0.88
        }
    }

    private static func horizontalOffset(for index: Int, visibleCount: Int) -> Double {
        guard visibleCount > 1 else { return 0 }
        switch index {
        case 0:
            return 0
        case 1:
            return -22
        case 2:
            return 24
        case 3:
            return -14
        default:
            return 18
        }
    }

    private static func rowOffset(for index: Int) -> Double {
        switch index {
        case 0:
            return 0
        case 1:
            return 57
        case 2:
            return 89
        case 3:
            return 121
        default:
            return 153
        }
    }
}
