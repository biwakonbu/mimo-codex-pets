import XCTest
@testable import MimoDesktopPetCore

final class CodexNotificationTests: XCTestCase {
    func testSupportedNotificationMethodNames() {
        XCTAssertEqual(CodexNotificationMethod.allCases.map(\.rawValue), [
            "thread/status/changed",
            "thread/name/updated",
            "thread/archived",
            "thread/closed",
            "thread/deleted",
            "thread/unarchived",
            "turn/started",
            "turn/completed",
            "turn/plan/updated",
            "item/started",
            "item/completed",
            "item/agentMessage/delta",
            "item/plan/delta",
            "item/reasoning/summaryPartAdded",
            "item/reasoning/summaryTextDelta",
            "item/reasoning/textDelta",
            "item/commandExecution/outputDelta",
            "item/fileChange/outputDelta",
            "item/mcpToolCall/progress"
        ])
    }

    func testThreadStatusNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "thread/status/changed",
          "params": {
            "threadId": "thread-1",
            "status": {
              "type": "active",
              "activeFlags": ["waitingOnUserInput"]
            }
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadStatusChangedNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "thread/status/changed")
        XCTAssertEqual(notification.params.threadId, "thread-1")
        XCTAssertEqual(notification.params.status, .active(activeFlags: [.waitingOnUserInput]))
    }

    func testThreadStatusDecodeIgnoresUnknownActiveFlags() throws {
        let data = Data("""
        {
          "method": "thread/status/changed",
          "params": {
            "threadId": "thread-1",
            "status": {
              "type": "active",
              "activeFlags": ["waitingOnUserInput", "futureFlag"]
            }
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadStatusChangedNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.params.status, .active(activeFlags: [.waitingOnUserInput]))
    }

    func testTurnCompletedNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "turn/completed",
          "params": {
            "threadId": "thread-1",
            "turn": {
              "id": "turn-1",
              "status": "completed"
            }
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<TurnNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "turn/completed")
        XCTAssertEqual(notification.params.turn.status, .completed)
    }

    func testTurnNotificationTreatsUnknownStatusAsInProgress() throws {
        let data = Data("""
        {
          "method": "turn/completed",
          "params": {
            "threadId": "thread-1",
            "turn": {
              "id": "turn-1",
              "status": "futureStatus"
            }
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<TurnNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.params.turn.status, .inProgress)
    }

    func testThreadSnapshotDefaultsMissingStatusWithoutDroppingTurns() throws {
        let data = Data("""
        {
          "id": "thread-1",
          "turns": [
            {
              "id": "turn-1",
              "status": "futureStatus"
            },
            {
              "id": "turn-2"
            }
          ]
        }
        """.utf8)

        let snapshot = try JSONDecoder().decode(CodexThreadSnapshot.self, from: data)

        XCTAssertEqual(snapshot.status, .idle)
        XCTAssertEqual(snapshot.turns.map(\.status), [.inProgress, .inProgress])
    }

    func testItemLifecycleNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "item/completed",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "item": { "type": "agentMessage" },
            "completedAtMs": 100
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ItemLifecycleNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "item/completed")
        XCTAssertEqual(notification.params.threadId, "thread-1")
        XCTAssertEqual(notification.params.turnId, "turn-1")
    }

    func testItemTextDeltaNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "item/agentMessage/delta",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "itemId": "item-1",
            "delta": "partial output"
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ItemTextDeltaNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "item/agentMessage/delta")
        XCTAssertEqual(notification.params.itemId, "item-1")
        XCTAssertEqual(notification.params.delta, "partial output")
    }

    func testMcpToolCallProgressNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "item/mcpToolCall/progress",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "itemId": "item-1",
            "message": "Fetching UI tree"
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<McpToolCallProgressNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "item/mcpToolCall/progress")
        XCTAssertEqual(notification.params.message, "Fetching UI tree")
    }

    func testThreadNameNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "thread/name/updated",
          "params": {
            "threadId": "thread-1",
            "threadName": "更新されたスレッド"
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadNameUpdatedNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "thread/name/updated")
        XCTAssertEqual(notification.params.threadId, "thread-1")
        XCTAssertEqual(notification.params.threadName, "更新されたスレッド")
    }

    func testThreadLifecycleNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "thread/closed",
          "params": {
            "threadId": "thread-1"
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadIdNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "thread/closed")
        XCTAssertEqual(notification.params.threadId, "thread-1")
    }
}
