import Foundation

public enum PetAtlasContract {
    public static let atlasWidth = 1_536
    public static let atlasHeight = 1_872
    public static let columns = 8
    public static let rows = 9
    public static let cellWidth = 192
    public static let cellHeight = 208

    public static let rowSpecs: [PetAnimationSpec] = [
        PetAnimationSpec(state: .idle, row: 0, frameCount: 6),
        PetAnimationSpec(state: .runningRight, row: 1, frameCount: 8),
        PetAnimationSpec(state: .runningLeft, row: 2, frameCount: 8),
        PetAnimationSpec(state: .waving, row: 3, frameCount: 4),
        PetAnimationSpec(state: .jumping, row: 4, frameCount: 5),
        PetAnimationSpec(state: .failed, row: 5, frameCount: 8),
        PetAnimationSpec(state: .waiting, row: 6, frameCount: 6),
        PetAnimationSpec(state: .running, row: 7, frameCount: 6),
        PetAnimationSpec(state: .review, row: 8, frameCount: 6)
    ]

    public static func spec(for state: PetAnimationState) -> PetAnimationSpec {
        guard let spec = rowSpecs.first(where: { $0.state == state }) else {
            preconditionFailure("Missing animation spec for \(state.rawValue)")
        }
        return spec
    }
}
