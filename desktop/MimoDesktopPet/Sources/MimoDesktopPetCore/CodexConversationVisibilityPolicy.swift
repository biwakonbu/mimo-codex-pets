import Foundation

public enum CodexConversationVisibilityPolicy {
    public static let recentlyStoppedWindow: TimeInterval = 30 * 60

    public static func shouldShow(
        threadStatus: CodexThreadStatus?,
        latestTurnStatus: CodexTurnStatus?,
        lastActivityAge: TimeInterval?
    ) -> Bool {
        if case .active = threadStatus {
            return true
        }
        if latestTurnStatus == .inProgress {
            return true
        }
        guard let lastActivityAge else {
            return false
        }
        return lastActivityAge <= recentlyStoppedWindow
    }
}
