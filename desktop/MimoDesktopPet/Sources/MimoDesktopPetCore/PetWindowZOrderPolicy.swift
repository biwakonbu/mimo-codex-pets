import Foundation

public enum PetWindowLevelKind: Equatable, Sendable {
    case screenSaver
}

public struct PetWindowZOrderPolicy: Equatable, Sendable {
    public var levelKind: PetWindowLevelKind
    public var joinsAllSpaces: Bool
    public var joinsFullscreenSpaces: Bool
    public var staysOutOfWindowCycle: Bool
    public var staysVisibleWhenInactive: Bool

    public init(
        levelKind: PetWindowLevelKind,
        joinsAllSpaces: Bool,
        joinsFullscreenSpaces: Bool,
        staysOutOfWindowCycle: Bool,
        staysVisibleWhenInactive: Bool
    ) {
        self.levelKind = levelKind
        self.joinsAllSpaces = joinsAllSpaces
        self.joinsFullscreenSpaces = joinsFullscreenSpaces
        self.staysOutOfWindowCycle = staysOutOfWindowCycle
        self.staysVisibleWhenInactive = staysVisibleWhenInactive
    }

    public static let alwaysOnTopCompanion = PetWindowZOrderPolicy(
        levelKind: .screenSaver,
        joinsAllSpaces: true,
        joinsFullscreenSpaces: true,
        staysOutOfWindowCycle: true,
        staysVisibleWhenInactive: true
    )
}
