import Foundation

public enum PetDebugOverlayPolicy {
    public static let environmentKey = "MIMO_DEBUG_OVERLAY"

    public static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentKey] == "1"
    }
}
