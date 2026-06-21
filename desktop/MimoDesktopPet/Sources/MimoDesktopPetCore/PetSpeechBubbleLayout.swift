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
    public static let productionWindowHeight = 530.0
    public static let productionStackWidth = 424.0
    public static let productionStackHeight = 318.0
    public static let productionSpriteWidth = 192.0
    public static let productionSpriteHeight = 208.0
    public static let productionVisibleLimit = 5
    public static let productionRowSpacing = 5.0
    public static let statusTextLimit = 156
    public static let focusTextLimit = 156
    public static let conversationTextLimit = 96
    public static let overflowTextLimit = 22
    public static let chatTitleTextLimit = 34

    public static let transitionInsertionOffsetY = 18.0
    public static let transitionRemovalOffsetY = -14.0
    public static let transitionInsertionScale = 0.96
    public static let transitionRemovalScale = 0.98
    public static let stackAnimationResponse = 0.34
    public static let stackAnimationDampingFraction = 0.86
    public static let contentAnimationDuration = 0.18
    public static let typewriterCharactersPerSecond = 48.0
    public static let typewriterFrameInterval = 1.0 / 30.0

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
            return 3
        case .conversation:
            return 2
        case .overflow:
            return 1
        }
    }

    public static func titleLineLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .focus, .conversation:
            return 2
        case .status, .overflow:
            return 1
        }
    }

    public static func summaryLineLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .focus:
            return 2
        case .conversation, .overflow:
            return 1
        case .status:
            return lineLimit(for: role)
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
            return 416
        case .conversation:
            return 392
        case .overflow:
            return 320
        }
    }

    private static func minTextWidth(
        role: PetSpeechBubbleRole,
        isPrimary: Bool,
        visibleCount: Int
    ) -> Double? {
        switch role {
        case .status:
            return 398
        case .focus:
            return 398
        case .conversation:
            return 370
        case .overflow:
            return 270
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
            return -10
        case 2:
            return 12
        case 3:
            return -8
        default:
            return 10
        }
    }

    private static func rowOffset(for index: Int) -> Double {
        switch index {
        case 0:
            return 0
        case 1:
            return 78
        case 2:
            return 126
        case 3:
            return 174
        default:
            return 222
        }
    }
}
