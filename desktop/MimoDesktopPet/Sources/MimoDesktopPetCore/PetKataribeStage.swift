import Foundation

public struct PetKataribeChatCharm: Equatable, Identifiable, Sendable {
    public let id: String
    public let threadId: String
    public let title: String
    public let tone: PetSpeechBubbleTone
    public let activityKind: CodexConversationActivityKind?
    public let isSelected: Bool
    public let updateSignature: String

    public init(
        threadId: String,
        title: String,
        tone: PetSpeechBubbleTone,
        activityKind: CodexConversationActivityKind?,
        isSelected: Bool,
        appearanceRevision: Int = 0,
        updateSignature: String? = nil
    ) {
        self.id = "chat-charm:\(threadId):\(max(0, appearanceRevision))"
        self.threadId = threadId
        self.title = title
        self.tone = tone
        self.activityKind = activityKind
        self.isSelected = isSelected
        self.updateSignature = updateSignature ?? "\(tone.rawValue)|\(activityKind?.rawValue ?? "none")"
    }

    public var interactionBubble: PetSpeechBubble {
        PetSpeechBubble(
            id: id,
            text: title,
            role: .conversation,
            tone: tone,
            activityKind: activityKind,
            threadId: threadId,
            threadTitle: title
        )
    }
}

public struct PetKataribeStagePresentation: Equatable, Sendable {
    public let report: PetSpeechBubble
    public let charms: [PetKataribeChatCharm]
    public let pageNumber: Int
    public let pageCount: Int
    public let reportLayoutTextLength: Int

    public init(
        report: PetSpeechBubble,
        charms: [PetKataribeChatCharm],
        pageNumber: Int = 1,
        pageCount: Int = 1,
        reportLayoutTextLength: Int? = nil
    ) {
        self.report = report
        self.charms = charms
        self.pageCount = max(1, pageCount)
        self.pageNumber = min(max(1, pageNumber), self.pageCount)
        self.reportLayoutTextLength = max(
            0,
            reportLayoutTextLength ?? PetSpeechBubbleTextParts.parse(report.text).summary.count
        )
    }

    public var interactiveBubbles: [PetSpeechBubble] {
        let reportBubble = report.threadId == nil ? [] : [report]
        return reportBubble + charms.map(\.interactionBubble)
    }
}

public enum PetKataribeStagePlanner {
    public static let maximumCharmCount = 6

    public static func presentation(
        visibleBubbles: [PetSpeechBubble],
        conversationLines: [CodexConversationLine],
        charmRevisions: [String: Int] = [:],
        pageNumber: Int = 1,
        pageCount: Int = 1,
        maximumPageTextLength: Int = 0
    ) -> PetKataribeStagePresentation {
        let primary = visibleBubbles.first ?? fallbackReport
        let report = normalizedReport(urgentReport(in: visibleBubbles) ?? primary)
        let reportUsesCurrentPage = report.id == primary.id
        let representatives = latestLineByStableThreadOrder(from: conversationLines)

        var charms = representatives.prefix(maximumCharmCount).map { line in
            PetKataribeChatCharm(
                threadId: line.threadId,
                title: displayTitle(line.threadTitle),
                tone: CodexConversationBubblePlanner.tone(for: line),
                activityKind: line.activityKind,
                isSelected: line.threadId == report.threadId,
                appearanceRevision: charmRevisions[line.threadId, default: 0],
                updateSignature: CodexConversationBubblePlanner.displaySignature(for: line)
            )
        }

        if let reportThreadId = report.threadId,
           !charms.contains(where: { $0.threadId == reportThreadId }) {
            let title = displayTitle(report.threadTitle)
            charms.append(PetKataribeChatCharm(
                threadId: reportThreadId,
                title: title,
                tone: report.tone,
                activityKind: report.activityKind,
                isSelected: true,
                appearanceRevision: charmRevisions[reportThreadId, default: 0],
                updateSignature: "\(report.id)|\(report.text)|\(report.tone.rawValue)"
            ))
            if charms.count > maximumCharmCount {
                charms.removeFirst(charms.count - maximumCharmCount)
            }
        }

        let reportTextLength = PetSpeechBubbleTextParts.parse(report.text).summary.count
        return PetKataribeStagePresentation(
            report: report,
            charms: charms,
            pageNumber: reportUsesCurrentPage ? pageNumber : 1,
            pageCount: reportUsesCurrentPage ? pageCount : 1,
            reportLayoutTextLength: reportUsesCurrentPage
                ? max(reportTextLength, maximumPageTextLength)
                : reportTextLength
        )
    }

    private static var fallbackReport: PetSpeechBubble {
        PetSpeechBubble(
            id: "status:kataribe-idle",
            text: CodexMimoStatusSpeech.idle,
            role: .status,
            tone: .neutral
        )
    }

    private static func urgentReport(in bubbles: [PetSpeechBubble]) -> PetSpeechBubble? {
        bubbles.first { bubble in
            bubble.threadId != nil && (bubble.tone == .failed || bubble.tone == .waiting)
        }
    }

    private static func normalizedReport(_ report: PetSpeechBubble) -> PetSpeechBubble {
        guard report.threadId != nil else { return report }
        let parsedTitle = PetSpeechBubbleTextParts.parse(report.text).threadTitle
        return PetSpeechBubble(
            id: report.id,
            text: report.text,
            role: report.role,
            tone: report.tone,
            activityKind: report.activityKind,
            threadId: report.threadId,
            threadTitle: displayTitle(report.threadTitle ?? parsedTitle)
        )
    }

    private static func latestLineByStableThreadOrder(
        from lines: [CodexConversationLine]
    ) -> [CodexConversationLine] {
        var threadOrder: [String] = []
        var latestByThread: [String: CodexConversationLine] = [:]

        for line in lines {
            if latestByThread[line.threadId] == nil {
                threadOrder.append(line.threadId)
            }
            latestByThread[line.threadId] = line
        }

        return threadOrder.compactMap { latestByThread[$0] }
    }

    private static func displayTitle(_ rawTitle: String?) -> String {
        let title = CodexThreadTitleFormatter.title(
            from: [rawTitle],
            fallback: "名前のないチャット",
            limit: PetSpeechBubbleLayout.chatTitleTextLimit
        )
        if ["Codex Thread", "Codex Session", "unknown-thread", "Codex"].contains(title) {
            return "名前のないチャット"
        }
        return title
    }
}
