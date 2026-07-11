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
    public let fontScale: Double
    public let rotationDegrees: Double
    public let floatingHorizontalOffset: Double
    public let floatingVerticalOffset: Double
    public let floatingDuration: Double
    public let floatingDelay: Double
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
        fontScale: Double = 1,
        rotationDegrees: Double = 0,
        floatingHorizontalOffset: Double = 0,
        floatingVerticalOffset: Double = 0,
        floatingDuration: Double = 0,
        floatingDelay: Double = 0,
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
        self.fontScale = fontScale
        self.rotationDegrees = rotationDegrees
        self.floatingHorizontalOffset = floatingHorizontalOffset
        self.floatingVerticalOffset = floatingVerticalOffset
        self.floatingDuration = floatingDuration
        self.floatingDelay = floatingDelay
        self.zIndex = zIndex
    }
}

public enum PetSpeechBubbleLayout {
    public static let productionWindowWidth = 520.0
    public static let productionWindowHeight = 520.0
    public static let productionStackWidth = 512.0
    public static let productionStackHeight = 312.0
    public static let productionTopPadding = 0.0
    public static let productionStackVisualOffsetY = -20.0
    public static let productionSpriteWidth = 192.0
    public static let productionSpriteHeight = 208.0
    public static let productionSpriteVisualOffsetY = -16.0
    public static let productionVisibleLimit = 4
    public static let productionRowSpacing = 8.0
    public static let statusTextLimit = 156
    public static let focusTextLimit = 156
    public static let conversationTextLimit = 96
    public static let overflowTextLimit = 22
    public static let chatTitleTextLimit = 34

    public static let transitionInsertionOffsetY = 62.0
    public static let transitionRemovalOffsetY = -46.0
    public static let transitionInsertionScale = 0.74
    public static let transitionRemovalScale = 0.9
    public static let stackAnimationResponse = 0.92
    public static let stackAnimationDampingFraction = 0.78
    public static let stackAnimationBlendDuration = 0.18
    public static let stackAnimationStaggerDelay = 0.1
    public static let stackAnimationMaxStaggerDelay = 0.28
    public static let stackAnimationResponseStep = 0.06
    public static let stackAnimationDampingStep = 0.018
    public static let stackAnimationMinimumDampingFraction = 0.68
    public static let birthPulseDuration = 1.35
    public static let birthPulseSpringResponse = 0.62
    public static let birthPulseSpringDampingFraction = 0.82
    public static let birthPulseFadeOutDuration = 0.5
    public static let birthPulseOffsetY = 16.0
    public static let birthPulseWidth = 112.0
    public static let birthPulseHeight = 10.0
    public static let contentAnimationDuration = 0.28
    public static let typewriterCharactersPerSecond = 10.0
    public static let typewriterFrameInterval = 1.0 / 30.0
    public static let organicPrimaryHorizontalJitter = 18.0
    public static let organicSecondaryHorizontalJitter = 254.0
    public static let organicTopRowHorizontalJitter = 286.0
    public static let organicPrimaryVerticalJitter = 16.0
    public static let organicSecondaryVerticalJitter = 92.0
    public static let organicTopRowOverlapDrop = 118.0
    public static let organicTopRowOverlapJitter = 94.0
    public static let organicPrimaryWidthJitter = 18.0
    public static let organicConversationWidthJitter = 24.0
    public static let organicOverflowWidthJitter = 16.0
    public static let organicPrimaryScaleJitter = 0.045
    public static let organicSecondaryScaleJitter = 0.07
    public static let organicPrimaryMaximumHorizontalOffset = 20.0
    public static let organicPrimaryMinimumVerticalOffset = -8.0
    public static let organicPrimaryMaximumVerticalOffset = 18.0
    public static let organicSecondaryMaximumHorizontalOffset = 220.0
    public static let organicSecondaryMinimumVerticalOffset = -204.0
    public static let organicSecondaryMaximumVerticalOffset = -82.0
    public static let organicSecondaryMinimumDistanceFromMimo = 92.0
    public static let organicSecondaryMaximumDistanceFromMimo = 222.0
    public static let organicSecondaryOrbitMinimumAngleDegrees = 22.0
    public static let organicSecondaryOrbitMaximumAngleDegrees = 158.0
    public static let organicPrimaryRotationJitter = 1.4
    public static let organicSecondaryRotationJitter = 7.0
    public static let organicPrimaryFloatingHorizontalMaximum = 1.6
    public static let organicPrimaryFloatingVerticalMaximum = 1.2
    public static let organicSecondaryFloatingHorizontalMaximum = 3.6
    public static let organicSecondaryFloatingVerticalMaximum = 2.6
    public static let organicFloatingMinimumDuration = 8.5
    public static let organicFloatingMaximumDuration = 13.5
    public static let organicFloatingMaximumDelay = 1.2
    public static let organicPrimaryMinimumFontScale = 0.94
    public static let organicPrimaryMaximumFontScale = 1.12
    public static let organicSecondaryMinimumFontScale = 0.92
    public static let organicSecondaryMaximumFontScale = 1.14
    public static let organicOverflowMinimumFontScale = 0.9
    public static let organicOverflowMaximumFontScale = 1.07

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
            return 4
        case .conversation:
            return 3
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
        case .conversation:
            return 2
        case .overflow:
            return 1
        case .status:
            return lineLimit(for: role)
        }
    }

    public static func placement(
        for index: Int,
        role: PetSpeechBubbleRole,
        visibleCount: Int,
        variationSeed: String? = nil
    ) -> PetSpeechBubblePlacement {
        let count = max(1, min(visibleCount, productionVisibleLimit))
        let normalizedIndex = max(0, min(index, count - 1))
        let isPrimary = normalizedIndex == 0

        let base = PetSpeechBubblePlacement(
            index: normalizedIndex,
            role: role,
            maxTextWidth: maxTextWidth(role: role),
            minTextWidth: minTextWidth(role: role, isPrimary: isPrimary, visibleCount: count),
            horizontalOffset: horizontalOffset(for: normalizedIndex, visibleCount: count),
            verticalOffset: -rowOffset(for: normalizedIndex, visibleCount: count),
            fillOpacity: fillOpacity(role: role),
            scale: scale(for: normalizedIndex),
            zIndex: isPrimary ? 10 : Double(productionVisibleLimit - normalizedIndex)
        )
        guard let variationSeed,
              !variationSeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return base
        }
        return organicPlacement(from: base, seed: variationSeed)
    }

    private static func maxTextWidth(role: PetSpeechBubbleRole) -> Double {
        switch role {
        case .status, .focus:
            return 404
        case .conversation:
            return 218
        case .overflow:
            return 184
        }
    }

    private static func minTextWidth(
        role: PetSpeechBubbleRole,
        isPrimary: Bool,
        visibleCount: Int
    ) -> Double? {
        switch role {
        case .status:
            return 320
        case .focus:
            return 336
        case .conversation:
            return 178
        case .overflow:
            return 154
        }
    }

    private static func fillOpacity(role: PetSpeechBubbleRole) -> Double {
        switch role {
        case .status, .focus:
            return 0.97
        case .conversation:
            return 0.92
        case .overflow:
            return 0.9
        }
    }

    private static func horizontalOffset(for index: Int, visibleCount: Int) -> Double {
        guard visibleCount > 1 else { return 0 }
        switch index {
        case 0:
            return 0
        case 1:
            return -134
        case 2:
            return 134
        case 3:
            return 18
        default:
            return 8
        }
    }

    private static func rowOffset(for index: Int, visibleCount: Int) -> Double {
        switch index {
        case 0:
            return 0
        case 1:
            return 112
        case 2:
            return 118
        case 3:
            return 172
        default:
            return 96
        }
    }

    private static func scale(for index: Int) -> Double {
        switch index {
        case 0:
            return 1
        case 1, 2:
            return 0.96
        default:
            return 0.92
        }
    }

    private static func organicPlacement(
        from base: PetSpeechBubblePlacement,
        seed: String
    ) -> PetSpeechBubblePlacement {
        let widthCenter = variationCentered(seed: seed, salt: "width-\(base.index)")
        let widthJitter = widthJitter(role: base.role, isPrimary: base.index == 0)
        let maxTextWidth = max(120, base.maxTextWidth + widthCenter * widthJitter)
        let minTextWidth = base.minTextWidth.map {
            min(maxTextWidth - 12, max(118, $0 + widthCenter * widthJitter * 0.58))
        }
        let isPrimary = base.index == 0
        let offsets = organicOffsets(from: base, maxTextWidth: maxTextWidth, seed: seed)
        let horizontalOffset = offsets.horizontal
        let verticalOffset = offsets.vertical
        let scale = clampedScale(
            base.scale + variationCentered(seed: seed, salt: "scale-\(base.index)") * scaleJitter(isPrimary: isPrimary),
            isPrimary: isPrimary,
            role: base.role
        )
        let rotationDegrees = clampedRotationDegrees(
            variationCentered(seed: seed, salt: "rotation-\(base.index)") * rotationJitter(isPrimary: isPrimary),
            isPrimary: isPrimary
        )
        let widthBias = (widthCenter + 1) / 2
        let fontBias = variationUnit(seed: seed, salt: "font-\(base.index)") * 0.34 + widthBias * 0.66
        let fontScale = fontScale(role: base.role, isPrimary: base.index == 0, bias: fontBias)
        let floatingHorizontalOffset = floatingOffset(
            seed: seed,
            salt: "float-x-\(base.index)",
            maximum: isPrimary ? organicPrimaryFloatingHorizontalMaximum : organicSecondaryFloatingHorizontalMaximum
        )
        let floatingVerticalOffset = floatingOffset(
            seed: seed,
            salt: "float-y-\(base.index)",
            maximum: isPrimary ? organicPrimaryFloatingVerticalMaximum : organicSecondaryFloatingVerticalMaximum
        )
        let floatingDuration = organicFloatingMinimumDuration +
            variationUnit(seed: seed, salt: "float-duration-\(base.index)") *
            (organicFloatingMaximumDuration - organicFloatingMinimumDuration)
        let floatingDelay = variationUnit(seed: seed, salt: "float-delay-\(base.index)") *
            organicFloatingMaximumDelay
        let zIndex = isPrimary
            ? base.zIndex
            : base.zIndex + variationUnit(seed: seed, salt: "depth-\(base.index)") * 0.72

        return PetSpeechBubblePlacement(
            index: base.index,
            role: base.role,
            maxTextWidth: maxTextWidth,
            minTextWidth: minTextWidth,
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            fillOpacity: base.fillOpacity,
            scale: scale,
            fontScale: fontScale,
            rotationDegrees: rotationDegrees,
            floatingHorizontalOffset: floatingHorizontalOffset,
            floatingVerticalOffset: floatingVerticalOffset,
            floatingDuration: floatingDuration,
            floatingDelay: floatingDelay,
            zIndex: zIndex
        )
    }

    private static func widthJitter(role: PetSpeechBubbleRole, isPrimary: Bool) -> Double {
        if isPrimary {
            return organicPrimaryWidthJitter
        }
        switch role {
        case .status, .focus, .conversation:
            return organicConversationWidthJitter
        case .overflow:
            return organicOverflowWidthJitter
        }
    }

    private static func organicHorizontalJitter(for index: Int, isPrimary: Bool) -> Double {
        if isPrimary {
            return organicPrimaryHorizontalJitter
        }
        if index >= 3 {
            return organicTopRowHorizontalJitter
        }
        return organicSecondaryHorizontalJitter
    }

    private static func organicOffsets(
        from base: PetSpeechBubblePlacement,
        maxTextWidth: Double,
        seed: String
    ) -> (horizontal: Double, vertical: Double) {
        if base.index == 0 {
            return (
                horizontal: organicPrimaryHorizontalOffset(from: base, seed: seed),
                vertical: organicPrimaryVerticalOffset(from: base, seed: seed)
            )
        }
        return organicSecondaryOffsets(from: base, maxTextWidth: maxTextWidth, seed: seed)
    }

    private static func organicPrimaryHorizontalOffset(
        from base: PetSpeechBubblePlacement,
        seed: String
    ) -> Double {
        let rawOffset = base.horizontalOffset +
            variationCentered(seed: seed, salt: "x-\(base.index)") *
            organicHorizontalJitter(for: base.index, isPrimary: true)
        return clamp(
            rawOffset,
            minimum: -organicPrimaryMaximumHorizontalOffset,
            maximum: organicPrimaryMaximumHorizontalOffset
        )
    }

    private static func verticalJitter(isPrimary: Bool) -> Double {
        isPrimary ? organicPrimaryVerticalJitter : organicSecondaryVerticalJitter
    }

    private static func organicPrimaryVerticalOffset(
        from base: PetSpeechBubblePlacement,
        seed: String
    ) -> Double {
        return clamp(
            base.verticalOffset + variationCentered(seed: seed, salt: "y-\(base.index)") * verticalJitter(isPrimary: true),
            minimum: organicPrimaryMinimumVerticalOffset,
            maximum: organicPrimaryMaximumVerticalOffset
        )
    }

    private static func organicSecondaryOffsets(
        from base: PetSpeechBubblePlacement,
        maxTextWidth: Double,
        seed: String
    ) -> (horizontal: Double, vertical: Double) {
        let maximumHorizontal = min(
            organicSecondaryMaximumHorizontalOffset,
            maximumHorizontalOffset(maxTextWidth: maxTextWidth)
        )
        guard maximumHorizontal > 0 else {
            return (0, organicSecondaryMaximumVerticalOffset)
        }

        let angle = degreesToRadians(
            organicSecondaryOrbitMinimumAngleDegrees +
            variationUnit(seed: seed, salt: "orbit-angle-\(base.index)") *
            (organicSecondaryOrbitMaximumAngleDegrees - organicSecondaryOrbitMinimumAngleDegrees)
        )
        let radius = organicSecondaryMinimumDistanceFromMimo +
            variationUnit(seed: seed, salt: "orbit-radius-\(base.index)") *
            (organicSecondaryMaximumDistanceFromMimo - organicSecondaryMinimumDistanceFromMimo)
        let orbitX = cos(angle) * radius
        let orbitY = -sin(angle) * radius
        let rowHintX = base.horizontalOffset * 0.28
        let rowHintY = base.index >= 3
            ? (base.verticalOffset + organicTopRowOverlapDrop) * 0.14
            : base.verticalOffset * 0.18
        let scatterX = variationCentered(seed: seed, salt: "x-\(base.index)") *
            organicHorizontalJitter(for: base.index, isPrimary: false) * 0.2
        let scatterY = variationCentered(seed: seed, salt: "y-\(base.index)") *
            (base.index >= 3 ? organicTopRowOverlapJitter : verticalJitter(isPrimary: false)) * 0.18

        var horizontalOffset = orbitX + rowHintX + scatterX
        var verticalOffset = orbitY + rowHintY + scatterY + organicSecondaryVerticalBias(for: base.index)
        horizontalOffset = clamp(
            horizontalOffset,
            minimum: -maximumHorizontal,
            maximum: maximumHorizontal
        )
        verticalOffset = clamp(
            verticalOffset,
            minimum: organicSecondaryMinimumVerticalOffset,
            maximum: organicSecondaryMaximumVerticalOffset
        )

        let clampedPoint = clampPointDistance(
            horizontal: horizontalOffset,
            vertical: verticalOffset,
            maximumDistance: organicSecondaryMaximumDistanceFromMimo
        )
        return (
            horizontal: clamp(
                clampedPoint.horizontal,
                minimum: -maximumHorizontal,
                maximum: maximumHorizontal
            ),
            vertical: clamp(
                clampedPoint.vertical,
                minimum: organicSecondaryMinimumVerticalOffset,
                maximum: organicSecondaryMaximumVerticalOffset
            )
        )
    }

    private static func organicSecondaryVerticalBias(for index: Int) -> Double {
        switch index {
        case 1:
            return -30
        case 2:
            return -42
        case 3:
            return -34
        default:
            return 0
        }
    }

    private static func scaleJitter(isPrimary: Bool) -> Double {
        isPrimary ? organicPrimaryScaleJitter : organicSecondaryScaleJitter
    }

    private static func rotationJitter(isPrimary: Bool) -> Double {
        isPrimary ? organicPrimaryRotationJitter : organicSecondaryRotationJitter
    }

    private static func floatingOffset(seed: String, salt: String, maximum: Double) -> Double {
        let minimum = maximum * 0.36
        let magnitude = minimum + variationUnit(seed: seed, salt: "\(salt)-magnitude") * (maximum - minimum)
        return variationCentered(seed: seed, salt: salt) >= 0 ? magnitude : -magnitude
    }

    private static func clampedScale(
        _ value: Double,
        isPrimary: Bool,
        role: PetSpeechBubbleRole
    ) -> Double {
        if isPrimary {
            return clamp(value, minimum: 0.99, maximum: 1.045)
        }
        if role == .overflow {
            return clamp(value, minimum: 0.885, maximum: 0.96)
        }
        return clamp(value, minimum: 0.91, maximum: 0.99)
    }

    private static func fontScale(role: PetSpeechBubbleRole, isPrimary: Bool, bias: Double) -> Double {
        let bounds: (minimum: Double, maximum: Double)
        if isPrimary {
            bounds = (organicPrimaryMinimumFontScale, organicPrimaryMaximumFontScale)
        } else {
            switch role {
            case .status, .focus, .conversation:
                bounds = (organicSecondaryMinimumFontScale, organicSecondaryMaximumFontScale)
            case .overflow:
                bounds = (organicOverflowMinimumFontScale, organicOverflowMaximumFontScale)
            }
        }
        return bounds.minimum + clamp(bias, minimum: 0, maximum: 1) * (bounds.maximum - bounds.minimum)
    }

    private static func maximumHorizontalOffset(maxTextWidth: Double) -> Double {
        let inset = 28.0
        return max(0, productionStackWidth / 2 - maxTextWidth / 2 - inset)
    }

    private static func clampedRotationDegrees(_ value: Double, isPrimary: Bool) -> Double {
        let maximum = isPrimary ? organicPrimaryRotationJitter : organicSecondaryRotationJitter
        return clamp(value, minimum: -maximum, maximum: maximum)
    }

    private static func variationCentered(seed: String, salt: String) -> Double {
        variationUnit(seed: seed, salt: salt) * 2 - 1
    }

    private static func variationUnit(seed: String, salt: String) -> Double {
        let hash = stableHash("\(seed)|\(salt)")
        return Double(hash % 10_000) / 9_999.0
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func clampPointDistance(
        horizontal: Double,
        vertical: Double,
        maximumDistance: Double
    ) -> (horizontal: Double, vertical: Double) {
        let distance = hypot(horizontal, vertical)
        guard distance > maximumDistance, distance > 0 else {
            return (horizontal, vertical)
        }
        let scale = maximumDistance / distance
        return (horizontal * scale, vertical * scale)
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func clamp(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
