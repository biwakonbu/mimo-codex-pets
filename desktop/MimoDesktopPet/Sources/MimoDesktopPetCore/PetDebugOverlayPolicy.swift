import Foundation

public enum PetDebugOverlayPolicy {
    public static let environmentKey = "MIMO_DEBUG_OVERLAY"
    public static let menuEnvironmentKey = "MIMO_DEBUG_MENU"

    public static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentKey] == "1"
    }

    public static func isMenuVisible(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        isEnabled(environment: environment) || environment[menuEnvironmentKey] == "1"
    }
}
