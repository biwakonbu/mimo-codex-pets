import XCTest
@testable import MimoDesktopPetCore

final class AtlasContractTests: XCTestCase {
    func testAtlasGeometryMatchesCodexPetContract() {
        XCTAssertEqual(PetAtlasContract.atlasWidth, 1_536)
        XCTAssertEqual(PetAtlasContract.atlasHeight, 1_872)
        XCTAssertEqual(PetAtlasContract.columns, 8)
        XCTAssertEqual(PetAtlasContract.rows, 9)
        XCTAssertEqual(PetAtlasContract.cellWidth, 192)
        XCTAssertEqual(PetAtlasContract.cellHeight, 208)
    }

    func testRowOrderAndFrameCountsMatchMimoContract() {
        let states = PetAtlasContract.rowSpecs.map(\.state)
        XCTAssertEqual(states, [
            .idle,
            .runningRight,
            .runningLeft,
            .waving,
            .jumping,
            .failed,
            .waiting,
            .running,
            .review
        ])

        XCTAssertEqual(PetAtlasContract.spec(for: .idle).frameCount, 6)
        XCTAssertEqual(PetAtlasContract.spec(for: .runningRight).frameCount, 8)
        XCTAssertEqual(PetAtlasContract.spec(for: .runningLeft).frameCount, 8)
        XCTAssertEqual(PetAtlasContract.spec(for: .waving).frameCount, 4)
        XCTAssertEqual(PetAtlasContract.spec(for: .jumping).frameCount, 5)
        XCTAssertEqual(PetAtlasContract.spec(for: .failed).frameCount, 8)
        XCTAssertEqual(PetAtlasContract.spec(for: .waiting).frameCount, 6)
        XCTAssertEqual(PetAtlasContract.spec(for: .running).frameCount, 6)
        XCTAssertEqual(PetAtlasContract.spec(for: .review).frameCount, 6)
    }
}
