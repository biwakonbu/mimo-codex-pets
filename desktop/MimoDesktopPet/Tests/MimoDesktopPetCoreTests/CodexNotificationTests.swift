import XCTest
@testable import MimoDesktopPetCore

final class CodexNotificationTests: XCTestCase {
    func testSupportedNotificationMethodNames() {
        XCTAssertEqual(CodexNotificationMethod.allCases.map(\.rawValue), [
            "thread/started",
            "thread/status/changed",
            "thread/name/updated",
            "thread/goal/updated",
            "thread/goal/cleared",
            "thread/archived",
            "thread/closed",
            "thread/deleted",
            "thread/unarchived",
            "hook/started",
            "hook/completed",
            "turn/started",
            "turn/completed",
            "turn/plan/updated",
            "turn/diff/updated",
            "item/started",
            "item/completed",
            "item/autoApprovalReview/started",
            "item/autoApprovalReview/completed",
            "item/agentMessage/delta",
            "item/plan/delta",
            "item/reasoning/summaryPartAdded",
            "item/reasoning/summaryTextDelta",
            "item/reasoning/textDelta",
            "item/commandExecution/outputDelta",
            "item/commandExecution/terminalInteraction",
            "item/fileChange/outputDelta",
            "item/fileChange/patchUpdated",
            "item/mcpToolCall/progress",
            "serverRequest/resolved"
        ])
    }

    func testIntentionallyIgnoredNotificationMethodNames() {
        XCTAssertEqual(CodexIgnoredNotificationMethod.allCases.map(\.rawValue), [
            "error",
            "skills/changed",
            "thread/settings/updated",
            "thread/tokenUsage/updated",
            "command/exec/outputDelta",
            "process/outputDelta",
            "process/exited",
            "mcpServer/oauthLogin/completed",
            "mcpServer/startupStatus/updated",
            "account/updated",
            "account/rateLimits/updated",
            "app/list/updated",
            "remoteControl/status/changed",
            "externalAgentConfig/import/completed",
            "fs/changed",
            "thread/compacted",
            "model/rerouted",
            "model/verification",
            "turn/moderationMetadata",
            "warning",
            "guardianWarning",
            "deprecationNotice",
            "configWarning",
            "fuzzyFileSearch/sessionUpdated",
            "fuzzyFileSearch/sessionCompleted",
            "thread/realtime/started",
            "thread/realtime/itemAdded",
            "thread/realtime/transcript/delta",
            "thread/realtime/transcript/done",
            "thread/realtime/outputAudio/delta",
            "thread/realtime/sdp",
            "thread/realtime/error",
            "thread/realtime/closed",
            "windows/worldWritableWarning",
            "windowsSandbox/setupCompleted",
            "account/login/completed"
        ])
    }

    func testHandledAndIgnoredNotificationMethodsDoNotOverlap() {
        let handled = Set(CodexNotificationMethod.allCases.map(\.rawValue))
        let ignored = Set(CodexIgnoredNotificationMethod.allCases.map(\.rawValue))

        XCTAssertTrue(handled.isDisjoint(with: ignored))
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

    func testThreadStartedNotificationDecodes() throws {
        let data = Data("""
        {
          "method": "thread/started",
          "params": {
            "thread": {
              "id": "thread-new",
              "status": {
                "type": "active",
                "activeFlags": []
              },
              "turns": [
                {
                  "id": "turn-new",
                  "status": "inProgress"
                }
              ]
            }
          }
        }
        """.utf8)

        let notification = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadStartedNotification>.self,
            from: data
        )

        XCTAssertEqual(notification.method, "thread/started")
        XCTAssertEqual(notification.params.thread.id, "thread-new")
        XCTAssertEqual(notification.params.thread.status, .active(activeFlags: []))
        XCTAssertEqual(notification.params.thread.turns.last?.status, .inProgress)
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

    func testThreadTurnProgressNotificationsDecodeThreadContext() throws {
        let diffData = Data("""
        {
          "method": "turn/diff/updated",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "diff": "raw diff must not be displayed"
          }
        }
        """.utf8)
        let hookData = Data("""
        {
          "method": "hook/started",
          "params": {
            "threadId": "thread-1",
            "turnId": null,
            "run": { "id": "hook-run" }
          }
        }
        """.utf8)

        let diff = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadTurnNotification>.self,
            from: diffData
        )
        let hook = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadTurnNotification>.self,
            from: hookData
        )

        XCTAssertEqual(diff.method, "turn/diff/updated")
        XCTAssertEqual(diff.params.threadId, "thread-1")
        XCTAssertEqual(diff.params.turnId, "turn-1")
        XCTAssertEqual(hook.method, "hook/started")
        XCTAssertEqual(hook.params.threadId, "thread-1")
        XCTAssertNil(hook.params.turnId)
    }

    func testApprovalAndServerRequestNotificationsDecodeThreadContext() throws {
        let approvalData = Data("""
        {
          "method": "item/autoApprovalReview/completed",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "reviewId": "review-1",
            "startedAtMs": 100,
            "completedAtMs": 200,
            "decisionSource": "auto",
            "action": { "type": "command", "command": "secret command" },
            "review": { "type": "approved" }
          }
        }
        """.utf8)
        let requestData = Data("""
        {
          "method": "serverRequest/resolved",
          "params": {
            "threadId": "thread-1",
            "requestId": "request-1"
          }
        }
        """.utf8)

        let approval = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadTurnNotification>.self,
            from: approvalData
        )
        let request = try JSONDecoder().decode(
            CodexJSONRPCNotification<ThreadIdNotification>.self,
            from: requestData
        )

        XCTAssertEqual(approval.method, "item/autoApprovalReview/completed")
        XCTAssertEqual(approval.params.threadId, "thread-1")
        XCTAssertEqual(approval.params.turnId, "turn-1")
        XCTAssertEqual(request.method, "serverRequest/resolved")
        XCTAssertEqual(request.params.threadId, "thread-1")
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
