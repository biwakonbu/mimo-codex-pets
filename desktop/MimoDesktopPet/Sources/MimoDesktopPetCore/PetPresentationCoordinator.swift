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
    public private(set) var presentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    public private(set) var visibleBubbles: [PetSpeechBubble] = [
        PetSpeechBubble(id: "0-待機中", text: "待機中", role: .status)
    ]
    public private(set) var conversationLines: [CodexConversationLine] = []

    public var hasPendingConversationBubbles: Bool {
        conversationBubbleActive || !pendingConversationLines.isEmpty
    }

    public var hasActiveConversationBubble: Bool {
        conversationBubbleActive
    }

    private var lastCodexPresentation = PetPresentationState(animation: .idle, bubbleText: "待機中")
    private var shownConversationDisplaySignatures: Set<String> = []
    private var pendingConversationLines: [CodexConversationLine] = []
    private var conversationBubbleActive = false
    private var currentConversationThreadId: String?
    private var currentConversationActivityKind: CodexConversationActivityKind?
    private var focusedThreadId: String?

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
        conversationLines = Array(snapshot.conversationLines.suffix(12))
        focusedThreadId = snapshot.focusedConversationLine?.threadId
        pruneConversationQueue(keeping: Set(conversationLines.map(\.threadId)))

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
            refreshVisibleBubbles()
        }

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

        if pendingConversationLines.isEmpty {
            conversationBubbleActive = false
            currentConversationThreadId = nil
            currentConversationActivityKind = nil
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
        conversationLines.removeAll()
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
    public mutating func beginDrag(deltaX: Double) -> PetPresentationCoordinatorChange {
        beginDrag(animation: CodexPetStateMapper.dragPresentation(deltaX: deltaX).animation)
    }

    @discardableResult
    public mutating func beginDrag(animation: PetAnimationState) -> PetPresentationCoordinatorChange {
        let previousPresentation = presentation
        let previousVisibleBubbles = visibleBubbles
        clearConversationQueue()
        setPresentation(PetPresentationState(animation: animation, bubbleText: "移動中"))
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
        clearConversationQueue()
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
        clearConversationQueue()
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
        setPresentation(PetPresentationState(
            animation: lastCodexPresentation.animation,
            bubbleText: lastCodexPresentation.bubbleText,
            isOffline: lastCodexPresentation.isOffline
        ))
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
            setPresentation(lastCodexPresentation)
            return false
        }

        let line = pendingConversationLines.removeFirst()
        conversationBubbleActive = true
        currentConversationThreadId = line.threadId
        currentConversationActivityKind = line.activityKind
        setPresentation(PetPresentationState(
            animation: CodexConversationBubblePlanner.animation(
                for: line,
                fallback: lastCodexPresentation.animation
            ),
            bubbleText: CodexBubbleFormatter.bubbleText(for: line),
            isOffline: lastCodexPresentation.isOffline
        ))
        return true
    }

    private mutating func clearConversationQueue() {
        pendingConversationLines.removeAll()
        conversationBubbleActive = false
        currentConversationThreadId = nil
        currentConversationActivityKind = nil
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
        }
    }

    private mutating func setPresentation(_ state: PetPresentationState) {
        presentation = state
        refreshVisibleBubbles()
    }

    private mutating func refreshVisibleBubbles() {
        let primaryBubble = CodexConversationBubblePlanner.primaryBubble(
            statusText: presentation.bubbleText,
            conversationLines: conversationLines,
            preferredThreadId: focusedThreadId,
            activeConversationThreadId: conversationBubbleActive ? currentConversationThreadId : nil,
            activeConversationActivityKind: conversationBubbleActive ? currentConversationActivityKind : nil,
            isOffline: presentation.isOffline
        )
        visibleBubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: primaryBubble.text,
            conversationLines: conversationLines,
            preferredThreadId: focusedThreadId,
            primaryThreadId: primaryBubble.threadId,
            primaryActivityKind: primaryBubble.activityKind
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
