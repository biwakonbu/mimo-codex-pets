import Foundation

public enum CodexMimoDialogueCadencePolicy {
    public static func shouldOrganize(
        lastOrganizationAge: TimeInterval?,
        interval: TimeInterval
    ) -> Bool {
        guard let lastOrganizationAge else { return true }
        return lastOrganizationAge >= max(0, interval)
    }
}
