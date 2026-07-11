import Foundation

public enum PetKataribeNarrationPolicy {
    public static let restSettleDelay: TimeInterval = 0.8

    public static func shouldAdvanceAfterTimeout(isPetMoving: Bool) -> Bool {
        !isPetMoving
    }
}
