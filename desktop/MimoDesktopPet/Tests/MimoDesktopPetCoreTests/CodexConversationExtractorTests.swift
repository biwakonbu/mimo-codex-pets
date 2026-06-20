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
