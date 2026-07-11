import AppKit
import Foundation
import MimoDesktopPetCore

@MainActor
final class PetViewModel: ObservableObject {
    @Published private(set) var presentation: PetPresentationState
    @Published private(set) var visibleBubbles: [PetSpeechBubble]
    @Published private(set) var conversationLines: [CodexConversationLine]
    @Published private(set) var kataribeStage: PetKataribeStagePresentation
    @Published private(set) var hoveredBubbleId: String?
    @Published private(set) var isPetMoving = false
    @Published private(set) var autonomousWindowMovementEnabled = true
    @Published var clickThrough: Bool
    @Published var debugOverlay: Bool
    var hasPendingConversationBubbles: Bool {
        coordinator.hasPendingConversationBubbles
    }
    var accessibilityValue: String {
        PetKataribeStageAccessibility.value(
            stage: kataribeStage,
            debugOverlay: debugOverlay
        )
    }

    private let conversationBubbleDurationOverride: TimeInterval?
    private let presentationLogURL: URL?
    private var coordinator = PetPresentationCoordinator()
    private var conversationTimeoutToken = UUID()
    private var deferredConversationTimeoutToken: UUID?
    private var temporaryMomentToken = UUID()
    private var bubbleFramesById: [String: PetDragFrame] = [:]
    private var manualMovementActive = false
    private var ambientMovementActive = false

    init(
        debugOverlay: Bool = PetDebugOverlayPolicy.isEnabled(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.debugOverlay = debugOverlay
        clickThrough = environment["MIMO_CLICK_THROUGH"] == "1"
        presentation = coordinator.presentation
        visibleBubbles = coordinator.visibleBubbles
        conversationLines = coordinator.conversationLines
        kataribeStage = PetKataribeStagePlanner.presentation(
            visibleBubbles: coordinator.visibleBubbles,
            conversationLines: coordinator.kataribeConversationLines,
            charmRevisions: coordinator.kataribeCharmRevisions
        )
        hoveredBubbleId = nil
        conversationBubbleDurationOverride = Self.conversationBubbleDurationOverride(
            environment: environment
        )
        if let path = environment["MIMO_PRESENTATION_LOG"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            presentationLogURL = url
            try? FileManager.default.removeItem(at: url)
            FileManager.default.createFile(atPath: path, contents: nil)
            appendPresentationLog(presentation)
        } else {
            presentationLogURL = nil
        }
    }

    func apply(snapshot: CodexStateSnapshot) {
        let change = coordinator.apply(
            snapshot: PetCodexSnapshot(
                threadStatus: snapshot.threadStatus,
                latestTurnStatus: snapshot.latestTurnStatus,
                hasRecentAssistantFinal: snapshot.hasRecentAssistantFinal,
                connectionAvailable: snapshot.connectionAvailable,
                offlineBubbleText: snapshot.offlineBubbleText,
                conversationLines: snapshot.conversationLines,
                focusedConversationLine: snapshot.focusedConversationLine
            )
        )
        if !coordinator.hasActiveConversationBubble {
            conversationTimeoutToken = UUID()
            deferredConversationTimeoutToken = nil
        }
        apply(change: change)
    }

    private func finishConversationBubble(token: UUID) {
        guard conversationTimeoutToken == token else { return }
        guard PetKataribeNarrationPolicy.shouldAdvanceAfterTimeout(isPetMoving: isPetMoving) else {
            deferredConversationTimeoutToken = token
            return
        }
        deferredConversationTimeoutToken = nil
        apply(change: coordinator.finishConversationBubble())
    }

    func setConnectionAvailable(_ available: Bool) {
        guard !available else { return }
        conversationTimeoutToken = UUID()
        deferredConversationTimeoutToken = nil
        apply(change: coordinator.setConnectionAvailable(available))
    }

    func apply(showcaseScene scene: PetShowcaseScene) {
        conversationTimeoutToken = UUID()
        deferredConversationTimeoutToken = nil
        temporaryMomentToken = UUID()
        apply(change: coordinator.apply(showcaseScene: scene))
    }

    func beginDrag(deltaX: CGFloat) {
        setMovementActive(manual: true, active: true)
        apply(change: coordinator.beginDrag(deltaX: Double(deltaX)))
    }

    func beginDrag(animation: PetAnimationState) {
        setMovementActive(manual: true, active: true)
        apply(change: coordinator.beginDrag(animation: animation))
    }

    func beginAmbientMovement(animation: PetAnimationState) {
        setMovementActive(manual: false, active: true)
        apply(change: coordinator.beginAmbientMovement(animation: animation))
    }

    func endDrag() {
        setMovementActive(manual: true, active: false)
        apply(change: coordinator.endDrag())
        resumeDeferredConversationIfResting()
    }

    func endAmbientMovement() {
        setMovementActive(manual: false, active: false)
        apply(change: coordinator.endAmbientMovement())
        resumeDeferredConversationIfResting()
    }

    func playMoment(animation: PetAnimationState, bubbleText: String? = nil, duration: TimeInterval = 1.8) {
        let token = UUID()
        temporaryMomentToken = token
        apply(change: coordinator.playMoment(animation: animation, bubbleText: bubbleText))

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, self.temporaryMomentToken == token else { return }
            self.apply(change: self.coordinator.finishTemporaryPresentation())
        }
    }

    func toggleClickThrough() {
        clickThrough.toggle()
    }

    func setAutonomousWindowMovementEnabled(_ enabled: Bool) {
        autonomousWindowMovementEnabled = enabled
    }

    func toggleAutonomousWindowMovement() {
        autonomousWindowMovementEnabled.toggle()
    }

    func toggleDebugOverlay() {
        debugOverlay.toggle()
    }

    func openableBubble(at point: PetWanderPoint, in bounds: PetDragFrame) -> PetSpeechBubble? {
        guard point.x >= 0, point.y >= 0, point.x <= bounds.width, point.y <= bounds.height else {
            return nil
        }
        return PetSpeechBubbleHitTesting.openableBubble(
            at: point,
            bubbles: kataribeStage.interactiveBubbles,
            framesByBubbleId: bubbleFramesById
        )
    }

    func updateBubbleFrames(_ framesById: [String: PetDragFrame]) {
        let stageIds = Set(
            [kataribeStage.report.id] + kataribeStage.charms.map(\.id)
        )
        bubbleFramesById = framesById.filter { id, _ in
            stageIds.contains(id)
        }
    }

    func setHoveredBubble(_ bubble: PetSpeechBubble?) {
        let nextId = bubble?.id
        guard hoveredBubbleId != nextId else { return }
        hoveredBubbleId = nextId
    }

    func containsInteractiveContent(at point: PetWanderPoint, in bounds: PetDragFrame) -> Bool {
        interactionTarget(at: point, in: bounds) != .none
    }

    func interactionTarget(at point: PetWanderPoint, in bounds: PetDragFrame) -> PetInteractionHitTarget {
        PetInteractionHitRegion.target(
            point: point,
            bounds: bounds,
            bubbleFrames: Array(bubbleFramesById.values),
            debugOverlay: debugOverlay
        )
    }

    @discardableResult
    func openThread(for bubble: PetSpeechBubble) -> Bool {
        guard
            let threadId = bubble.threadId,
            let url = CodexThreadDeepLink.url(for: threadId)
        else { return false }
        let opened = NSWorkspace.shared.open(url)
        if opened {
            let title = bubble.threadTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = title.flatMap { $0.isEmpty ? nil : "「\($0)」を開いたよ" } ?? "チャットを開いたよ"
            playMoment(animation: .jumping, bubbleText: message, duration: 1.4)
        } else {
            playMoment(animation: .waiting, bubbleText: "Codexを開けなかったよ", duration: 2.4)
        }
        return opened
    }

    private func apply(change: PetPresentationCoordinatorChange) {
        presentation = coordinator.presentation
        visibleBubbles = coordinator.visibleBubbles
        conversationLines = coordinator.conversationLines
        kataribeStage = PetKataribeStagePlanner.presentation(
            visibleBubbles: visibleBubbles,
            conversationLines: coordinator.kataribeConversationLines,
            charmRevisions: coordinator.kataribeCharmRevisions,
            pageNumber: coordinator.currentConversationPageNumber,
            pageCount: coordinator.currentConversationPageCount,
            maximumPageTextLength: coordinator.currentConversationMaximumPageTextLength
        )
        if change.changed {
            appendPresentationLog(presentation)
        }
        if change.shouldScheduleConversationTimeout {
            scheduleConversationBubbleTimeout()
        }
    }

    private func scheduleConversationBubbleTimeout() {
        let token = UUID()
        conversationTimeoutToken = token
        deferredConversationTimeoutToken = nil
        Task { @MainActor [weak self] in
            let duration = self?.currentConversationBubbleDuration() ?? PetSpeechBubbleDisplayTiming.minimumConversationBubbleDuration
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.finishConversationBubble(token: token)
        }
    }

    private func currentConversationBubbleDuration() -> TimeInterval {
        if let conversationBubbleDurationOverride {
            return conversationBubbleDurationOverride
        }
        let primaryRole = kataribeStage.report.role
        return PetSpeechBubbleDisplayTiming.conversationBubbleDuration(
            for: kataribeStage.report.text,
            role: primaryRole
        )
    }

    private func setMovementActive(manual: Bool, active: Bool) {
        if manual {
            manualMovementActive = active
        } else {
            ambientMovementActive = active
        }
        isPetMoving = manualMovementActive || ambientMovementActive
    }

    private func resumeDeferredConversationIfResting() {
        guard !isPetMoving, let token = deferredConversationTimeoutToken else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(PetKataribeNarrationPolicy.restSettleDelay * 1_000_000_000)
            )
            self?.finishConversationBubble(token: token)
        }
    }

    private static func conversationBubbleDurationOverride(environment: [String: String]) -> TimeInterval? {
        if let value = environment["MIMO_CONVERSATION_BUBBLE_DURATION_OVERRIDE"],
           let seconds = TimeInterval(value),
           seconds > 0 {
            return max(0.25, seconds)
        }
        if environment["MIMO_BUBBLE_TEST_MODE"] == "1" {
            return PetSpeechBubbleDisplayTiming.testConversationBubbleDuration
        }
        return nil
    }

    private func appendPresentationLog(_ state: PetPresentationState) {
        guard let presentationLogURL else { return }
        let object: [String: Any] = [
            "animation": state.animation.rawValue,
            "bubbleText": state.bubbleText,
            "bubbleTexts": visibleBubbles.map(\.text),
            "bubbleRoles": visibleBubbles.map { $0.role.rawValue },
            "bubbleTones": visibleBubbles.map { $0.tone.rawValue },
            "bubbleActivityKinds": visibleBubbles.map { $0.activityKind?.rawValue ?? "none" },
            "bubbleThreadIds": visibleBubbles.map { $0.threadId ?? "none" },
            "bubbleThreadTitles": visibleBubbles.map { $0.threadTitle ?? "none" },
            "kataribeReportText": kataribeStage.report.text,
            "kataribeReportThreadId": kataribeStage.report.threadId ?? "none",
            "kataribeCharmTitles": kataribeStage.charms.map(\.title),
            "kataribeCharmThreadIds": kataribeStage.charms.map(\.threadId),
            "kataribePageNumber": kataribeStage.pageNumber,
            "kataribePageCount": kataribeStage.pageCount,
            "isPetMoving": isPetMoving,
            "clickThrough": clickThrough,
            "accessibilityValue": accessibilityValue,
            "debugOverlay": debugOverlay,
            "isOffline": state.isOffline
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: object),
            let newline = "\n".data(using: .utf8)
        else { return }

        if let handle = try? FileHandle(forWritingTo: presentationLogURL) {
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
            _ = try? handle.write(contentsOf: newline)
            _ = try? handle.close()
        } else {
            var line = data
            line.append(newline)
            try? line.write(to: presentationLogURL)
        }
    }
}
