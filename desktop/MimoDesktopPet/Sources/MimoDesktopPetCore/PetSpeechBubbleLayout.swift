import Foundation

public struct PetSpeechBubblePlacement: Equatable, Sendable {
    public let index: Int
    public let role: PetSpeechBubbleRole
    public let maxTextWidth: Double
    public let horizontalOffset: Double
    public let verticalOffset: Double
    public let fillOpacity: Double
    public let scale: Double
    public let zIndex: Double

    public init(
        index: Int,
        role: PetSpeechBubbleRole,
        maxTextWidth: Double,
        horizontalOffset: Double,
        verticalOffset: Double,
        fillOpacity: Double,
        scale: Double,
        zIndex: Double
    ) {
        self.index = index
        self.role = role
        self.maxTextWidth = maxTextWidth
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
    public static let statusTextLimit = 44
    public static let focusTextLimit = 48
    public static let conversationTextLimit = 34
    public static let overflowTextLimit = 22
    public static let clusterGuideOpacity = 0.045
    public static let clusterGuideLineWidth = 1.0

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
        let offsets: [(x: Double, y: Double)]
        switch count {
        case 1:
            offsets = [(0, 0)]
        case 2:
            offsets = [(0, 0), (-100, -76)]
        case 3:
            offsets = [(0, 0), (-106, -78), (104, -132)]
        case 4:
            offsets = [(0, 0), (-106, -70), (104, -122), (-54, -174)]
        default:
            offsets = [(0, 0), (-108, -58), (108, -98), (-92, -144), (66, -186)]
        }
        let offset = offsets[normalizedIndex]
        let isPrimary = normalizedIndex == 0

        return PetSpeechBubblePlacement(
            index: normalizedIndex,
            role: role,
            maxTextWidth: maxTextWidth(role: role),
            horizontalOffset: offset.x,
            verticalOffset: offset.y,
            fillOpacity: fillOpacity(role: role),
            scale: scale(role: role, isPrimary: isPrimary),
            zIndex: isPrimary ? 10 : Double(productionVisibleLimit - normalizedIndex)
        )
    }

    private static func maxTextWidth(role: PetSpeechBubbleRole) -> Double {
        switch role {
        case .status, .focus:
            return 318
        case .conversation:
            return 204
        case .overflow:
            return 176
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

    private static func scale(role: PetSpeechBubbleRole, isPrimary: Bool) -> Double {
        switch role {
        case .status, .focus:
            return isPrimary ? 1.0 : 0.94
        case .conversation:
            return 0.9
        case .overflow:
            return 0.9
        }
    }
}
