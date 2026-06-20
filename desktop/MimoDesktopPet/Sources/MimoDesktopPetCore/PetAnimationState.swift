import Foundation

public enum PetAnimationState: String, CaseIterable, Codable, Equatable, Sendable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review
}

public struct PetAnimationSpec: Equatable, Sendable {
    public let state: PetAnimationState
    public let row: Int
    public let frameCount: Int

    public init(state: PetAnimationState, row: Int, frameCount: Int) {
        self.state = state
        self.row = row
        self.frameCount = frameCount
    }
}
