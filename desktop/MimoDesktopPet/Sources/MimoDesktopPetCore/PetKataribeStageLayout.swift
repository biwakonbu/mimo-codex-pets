import Foundation

public enum PetKataribeStageLayout {
    public static let windowWidth = 520.0
    public static let windowHeight = 520.0

    public static let reportBottom = 270.0
    public static let reportWidth = 350.0
    public static let reportFrame = reportFrame(forTextLength: reportTextLimit)
    public static let charmRailX = 368.0
    public static let charmRailY = 80.0
    public static let charmWidth = 142.0
    public static let charmHeight = 29.0
    public static let charmSpacing = 3.0
    public static let reportTextLimit = 64
    public static let compactReportTextLimit = 34
    public static let mediumReportTextLimit = reportTextLimit
    public static let typewriterCharactersPerSecond = 16.0
    public static let spriteFrame = PetDragFrame(
        x: 134,
        y: 258,
        width: 224,
        height: 243
    )

    public static func reportFrame(forTextLength textLength: Int) -> PetDragFrame {
        let height: Double
        switch max(0, textLength) {
        case ...compactReportTextLimit:
            height = 128
        default:
            height = 184
        }
        return PetDragFrame(
            x: 10,
            y: reportBottom - height,
            width: reportWidth,
            height: height
        )
    }

    public static func charmFrame(at index: Int, totalCount: Int = PetKataribeStagePlanner.maximumCharmCount) -> PetDragFrame {
        let count = min(max(1, totalCount), PetKataribeStagePlanner.maximumCharmCount)
        let resolvedIndex = min(max(0, index), count - 1)
        let emptyLeadingSlots = PetKataribeStagePlanner.maximumCharmCount - count
        return PetDragFrame(
            x: charmRailX,
            y: charmRailY + Double(emptyLeadingSlots + resolvedIndex) * (charmHeight + charmSpacing),
            width: charmWidth,
            height: charmHeight
        )
    }
}

public enum PetKataribeCharmMotion {
    public static let breathingScale = 1.014
    public static let breathingOffsetY = -1.2
    public static let updatePulseScale = 1.018
    public static let updatePulseHalfDuration = 0.38
    public static let updatePulseCount = 2
    public static let hoverScale = 1.008
    public static let feedInsertionOffsetY = 16.0
    public static let feedRemovalOffsetY = -12.0
    public static let feedSpringResponse = 0.78
    public static let feedSpringDamping = 0.84
    public static let feedPropagationDelay = 0.035
}
