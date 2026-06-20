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
        XCTAssertEqual(lines[2].text, "テストを実行中")
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
            "テストを実行中",
            "ツールを使用中"
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
            "ツールを使用中",
            "Web 検索中",
            "画像を生成中",
            "文脈を整理中",
            "レビューを開始"
        ])
        XCTAssertFalse(lines.map(\.text).joined(separator: " ").contains("secret"))
        XCTAssertFalse(lines.map(\.text).joined(separator: " ").contains("private query"))
        XCTAssertFalse(lines.map(\.text).joined(separator: " ").contains("use_figma"))
    }

    func testExtractsBrowserFileImageSkillItemsWithoutDumpingArguments() {
        let thread: [String: Any] = [
            "id": "thread-surface-items",
            "name": "surface-items",
            "turns": [
                [
                    "id": "turn-1",
                    "status": "inProgress",
                    "items": [
                        ["id": "open", "type": "openPage", "url": "https://example.com/private-path"],
                        ["id": "find", "type": "findInPage", "query": "secret search term"],
                        ["id": "files", "type": "listFiles", "path": "/Users/example/private"],
                        ["id": "read", "type": "read", "path": "/Users/example/private/file.swift"],
                        ["id": "search", "type": "search", "query": "private symbol"],
                        ["id": "image", "type": "localImage", "path": "/Users/example/Desktop/private.png"],
                        ["id": "skill", "type": "skill", "name": "private-skill-name"],
                        ["id": "mention", "type": "mention", "target": "private-thread"]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread, maxLines: 20)

        XCTAssertEqual(lines.map(\.text), [
            "ページを確認中",
            "ページ内を検索中",
            "ファイル一覧を確認中",
            "ファイルを確認中",
            "検索中",
            "画像を確認中",
            "スキルを確認中",
            "参照を確認中"
        ])

        let joined = lines.map(\.text).joined(separator: " ")
        XCTAssertFalse(joined.contains("example.com"))
        XCTAssertFalse(joined.contains("/Users/example"))
        XCTAssertFalse(joined.contains("secret search term"))
        XCTAssertFalse(joined.contains("private-skill-name"))
        XCTAssertFalse(joined.contains("private-thread"))
    }

    func testCommandAndToolItemsAreSanitizedBeforeBubblePlanning() {
        let thread: [String: Any] = [
            "id": "thread-sensitive-tools",
            "name": "sensitive-tools",
            "turns": [
                [
                    "id": "turn-1",
                    "status": "inProgress",
                    "items": [
                        [
                            "id": "command",
                            "type": "commandExecution",
                            "command": "cat /Users/example/private/project/.env && curl https://example.com/token"
                        ],
                        [
                            "id": "test-command",
                            "type": "commandExecution",
                            "command": ["swift", "test", "--filter", "SecretSuite"]
                        ],
                        [
                            "id": "mcp",
                            "type": "mcpToolCall",
                            "tool": "read_secret_workspace_file",
                            "arguments": #"{"path":"/Users/example/private/project/file.swift"}"#
                        ],
                        [
                            "id": "dynamic",
                            "type": "dynamicToolCall",
                            "namespace": "private_connector",
                            "tool": "secret_operation"
                        ]
                    ]
                ]
            ]
        ]

        let lines = CodexConversationExtractor.lines(from: thread, maxLines: 20)

        XCTAssertEqual(lines.map(\.text), [
            "コマンドを実行中",
            "テストを実行中",
            "ツールを使用中",
            "ツールを使用中"
        ])

        let joined = lines.map(\.text).joined(separator: " ")
        XCTAssertFalse(joined.contains("/Users/example"))
        XCTAssertFalse(joined.contains(".env"))
        XCTAssertFalse(joined.contains("example.com/token"))
        XCTAssertFalse(joined.contains("SecretSuite"))
        XCTAssertFalse(joined.contains("read_secret_workspace_file"))
        XCTAssertFalse(joined.contains("private_connector"))
        XCTAssertFalse(joined.contains("secret_operation"))
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

        XCTAssertEqual(plan.speaker, "codex")
        XCTAssertEqual(plan.text, "計画を更新中")
        XCTAssertEqual(reasoning.text, "文脈を整理中")
    }

    func testBuildsStatusLinesFromThreadState() {
        let active = CodexConversationExtractor.statusLine(
            threadId: "thread-active",
            threadTitle: "実装",
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )
        let waiting = CodexConversationExtractor.statusLine(
            threadId: "thread-waiting",
            threadTitle: "確認",
            threadStatus: .active(activeFlags: [.waitingOnUserInput]),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )
        let review = CodexConversationExtractor.statusLine(
            threadId: "thread-review",
            threadTitle: "レビュー",
            threadStatus: .idle,
            latestTurnStatus: .completed,
            hasRecentAssistantFinal: true
        )
        let idle = CodexConversationExtractor.statusLine(
            threadId: "thread-idle",
            threadTitle: "待機",
            threadStatus: .idle,
            latestTurnStatus: nil,
            hasRecentAssistantFinal: false
        )

        XCTAssertEqual(active?.speaker, "thread")
        XCTAssertEqual(active?.text, "作業中")
        XCTAssertEqual(waiting?.text, "確認待ち")
        XCTAssertEqual(review?.text, "レビュー可能")
        XCTAssertNil(idle)
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
