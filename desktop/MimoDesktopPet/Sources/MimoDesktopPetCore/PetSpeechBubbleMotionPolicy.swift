import Foundation

public enum PetSpeechBubbleMotionPolicy {
    public static func shouldTriggerBirthPulse(
        previousIDs: [String],
        nextIDs: [String]
    ) -> Bool {
        guard !previousIDs.isEmpty, !nextIDs.isEmpty else { return false }
        let previous = Set(previousIDs)
        if nextIDs.contains(where: { !previous.contains($0) }) {
            return true
        }
        return previousIDs.first != nextIDs.first
    }
}
