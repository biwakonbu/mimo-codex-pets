import Foundation

public struct PetShowcaseScene: Equatable, Sendable {
    public let animation: PetAnimationState
    public let bubbleText: String
    public let conversationLines: [CodexConversationLine]
    public let focusedThreadId: String?
    public let primaryThreadId: String?
    public let primaryActivityKind: CodexConversationActivityKind?
    public let primaryRole: PetSpeechBubbleRole?
    public let duration: TimeInterval

    public init(
        animation: PetAnimationState,
        bubbleText: String,
        conversationLines: [CodexConversationLine] = [],
        focusedThreadId: String? = nil,
        primaryThreadId: String? = nil,
        primaryActivityKind: CodexConversationActivityKind? = nil,
        primaryRole: PetSpeechBubbleRole? = nil,
        duration: TimeInterval
    ) {
        self.animation = animation
        self.bubbleText = bubbleText
        self.conversationLines = conversationLines
        self.focusedThreadId = focusedThreadId
        self.primaryThreadId = primaryThreadId
        self.primaryActivityKind = primaryActivityKind
        self.primaryRole = primaryRole
        self.duration = duration
    }
}

public enum PetShowcaseSequence {
    public static let minimumSceneDuration = 3.0

    public static var scenes: [PetShowcaseScene] {
        [
            scene(
                animation: .idle,
                bubbleText: "今日はここで見守ってるよ",
                lines: [],
                primary: nil
            ),
            scene(
                animation: .waving,
                bubbleText: "「Mimo Desktop Pet」で吹き出しを整え始めたよ",
                lines: [mimoUI, releaseDMG]
            ),
            scene(
                animation: .running,
                bubbleText: "「Mimo Desktop Pet」で新しい吹き出し演出を動かしているよ",
                lines: [mimoUI, releaseDMG, slackNotify]
            ),
            scene(
                animation: .waiting,
                bubbleText: "「Slack 通知整備」は設定の確認待ちみたい",
                lines: [slackNotify, mimoUI, releaseDMG, notarization],
                primary: slackNotify.threadId
            ),
            scene(
                animation: .runningRight,
                bubbleText: "右の方まで様子を見に行くね",
                lines: [mimoUI, slackNotify, releaseDMG, notarization],
                primary: nil
            ),
            scene(
                animation: .runningLeft,
                bubbleText: "左側のチャットも見てくるね",
                lines: [releaseDMG, mimoUI, slackNotify, notarization],
                primary: nil
            ),
            scene(
                animation: .jumping,
                bubbleText: "「Release DMG」は確認してよさそう。ぴょん",
                lines: [releaseDMG, mimoUI, slackNotify, notarization],
                primary: releaseDMG.threadId
            ),
            scene(
                animation: .failed,
                bubbleText: "「Notarization 調査」で失敗を見つけたよ。原因を確認中",
                lines: [notarization, releaseDMG, mimoUI, slackNotify],
                primary: notarization.threadId
            ),
            scene(
                animation: .review,
                bubbleText: "「吹き出し演出」は確認してよさそう。あとで見てね",
                lines: [mimoUI, releaseDMG, slackNotify, notarization],
                primary: mimoUI.threadId
            )
        ]
    }

    public static var coveredAnimations: Set<PetAnimationState> {
        Set(scenes.map(\.animation))
    }

    private static func scene(
        animation: PetAnimationState,
        bubbleText: String,
        lines: [CodexConversationLine],
        primary: String? = "mimo-ui"
    ) -> PetShowcaseScene {
        PetShowcaseScene(
            animation: animation,
            bubbleText: bubbleText,
            conversationLines: lines,
            focusedThreadId: primary,
            primaryThreadId: primary,
            primaryActivityKind: lines.first(where: { $0.threadId == primary })?.activityKind,
            duration: minimumSceneDuration
        )
    }

    private static let mimoUI = CodexConversationLine(
        threadId: "mimo-ui",
        threadTitle: "Mimo Desktop Pet",
        speaker: "codex",
        text: "吹き出しの出現と押し出しを調整中",
        isAssistant: true,
        activityKind: .fileChange,
        workSummary: "吹き出し演出を調整中",
        sessionState: .active
    )

    private static let releaseDMG = CodexConversationLine(
        threadId: "release-dmg",
        threadTitle: "Release DMG",
        speaker: "codex",
        text: "配布用 DMG の確認がひと段落",
        isAssistant: true,
        activityKind: .review,
        workSummary: "配布物の確認がひと段落",
        sessionState: .stopped
    )

    private static let slackNotify = CodexConversationLine(
        threadId: "slack-notify",
        threadTitle: "Slack 通知整備",
        speaker: "codex",
        text: "GitHub Actions の通知設定で確認待ち",
        isAssistant: true,
        activityKind: .threadStatus,
        workSummary: "通知設定の確認待ち",
        sessionState: .waiting
    )

    private static let notarization = CodexConversationLine(
        threadId: "notarization",
        threadTitle: "Notarization 調査",
        speaker: "tool",
        text: "notarytool の検証で失敗を確認",
        isAssistant: true,
        activityKind: .test,
        workSummary: "認証まわりの失敗を確認中",
        sessionState: .failed
    )
}
