import Foundation
import XCTest
@testable import MimoDesktopPetCore

final class CodexThreadTimestampTests: XCTestCase {
    func testThreadSnapshotUsesRecencyTimestampForLastActivity() throws {
        let snapshot = try decodeSnapshot(
            """
            {
              "id": "chat-1",
              "status": {"type": "notLoaded"},
              "createdAt": "2026-07-11T08:00:00Z",
              "updatedAt": "2026-07-11T08:20:00Z",
              "recencyAt": "2026-07-11T08:30:00Z",
              "turns": [{
                "id": "turn-1",
                "status": "completed",
                "startedAt": "2026-07-11T08:10:00Z",
                "completedAt": "2026-07-11T08:25:00Z"
              }]
            }
            """
        )

        XCTAssertEqual(snapshot.turns.last?.status, .completed)
        XCTAssertEqual(snapshot.lastActivityDate, CodexTimestampParser.date(from: "2026-07-11T08:30:00Z"))
    }

    func testTimestampParserAcceptsMillisecondsSinceEpoch() {
        let milliseconds = 1_700_000_000_000.0
        XCTAssertEqual(
            CodexTimestampParser.date(from: milliseconds),
            Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testTimestampParserAcceptsNumericStringSinceEpoch() {
        XCTAssertEqual(
            CodexTimestampParser.date(from: "1700000000000"),
            Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func decodeSnapshot(_ json: String) throws -> CodexThreadSnapshot {
        try JSONDecoder().decode(CodexThreadSnapshot.self, from: Data(json.utf8))
    }
}
