import Foundation

public struct PetCodexSnapshot: Equatable, Sendable {
    public var threadStatus: CodexThreadStatus?
    public var latestTurnStatus: CodexTurnStatus?
    public var hasRecentAssistantFinal: Bool
    public var connectionAvailable: Bool
    public var offlineBubbleText: String?
    public var conversationLines: [CodexConversationLine]
    public var focusedConversationLine: CodexConversationLine?

    public init(
        threadStatus: CodexThreadStatus?,
        latestTurnStatus: CodexTurnStatus?,
        hasRecentAssistantFinal: Bool,
        connectionAvailable: Bool,
        offlineBubbleText: String? = nil,
        conversationLines: [CodexConversationLine] = [],
        focusedConversationLine: CodexConversationLine? = nil
    ) {
        self.threadStatus = threadStatus
        self.latestTurnStatus = latestTurnStatus
        self.hasRecentAssistantFinal = hasRecentAssistantFinal
        self.connectionAvailable = connectionAvailable
        self.offlineBubbleText = offlineBubbleText
        self.conversationLines = conversationLines
        self.focusedConversationLine = focusedConversationLine
    }
}

public struct PetPresentationCoordinatorChange: Equatable, Sendable {
    public let presentationChanged: Bool
    public let visibleBubblesChanged: Bool
    public let shouldScheduleConversationTimeout: Bool

    public var changed: Bool {
        presentationChanged || visibleBubblesChanged
    }

    public init(
        presentationChanged: Bool,
        visibleBubblesChanged: Bool,
        shouldScheduleConversationTimeout: Bool = false
    ) {
        self.presentationChanged = presentationChanged
        self.visibleBubblesChanged = visibleBubblesChanged
        self.shouldScheduleConversationTimeout = shouldScheduleConversationTimeout
    }
}

public struct PetPresentationCoordinator: Equatable, Sendable {
    public private(set) var presentation = PetPresentationState(animation: .idle, bubbleText: CodexMimoStatusSpeech.idle)
    public private(set) var visibleBubbles: [PetSpeechBubble] = [
        PetSpeechBubble(id: "0-\(CodexMimoStatusSpeech.idle)", text: CodexMimoStatusSpeech.idle, role: .status)
    ]
    public private(set) var conversationLines: [CodexConversationLine] = []
    public private(set) var kataribeConversationLines: [CodexConversationLine] = []
    public private(set) var kataribeCharmRevisions: [String: Int] = [:]

    public var hasPendingConversationBubbles: Bool {
        conversationBubbleActive || !pendingConversationLines.isEmpty
    }

    public var hasActiveConversationBubble: Bool {
        conversationBubbleActive
    }

    public var currentConversationPageNumber: Int {
        conversationBubbleActive ? currentConversationPageIndex + 1 : 1
    }

    public var currentConversationPageCount: Int {
        conversationBubbleActive ? max(1, currentConversationPages.count) : 1
    }

    public var currentConversationMaximumPageTextLength: Int {
        guard conversationBubbleActive else { return 0 }
        return currentConversationPages
            .map { PetSpeechBubbleTextParts.parse($0).summary.count }
            .max() ?? 0
    }

    private var lastCodexPresentation = PetPresentationState(animation: .idle, bubbleText: CodexMimoStatusSpeech.idle)
    private var shownConversationDisplaySignatures: Set<String> = []
    private var pendingConversationLines: [CodexConversationLine] = []
    private var conversationBubbleActive = false
    private var currentConversationThreadId: String?
    private var currentConversationActivityKind: CodexConversationActivityKind?
    private var currentConversationAnimation: PetAnimationState?
    private var currentConversationPages: [String] = []
    private var currentConversationPageIndex = 0
    private var focusedThreadId: String?
    private var temporaryReturnPresentation: PetPresentationState?
    private var temporaryMomentActive = false
    private var kataribeThreadOrder: [String] = []
    private var latestKataribeLineByThread: [String: CodexConversationLine] = [:]

    public init() {}

    @discardableResult
    public mutating func apply(snapshot: PetCodexSnapshot) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        let next = CodexPetStateMapper.presentation(
            threadStatus: snapshot.threadStatus,
            latestTurnStatus: snapshot.latestTurnStatus,
            hasRecentAssistantFinal: snapshot.hasRecentAssistantFinal,
            connectionAvailable: snapshot.connectionAvailable
        )
        let presentationState: PetPresentationState
        if !snapshot.connectionAvailable, let offlineBubbleText = snapshot.offlineBubbleText {
            presentationState = PetPresentationState(
                animation: next.animation,
                bubbleText: offlineBubbleText,
                isOffline: next.isOffline
            )
        } else {
            presentationState = next
        }

        lastCodexPresentation = presentationState
        updateKataribeConversationLines(snapshot.conversationLines)
        conversationLines = Array(snapshot.conversationLines.suffix(12))
        focusedThreadId = snapshot.focusedConversationLine?.threadId
        pruneConversationQueue(keeping: Set(kataribeConversationLines.map(\.threadId)))

        if snapshot.connectionAvailable {
            enqueueConversationLines(
                snapshot.conversationLines,
                preferredThreadId: focusedThreadId
            )
        } else {
            clearConversationQueue()
        }

        let shouldScheduleConversationTimeout: Bool
        if !conversationBubbleActive {
            if !pendingConversationLines.isEmpty {
                shouldScheduleConversationTimeout = showNextConversationBubble()
            } else {
                shouldScheduleConversationTimeout = false
                setPresentation(presentationState)
            }
        } else {
            shouldScheduleConversationTimeout = false
            enrichVisibleBubblesIfNeeded()
        }
        alignKataribeFeedWithVisibleReport()

        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles,
            shouldScheduleConversationTimeout: shouldScheduleConversationTimeout
        )
    }

    @discardableResult
    public mutating func finishConversationBubble() -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        let shouldScheduleConversationTimeout: Bool

        if advanceConversationPage() {
            shouldScheduleConversationTimeout = true
        } else if pendingConversationLines.isEmpty {
            conversationBubbleActive = false
            currentConversationThreadId = nil
            currentConversationActivityKind = nil
            currentConversationAnimation = nil
            currentConversationPages.removeAll()
            currentConversationPageIndex = 0
            shouldScheduleConversationTimeout = false
            setPresentation(lastCodexPresentation)
        } else {
            shouldScheduleConversationTimeout = showNextConversationBubble()
        }

        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles,
            shouldScheduleConversationTimeout: shouldScheduleConversationTimeout
        )
    }

    @discardableResult
    public mutating func setConnectionAvailable(_ available: Bool) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        guard !available else {
            return change(
                previousPresentation: previousPresentation,
                previousVisibleBubbles: previousVisibleBubbles
            )
        }

        clearConversationQueue()
        temporaryMomentActive = false
        temporaryReturnPresentation = nil
        conversationLines.removeAll()
        clearKataribeConversationLines()
        focusedThreadId = nil
        let offline = CodexPetStateMapper.presentation(
            threadStatus: nil,
            latestTurnStatus: nil,
            hasRecentAssistantFinal: false,
            connectionAvailable: false
        )
        lastCodexPresentation = offline
        setPresentation(offline)
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func apply(showcaseScene scene: PetShowcaseScene) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles

        clearConversationQueue()
        temporaryMomentActive = false
        temporaryReturnPresentation = nil
        conversationLines = Array(scene.conversationLines.suffix(12))
        updateKataribeConversationLines(scene.conversationLines)
        if let primaryThreadId = scene.primaryThreadId {
            promoteKataribeThreadToBottom(primaryThreadId)
        }
        focusedThreadId = scene.focusedThreadId
        let showcasePresentation = PetPresentationState(
            animation: scene.animation,
            bubbleText: scene.bubbleText
        )
        lastCodexPresentation = showcasePresentation
        presentation = showcasePresentation
        visibleBubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: scene.bubbleText,
            conversationLines: conversationLines,
            preferredThreadId: scene.focusedThreadId,
            primaryThreadId: scene.primaryThreadId,
            primaryActivityKind: scene.primaryActivityKind,
            primaryRole: scene.primaryRole
        )

        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func beginDrag(deltaX: Double) -> PetPresentationCoordinatorChange {
        beginDrag(animation: CodexPetStateMapper.dragPresentation(deltaX: deltaX).animation)
    }

    @discardableResult
    public mutating func beginDrag(animation: PetAnimationState) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        setPresentation(PetPresentationState(
            animation: animation,
            bubbleText: presentation.bubbleText,
            isOffline: presentation.isOffline
        ))
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func beginAmbientMovement(animation: PetAnimationState) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        setPresentation(PetPresentationState(
            animation: animation,
            bubbleText: presentation.bubbleText,
            isOffline: presentation.isOffline
        ))
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func endDrag() -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        if conversationBubbleActive {
            setPresentation(PetPresentationState(
                animation: currentConversationAnimation ?? lastCodexPresentation.animation,
                bubbleText: presentation.bubbleText,
                isOffline: presentation.isOffline
            ))
            return change(
                previousPresentation: previousPresentation,
                previousVisibleBubbles: previousVisibleBubbles
            )
        }

        setPresentation(lastCodexPresentation)
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func endAmbientMovement() -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        guard !conversationBubbleActive else {
            setPresentation(PetPresentationState(
                animation: currentConversationAnimation ?? lastCodexPresentation.animation,
                bubbleText: presentation.bubbleText,
                isOffline: presentation.isOffline
            ))
            return change(
                previousPresentation: previousPresentation,
                previousVisibleBubbles: previousVisibleBubbles
            )
        }

        setPresentation(lastCodexPresentation)
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func playMoment(
        animation: PetAnimationState,
        bubbleText: String? = nil
    ) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        if !temporaryMomentActive {
            temporaryReturnPresentation = presentation
        }
        temporaryMomentActive = true
        setPresentation(PetPresentationState(
            animation: animation,
            bubbleText: bubbleText ?? lastCodexPresentation.bubbleText,
            isOffline: lastCodexPresentation.isOffline
        ))
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    @discardableResult
    public mutating func finishTemporaryPresentation() -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        let returnPresentation = temporaryReturnPresentation ?? lastCodexPresentation
        temporaryMomentActive = false
        temporaryReturnPresentation = nil
        setPresentation(returnPresentation)
        return change(
            previousPresentation: previousPresentation,
            previousVisibleBubbles: previousVisibleBubbles
        )
    }

    private mutating func enqueueConversationLines(_ lines: [CodexConversationLine], preferredThreadId: String?) {
        let candidates = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: preferredThreadId
        )
        let pendingSignatures = Set(pendingConversationLines.map(CodexConversationBubblePlanner.displaySignature(for:)))

        for line in candidates {
            let signature = CodexConversationBubblePlanner.displaySignature(for: line)
            guard !shownConversationDisplaySignatures.contains(signature), !pendingSignatures.contains(signature) else {
                continue
            }
            shownConversationDisplaySignatures.insert(signature)
            pendingConversationLines.insert(
                line,
                at: CodexConversationBubblePlanner.insertionIndex(
                    for: line,
                    preferredThreadId: preferredThreadId,
                    pendingLines: pendingConversationLines
                )
            )
        }
    }

    private mutating func showNextConversationBubble() -> Bool {
        guard !pendingConversationLines.isEmpty else {
            conversationBubbleActive = false
            currentConversationThreadId = nil
            currentConversationActivityKind = nil
            currentConversationAnimation = nil
            setPresentation(lastCodexPresentation)
            return false
        }

        let line = pendingConversationLines.removeFirst()
        let pages = PetSpeechBubblePaginator.pages(
            for: CodexBubbleFormatter.bubbleText(for: line),
            role: .focus,
            limit: PetKataribeStageLayout.reportTextLimit
        )
        conversationBubbleActive = true
        currentConversationThreadId = line.threadId
        currentConversationActivityKind = line.activityKind
        currentConversationAnimation = CodexConversationBubblePlanner.animation(
            for: line,
            fallback: lastCodexPresentation.animation
        )
        currentConversationPages = pages.isEmpty ? [CodexBubbleFormatter.bubbleText(for: line)] : pages
        currentConversationPageIndex = 0
        setPresentation(PetPresentationState(
            animation: currentConversationAnimation ?? lastCodexPresentation.animation,
            bubbleText: currentConversationPages[0],
            isOffline: lastCodexPresentation.isOffline
        ))
        return true
    }

    private mutating func advanceConversationPage() -> Bool {
        guard conversationBubbleActive,
              currentConversationPageIndex + 1 < currentConversationPages.count
        else { return false }

        currentConversationPageIndex += 1
        setPresentation(PetPresentationState(
            animation: presentation.animation,
            bubbleText: currentConversationPages[currentConversationPageIndex],
            isOffline: presentation.isOffline
        ))
        return true
    }

    private mutating func clearConversationQueue() {
        pendingConversationLines.removeAll()
        conversationBubbleActive = false
        currentConversationThreadId = nil
        currentConversationActivityKind = nil
        currentConversationAnimation = nil
        currentConversationPages.removeAll()
        currentConversationPageIndex = 0
    }

    private mutating func updateKataribeConversationLines(_ lines: [CodexConversationLine]) {
        var encounteredThreadIds: [String] = []
        var latestInSnapshot: [String: CodexConversationLine] = [:]

        for line in lines {
            if latestInSnapshot[line.threadId] == nil {
                encounteredThreadIds.append(line.threadId)
            }
            latestInSnapshot[line.threadId] = line
        }

        let activeThreadIds = Set(encounteredThreadIds)
        kataribeThreadOrder.removeAll { !activeThreadIds.contains($0) }
        latestKataribeLineByThread = latestKataribeLineByThread.filter { activeThreadIds.contains($0.key) }
        kataribeCharmRevisions = kataribeCharmRevisions.filter { activeThreadIds.contains($0.key) }

        for threadId in encounteredThreadIds where !kataribeThreadOrder.contains(threadId) {
            kataribeThreadOrder.append(threadId)
            kataribeCharmRevisions[threadId] = 0
        }
        for (threadId, line) in latestInSnapshot {
            latestKataribeLineByThread[threadId] = line
        }

        refreshKataribeConversationLines()
    }

    private mutating func promoteKataribeThreadToBottom(_ threadId: String) {
        guard latestKataribeLineByThread[threadId] != nil else { return }
        kataribeThreadOrder.removeAll { $0 == threadId }
        kataribeThreadOrder.append(threadId)
        kataribeCharmRevisions[threadId, default: 0] += 1
        refreshKataribeConversationLines()
    }

    private mutating func refreshKataribeConversationLines() {
        kataribeConversationLines = kataribeThreadOrder.compactMap { latestKataribeLineByThread[$0] }
    }

    private mutating func clearKataribeConversationLines() {
        kataribeConversationLines.removeAll()
        kataribeCharmRevisions.removeAll()
        kataribeThreadOrder.removeAll()
        latestKataribeLineByThread.removeAll()
    }

    private mutating func pruneConversationQueue(keeping activeThreadIds: Set<String>) {
        guard !activeThreadIds.isEmpty else {
            clearConversationQueue()
            shownConversationDisplaySignatures.removeAll()
            return
        }

        pendingConversationLines.removeAll { !activeThreadIds.contains($0.threadId) }
        shownConversationDisplaySignatures = Set(shownConversationDisplaySignatures.filter { signature in
            guard let threadId = signature.split(separator: "|", maxSplits: 1).first else { return false }
            return activeThreadIds.contains(String(threadId))
        })
        if let currentConversationThreadId, !activeThreadIds.contains(currentConversationThreadId) {
            conversationBubbleActive = false
            self.currentConversationThreadId = nil
            currentConversationActivityKind = nil
            currentConversationAnimation = nil
            currentConversationPages.removeAll()
            currentConversationPageIndex = 0
        }
    }

    private mutating func setPresentation(_ state: PetPresentationState) {
        presentation = state
        refreshVisibleBubbles()
        alignKataribeFeedWithVisibleReport()
    }

    private mutating func refreshVisibleBubbles() {
        visibleBubbles = plannedVisibleBubbles()
    }

    private mutating func enrichVisibleBubblesIfNeeded() {
        let planned = plannedVisibleBubbles()
        let shouldAdoptUrgent = shouldAdoptUrgentState(from: planned)
        guard planned.count > visibleBubbles.count ||
            shouldAdoptOverflowSummary(from: planned) ||
            shouldAdoptUrgent
        else { return }
        visibleBubbles = planned
        alignKataribeFeedWithVisibleReport()
    }

    private mutating func alignKataribeFeedWithVisibleReport() {
        let visibleReport = visibleBubbles.first(where: {
            $0.threadId != nil && ($0.tone == .failed || $0.tone == .waiting)
        }) ?? visibleBubbles.first
        guard let threadId = visibleReport?.threadId,
              kataribeThreadOrder.last != threadId
        else { return }
        promoteKataribeThreadToBottom(threadId)
    }

    private func shouldAdoptUrgentState(from planned: [PetSpeechBubble]) -> Bool {
        planned.contains { next in
            guard next.tone == .failed || next.tone == .waiting else { return false }
            guard let current = visibleBubbles.first(where: { $0.id == next.id }) else { return true }
            return current.tone != next.tone || current.text != next.text
        }
    }

    private func shouldAdoptOverflowSummary(from planned: [PetSpeechBubble]) -> Bool {
        guard let plannedOverflowCount = overflowHiddenCount(in: planned) else { return false }
        guard let visibleOverflowCount = overflowHiddenCount(in: visibleBubbles) else { return true }
        return plannedOverflowCount > visibleOverflowCount
    }

    private func overflowHiddenCount(in bubbles: [PetSpeechBubble]) -> Int? {
        guard let text = bubbles.first(where: { $0.role == .overflow })?.text else { return nil }
        let digits = text.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private func plannedVisibleBubbles() -> [PetSpeechBubble] {
        if temporaryMomentActive {
            return CodexConversationBubblePlanner.productionBubbles(
                primaryText: presentation.bubbleText,
                conversationLines: conversationLines,
                preferredThreadId: focusedThreadId,
                primaryRole: .status
            )
        }
        let primaryBubble = CodexConversationBubblePlanner.primaryBubble(
            statusText: presentation.bubbleText,
            conversationLines: conversationLines,
            preferredThreadId: focusedThreadId,
            activeConversationThreadId: conversationBubbleActive ? currentConversationThreadId : nil,
            activeConversationActivityKind: conversationBubbleActive ? currentConversationActivityKind : nil,
            isOffline: presentation.isOffline
        )
        return CodexConversationBubblePlanner.productionBubbles(
            primaryText: primaryBubble.text,
            conversationLines: conversationLines,
            preferredThreadId: focusedThreadId,
            primaryThreadId: primaryBubble.threadId,
            primaryActivityKind: primaryBubble.activityKind,
            primaryThreadTitle: primaryBubble.threadTitle
        )
    }

    private func change(
        previousPresentation: PetPresentationState,
        previousVisibleBubbles: [PetSpeechBubble],
        shouldScheduleConversationTimeout: Bool = false
    ) -> PetPresentationCoordinatorChange {
        PetPresentationCoordinatorChange(
            presentationChanged: previousPresentation != presentation,
            visibleBubblesChanged: previousVisibleBubbles != visibleBubbles,
            shouldScheduleConversationTimeout: shouldScheduleConversationTimeout
        )
    }
}
