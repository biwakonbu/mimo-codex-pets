import XCTest
@testable import MimoDesktopPetCore

final class CodexConversationExtractorTests: XCTestCase {
    func testExtractsRecentUserAssistantAndToolLines() {
        let thread: [String: Any] = [
            "id": "thread-a",
            "name": "実装スレッド",
            "turns": [
                [
                    "id": "turn-1",
                    "status": "completed",
                    "items": [
                        [
                            "id": "item-user",
                            "type": "userMessage",
                            "content": [
                                ["type": "inputText", "text": "ドラッグを直して"]
                            ]
                        ],
                        [
                            "id": "item-agent",
                            "type": "agentMessage",
                            "content": [
                                ["type": "outputText", "text": "ハンドラーを分離してテストしました"]
                            ]
                        ],
                        [
                            "id": "item-command",
                            "type": "commandExecution",
                            "command": ["swift", "test"]
                        ]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].speaker, "you")
        XCTAssertEqual(lines[0].text, "ドラッグを直して")
        XCTAssertEqual(lines[1].speaker, "codex")
        XCTAssertTrue(lines[1].isAssistant)
        XCTAssertEqual(lines[2].speaker, "tool")
        XCTAssertEqual(lines[2].text, "実行: swift test")
    }

    func testFallsBackToThreadPreviewWhenTurnsHaveNoItems() {
        let thread: [String: Any] = [
            "id": "thread-b",
            "preview": "Mimo の待機モーションを調整して"
        ]

        let lines = CodexConversationExtractor.lines(from: thread)

        XCTAssertEqual(lines, [
            CodexConversationLine(
                threadId: "thread-b",
                threadTitle: "Mimo の待機モーションを調整して",
                speaker: "thread",
                text: "Mimo の待機モーションを調整して",
                isAssistant: false
            )
        ])
    }

    func testExtractsSchemaThreadItemFields() {
        let thread: [String: Any] = [
            "id": "thread-schema",
            "name": "schema",
            "turns": [
                [
                    "id": "turn-1",
                    "status": "completed",
                    "items": [
                        ["id": "agent", "type": "agentMessage", "text": "実データの text を表示"],
                        ["id": "command", "type": "commandExecution", "command": "swift test"],
                        ["id": "mcp", "type": "mcpToolCall", "tool": "get_app_state"]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread)

        XCTAssertEqual(lines.map(\.text), [
            "実データの text を表示",
            "実行: swift test",
            "ツール: get_app_state"
        ])
    }

    func testExtractsAdditionalSchemaItemsWithoutDumpingPayloads() {
        let thread: [String: Any] = [
            "id": "thread-items",
            "name": "schema-items",
            "turns": [
                [
                    "id": "turn-1",
                    "status": "inProgress",
                    "items": [
                        ["id": "plan", "type": "plan", "text": "UI 表示を確認してから E2E を通す"],
                        ["id": "reasoning", "type": "reasoning", "summary": ["表示制約を整理"]],
                        [
                            "id": "dynamic",
                            "type": "dynamicToolCall",
                            "tool": "use_figma",
                            "arguments": #"{"secret":"do-not-show"}"#,
                            "status": "inProgress"
                        ],
                        ["id": "search", "type": "webSearch", "query": "private query should not show"],
                        ["id": "image", "type": "imageGeneration", "status": "inProgress"],
                        ["id": "compact", "type": "contextCompaction"],
                        ["id": "review", "type": "enteredReviewMode", "review": [:]],
                        ["id": "hook", "type": "hookPrompt", "fragments": [["text": "not user facing"]]]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread, maxLines: 20)

        XCTAssertEqual(lines.map(\.text), [
            "計画: UI 表示を確認してから E2E を通す",
            "表示制約を整理",
            "ツール: use_figma",
            "Web 検索中",
            "画像を生成中",
            "文脈を整理中",
            "レビューを開始"
        ])
        XCTAssertFalse(lines.map(\.text).joined(separator: " ").contains("secret"))
        XCTAssertFalse(lines.map(\.text).joined(separator: " ").contains("private query"))
    }

    func testBuildsGenericProgressLinesForDeltaNotifications() {
        let command = CodexConversationExtractor.progressLine(
            threadId: "thread-delta",
            threadTitle: "Delta QA",
            kind: "commandExecutionOutputDelta"
        )
        let agent = CodexConversationExtractor.progressLine(
            threadId: "thread-delta",
            threadTitle: "Delta QA",
            kind: "agentMessageDelta"
        )

        XCTAssertEqual(command.speaker, "tool")
        XCTAssertEqual(command.text, "コマンド出力を確認中")
        XCTAssertEqual(agent.speaker, "codex")
        XCTAssertEqual(agent.text, "応答を作成中")

        let plan = CodexConversationExtractor.progressLine(
            threadId: "thread-delta",
            threadTitle: "Delta QA",
            kind: "turnPlanUpdated"
        )
        let reasoning = CodexConversationExtractor.progressLine(
            threadId: "thread-delta",
            threadTitle: "Delta QA",
            kind: "reasoningDelta"
        )

        XCTAssertEqual(plan.text, "計画を更新中")
        XCTAssertEqual(reasoning.text, "文脈を整理中")
    }

    func testSuppressesMachinePayloadText() {
        let thread: [String: Any] = [
            "id": "thread-payload",
            "name": "payload",
            "turns": [
                [
                    "id": "turn-1",
                    "status": "completed",
                    "items": [
                        [
                            "id": "agent",
                            "type": "agentMessage",
                            "text": #"{"bundle_id":null,"question":null,"element_id":null}"#
                        ]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread)

        XCTAssertEqual(lines.map(\.text), ["応答を受信"])
    }

    func testTruncatesLongTextForBubbleDisplay() {
        let longText = String(repeating: "長い本文", count: 40)
        let thread: [String: Any] = [
            "id": "thread-c",
            "name": "長文",
            "turns": [
                [
                    "id": "turn-1",
                    "items": [
                        ["id": "item-agent", "type": "agentMessage", "content": longText]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread)

        XCTAssertEqual(lines.count, 1)
        XCTAssertLessThanOrEqual(lines[0].text.count, 79)
        XCTAssertTrue(lines[0].text.hasSuffix("..."))
    }
}
