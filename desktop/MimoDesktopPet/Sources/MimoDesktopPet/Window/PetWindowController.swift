import AppKit
import Combine
import SwiftUI
import MimoDesktopPetCore

@MainActor
final class PetWindowController: NSObject {
    private static let productionSize = NSSize(
        width: CGFloat(PetSpeechBubbleLayout.productionWindowWidth),
        height: CGFloat(PetSpeechBubbleLayout.productionWindowHeight)
    )
    private static let debugSize = NSSize(width: 320, height: 430)

    private let panel: NSPanel
    private let viewModel: PetViewModel
    private let zOrderPolicy = PetWindowZOrderPolicy.alwaysOnTopCompanion
    private let showcaseMode = ProcessInfo.processInfo.environment["MIMO_SHOWCASE_MODE"] == "1"
    private let autonomousTestMode = ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_TEST_MODE"] == "1"
    private let autonomousEnergyTestMode = ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_ENERGY_TEST_MODE"] == "1"
    private let autonomousForceBegin = ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_FORCE_BEGIN"] == "1"
    private let initialAutonomousWindowMovementEnabled = PetAutonomousMotionPolicy.shouldAllowWindowMovement(
        explicitWindowMovementEnabled: PetWindowController.environmentOptionalBool("MIMO_AUTONOMOUS_WINDOW_MOVEMENT"),
        autonomousTestMode: ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_TEST_MODE"] == "1",
        autonomousEnergyTestMode: ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_ENERGY_TEST_MODE"] == "1",
        autonomousForceBegin: ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_FORCE_BEGIN"] == "1"
    )
    private let autonomousDisabled = ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_DISABLED"] == "1" ||
        ProcessInfo.processInfo.environment["MIMO_SHOWCASE_MODE"] == "1"
    private var movementHandler = PetMovementEventHandler()
    private var movementTimer: Timer?
    private var movementTimerIsActiveCadence = false
    private var pointerPassThroughTimer: Timer?
    private var movementAnimationActive = false
    private var movementAnimationWasManual = false
    private var manualDragActive = false
    private var manualMovementTrackingStarted = false
    private var autonomousEnergy = PetWindowController.makeAutonomousEnergyController()
    private var autonomousMotion: PetAutonomousMotionTween?
    private var lastAutonomousFrameAt: TimeInterval?
    private var lastAutonomousOrigin: PetWanderPoint?
    private var autonomousHomeOrigin = PetWanderPoint(x: 0, y: 0)
    private var autonomousRestUntil = Date.timeIntervalSinceReferenceDate + PetWindowController.environmentDouble(
        "MIMO_AUTONOMOUS_INITIAL_REST_SECONDS",
        default: PetAutonomousMotionTuning.productionInitialRestSeconds
    )
    private var nextAutonomousRetargetAt = Date.timeIntervalSinceReferenceDate +
        PetAutonomousMotionTuning.productionRetargetDelayRange.lowerBound
    private var nextIdleMomentAt = Date.timeIntervalSinceReferenceDate +
        PetAutonomousMotionTuning.productionInitialRestSeconds
    private var cancellables: Set<AnyCancellable> = []
    private var autonomousWindowMovementEnabled: Bool {
        viewModel.autonomousWindowMovementEnabled
    }

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel

        let size = viewModel.debugOverlay ? Self.debugSize : Self.productionSize
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_280, height: 800)
        let origin = PetWindowPlacement.origin(
            visibleFrame: PetDragFrame(visibleFrame),
            petWidth: size.width,
            petHeight: size.height,
            override: ProcessInfo.processInfo.environment["MIMO_WINDOW_ORIGIN"]
        )

        panel = NSPanel(
            contentRect: NSRect(origin: NSPoint(x: CGFloat(origin.x), y: CGFloat(origin.y)), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        viewModel.setAutonomousWindowMovementEnabled(initialAutonomousWindowMovementEnabled)
        autonomousHomeOrigin = PetWanderPoint(x: origin.x, y: origin.y)
        if !autonomousWindowMovementEnabled {
            nextIdleMomentAt = Date.timeIntervalSinceReferenceDate + PetWindowController.environmentDouble(
                "MIMO_AUTONOMOUS_INITIAL_REST_SECONDS",
                default: PetAutonomousMotionPolicy.initialIdleMomentDelay(windowMovementEnabled: false)
            )
        }

        if autonomousTestMode || autonomousEnergyTestMode {
            let now = Date.timeIntervalSinceReferenceDate
            autonomousRestUntil = now
            nextAutonomousRetargetAt = now + (autonomousEnergyTestMode ? 1.6 : 60)
            nextIdleMomentAt = .greatestFiniteMagnitude
        }

        panel.title = "Mimo Desktop Pet"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = viewModel.debugOverlay
        applyWindowZOrderPolicy()
        panel.isMovableByWindowBackground = false

        let frameProvider: AtlasFrameImageProvider?
        do {
            let package = try PetAssetLocator.findMimoPackage()
            frameProvider = try AtlasFrameImageProvider(spritesheetURL: package.spritesheetURL)
        } catch {
            frameProvider = nil
            viewModel.apply(snapshot: .offline)
        }
        if let frameProvider {
            viewModel.configureSpriteHitMaskProvider { state, frame in
                frameProvider.hitMask(for: state, frame: frame)
            }
        }

        let rootView = PetView(
            viewModel: viewModel,
            frameProvider: frameProvider
        )
        let hostingView = ClearHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false

        let interactionView = PetInteractionView(
            hostedView: hostingView,
            isDebugOverlay: { [weak viewModel] in
                viewModel?.debugOverlay ?? false
            },
            accessibilityValue: { [weak viewModel] in
                viewModel?.accessibilityValue ?? PetSpeechBubbleAccessibility.label
            },
            onPointerDown: { [weak self] in
                self?.beginManualMovementTracking()
            },
            onDragStarted: { [weak self] in
                self?.beginManualMovementTrackingIfNeeded()
            },
            onDragAnimationChanged: { [weak self] animation in
                self?.beginMovementAnimation(animation, manual: true)
            },
            onDragEnded: { [weak self, weak viewModel] in
                if let self {
                    self.endManualMovementTracking()
                    self.rememberAutonomousHomeOrigin()
                    self.scheduleAutonomousRest(
                        now: Date.timeIntervalSinceReferenceDate,
                        includeMoment: false
                    )
                }
                viewModel?.endDrag()
            },
            openableBubbleAt: { [weak viewModel] point, bounds in
                viewModel?.openableBubble(
                    at: PetWanderPoint(x: Double(point.x), y: Double(point.y)),
                    in: PetDragFrame(bounds)
                )
            },
            interactionTargetAt: { [weak viewModel] point, bounds in
                viewModel?.interactionTarget(
                    at: PetWanderPoint(x: Double(point.x), y: Double(point.y)),
                    in: PetDragFrame(bounds)
                ) ?? .none
            },
            onPointerLocationChanged: { [weak self] in
                self?.updatePointerPassThrough()
            },
            onHoveredBubbleChanged: { [weak viewModel] bubble in
                viewModel?.setHoveredBubble(bubble)
            },
            onBubbleClicked: { [weak viewModel] bubble in
                guard bubble.threadId != nil else { return false }
                _ = viewModel?.openThread(for: bubble)
                return true
            },
            onClicked: { [weak self, weak viewModel] in
                if let self {
                    self.endManualMovementTracking()
                    self.autonomousMotion = nil
                    self.lastAutonomousFrameAt = nil
                    self.lastAutonomousOrigin = nil
                    self.scheduleAutonomousRest(
                        now: Date.timeIntervalSinceReferenceDate,
                        includeMoment: false
                    )
                }
                viewModel?.playMoment(animation: .waving, bubbleText: "呼びましたか?", duration: 1.6)
            }
        )
        panel.contentView = interactionView

        viewModel.$clickThrough
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePointerPassThrough()
            }
            .store(in: &cancellables)

        viewModel.$debugOverlay
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] debugOverlay in
                self?.updateWindowAppearance(debugOverlay: debugOverlay)
                self?.updatePointerPassThrough()
            }
            .store(in: &cancellables)

        viewModel.$autonomousWindowMovementEnabled
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                let now = Date.timeIntervalSinceReferenceDate
                if enabled {
                    self.autonomousRestUntil = now
                    self.nextAutonomousRetargetAt = now
                    self.nextIdleMomentAt = now + PetAutonomousMotionTuning.productionInitialRestSeconds
                    self.scheduleMovementTimer(activeCadence: false, force: true)
                } else {
                    self.stopAutonomousMotion()
                    self.scheduleAutonomousRest(now: now, includeMoment: true)
                }
            }
            .store(in: &cancellables)

        if !showcaseMode {
            startMovementTracking()
        }
        startPointerPassThroughTracking()
    }

    deinit {
        movementTimer?.invalidate()
        pointerPassThroughTimer?.invalidate()
    }

    func show() {
        applyWindowZOrderPolicy()
        panel.orderFrontRegardless()
        updatePointerPassThrough()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func startMovementTracking() {
        scheduleMovementTimer(activeCadence: false, force: true)
    }

    private func startPointerPassThroughTracking() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePointerPassThrough()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerPassThroughTimer = timer
        updatePointerPassThrough()
    }

    private func updatePointerPassThrough() {
        let target: PetInteractionHitTarget
        if let contentView = panel.contentView {
            let windowPoint = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
            let localPoint = contentView.convert(windowPoint, from: nil)
            target = viewModel.interactionTarget(
                at: PetWanderPoint(x: Double(localPoint.x), y: Double(localPoint.y)),
                in: PetDragFrame(contentView.bounds)
            )
        } else {
            target = .none
        }
        let shouldIgnore = PetPointerPassThroughPolicy.ignoresMouseEvents(
            clickThrough: viewModel.clickThrough,
            debugOverlay: viewModel.debugOverlay,
            isDragging: manualDragActive,
            target: target
        )
        if panel.ignoresMouseEvents != shouldIgnore {
            panel.ignoresMouseEvents = shouldIgnore
        }
    }

    private func scheduleMovementTimer(activeCadence: Bool, force: Bool = false) {
        guard force || movementTimer == nil || movementTimerIsActiveCadence != activeCadence else { return }
        movementTimer?.invalidate()
        movementTimerIsActiveCadence = activeCadence
        let timer = Timer(
            timeInterval: PetAutonomousMotionCadence.interval(isActivelyMoving: activeCadence),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.movementTimerFired()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        movementTimer = timer
    }

    private func updateWindowAppearance(debugOverlay: Bool) {
        let size = debugOverlay ? Self.debugSize : Self.productionSize
        let frame = panel.frame
        let nextOrigin = NSPoint(x: frame.minX, y: frame.maxY - size.height)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = debugOverlay
        applyWindowZOrderPolicy()
        panel.setFrame(NSRect(origin: nextOrigin, size: size), display: true, animate: false)
        lastAutonomousOrigin = PetWanderPoint(x: Double(nextOrigin.x), y: Double(nextOrigin.y))
    }

    private func applyWindowZOrderPolicy() {
        panel.level = zOrderPolicy.levelKind.nsWindowLevel

        var behavior: NSWindow.CollectionBehavior = []
        if zOrderPolicy.joinsAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        }
        if zOrderPolicy.joinsFullscreenSpaces {
            behavior.insert(.fullScreenAuxiliary)
        }
        if zOrderPolicy.staysOutOfWindowCycle {
            behavior.insert(.ignoresCycle)
        }
        panel.collectionBehavior = behavior
        panel.hidesOnDeactivate = !zOrderPolicy.staysVisibleWhenInactive
    }

    private func movementTimerFired() {
        if manualDragActive {
            scheduleMovementTimer(activeCadence: true)
            updateMovementAnimation()
            return
        }
        guard !autonomousDisabled else {
            scheduleMovementTimer(activeCadence: false)
            clearMovementAnimationIfNeeded()
            movementHandler.reset()
            return
        }
        if updateAutonomousMotion() {
            scheduleMovementTimer(activeCadence: autonomousMotion != nil)
            return
        }
        scheduleMovementTimer(activeCadence: false)
        updateMovementAnimation()
    }

    private func updateMovementAnimation() {
        guard panel.isVisible else {
            clearMovementAnimationIfNeeded()
            movementHandler.reset()
            return
        }

        let update = movementHandler.update(
            sample: PetMovementSample(
                frame: currentOnScreenFrame(),
                timestamp: Date.timeIntervalSinceReferenceDate
            )
        )

        if let animation = update.animation {
            if manualDragActive {
                beginMovementAnimation(animation, manual: true)
            } else {
                beginMovementAnimation(animation, manual: false)
            }
        } else if movementAnimationActive, !update.isMoving {
            clearMovementAnimationIfNeeded()
        }
    }

    private func beginMovementAnimation(_ animation: PetAnimationState, manual: Bool) {
        let shouldApply = !movementAnimationActive ||
            movementAnimationWasManual != manual ||
            viewModel.presentation.animation != animation
        movementAnimationActive = true
        movementAnimationWasManual = manual
        guard shouldApply else { return }
        if manual {
            viewModel.beginDrag(animation: animation)
        } else {
            viewModel.beginAmbientMovement(animation: animation)
        }
    }

    private func clearMovementAnimationIfNeeded() {
        guard movementAnimationActive else { return }
        let wasManual = movementAnimationWasManual
        movementAnimationActive = false
        movementAnimationWasManual = false
        if wasManual {
            viewModel.endDrag()
        } else {
            viewModel.endAmbientMovement()
        }
    }

    @discardableResult
    private func updateAutonomousMotion() -> Bool {
        let now = Date.timeIntervalSinceReferenceDate

        guard panel.isVisible, !manualDragActive, !autonomousDisabled else { return false }

        autonomousEnergy.update(
            now: now,
            isMoving: autonomousMotion != nil,
            isResting: autonomousMotion == nil
        )

        if now >= nextIdleMomentAt, autonomousMotion == nil {
            playRandomRestingMoment()
            nextIdleMomentAt = now + Double.random(
                in: PetAutonomousMotionPolicy.idleMomentDelayRange(
                    windowMovementEnabled: autonomousWindowMovementEnabled
                )
            )
        }

        if !autonomousWindowMovementEnabled {
            if autonomousMotion != nil {
                stopAutonomousMotion()
            }
            if now >= autonomousRestUntil {
                scheduleAutonomousRest(now: now, includeMoment: true)
            }
            return false
        }

        if autonomousMotion == nil, now >= autonomousRestUntil {
            if shouldBeginAutonomousMotion() {
                chooseNextAutonomousMotion(now: now)
            } else {
                scheduleAutonomousRest(now: now, includeMoment: true)
            }
        }

        guard let motion = autonomousMotion else { return false }

        let position = motion.position(at: now)
        let limitedOrigin = limitedAutonomousOrigin(desired: position.origin, motion: motion, now: now)
        panel.setFrameOrigin(NSPoint(x: limitedOrigin.x, y: limitedOrigin.y))
        if let animation = PetAutonomousMotionAnimationPolicy.animation(
            for: motion,
            currentOrigin: limitedOrigin,
            isAlreadyAnimating: movementAnimationActive
        ) {
            beginMovementAnimation(animation, manual: false)
        }

        if position.isComplete,
           hypot(limitedOrigin.x - motion.target.x, limitedOrigin.y - motion.target.y) <= 2 {
            autonomousMotion = nil
            lastAutonomousFrameAt = nil
            lastAutonomousOrigin = nil
            clearMovementAnimationIfNeeded()
            movementHandler.reset()
            scheduleAutonomousRest(now: now, includeMoment: true)
            return true
        }

        if now >= nextAutonomousRetargetAt {
            if shouldInterruptAutonomousMotionForRest() {
                autonomousMotion = nil
                lastAutonomousFrameAt = nil
                lastAutonomousOrigin = nil
                clearMovementAnimationIfNeeded()
                movementHandler.reset()
                scheduleAutonomousRest(now: now, includeMoment: true)
            } else {
                chooseNextAutonomousMotion(now: now)
            }
        }
        return true
    }

    private func chooseNextAutonomousMotion(now: TimeInterval) {
        let screen = currentScreen()
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_280, height: 800)
        let start = PetWanderPoint(x: panel.frame.minX, y: panel.frame.minY)
        let target: PetWanderPoint
        let baseSpeed: Double
        let speedWaveAmplitude: Double
        let speedWaveCycles: Double
        let speedWavePhase: Double
        if autonomousTestMode {
            let bounds = PetAutonomousMotionPlanner.movementBounds(
                visibleFrame: PetDragFrame(visibleFrame),
                petWidth: panel.frame.width,
                petHeight: panel.frame.height
            )
            let targetX = start.x - 240 >= bounds.minX
                ? start.x - 240
                : min(bounds.maxX, start.x + 240)
            target = PetWanderPoint(
                x: targetX,
                y: min(max(start.y + 36, bounds.minY), bounds.maxY)
            )
            baseSpeed = 66
            speedWaveAmplitude = 0.12
            speedWaveCycles = 1.5
            speedWavePhase = 0
        } else if autonomousEnergyTestMode {
            let bounds = PetAutonomousMotionPlanner.movementBounds(
                visibleFrame: PetDragFrame(visibleFrame),
                petWidth: panel.frame.width,
                petHeight: panel.frame.height
            )
            let targetX = start.x + 88 <= bounds.maxX
                ? start.x + 88
                : max(bounds.minX, start.x - 88)
            target = PetWanderPoint(
                x: targetX,
                y: min(max(start.y + 18, bounds.minY), bounds.maxY)
            )
            baseSpeed = 32
            speedWaveAmplitude = 0.06
            speedWaveCycles = 0.8
            speedWavePhase = 0
        } else {
            target = PetAutonomousMotionPlanner.homeBoundedTarget(
                visibleFrame: PetDragFrame(visibleFrame),
                petWidth: panel.frame.width,
                petHeight: panel.frame.height,
                home: autonomousHomeOrigin,
                start: start,
                homeRadius: PetAutonomousMotionTuning.productionHomeRadius,
                minimumDistance: PetAutonomousMotionTuning.productionMinimumStepDistance,
                maximumStepDistance: PetAutonomousMotionTuning.productionMaximumStepDistance,
                verticalScale: PetAutonomousMotionTuning.productionVerticalStepScale,
                angleUnit: autonomousForceBegin ? 0 : Double.random(in: 0...1),
                distanceUnit: autonomousForceBegin ? 1 : Double.random(in: 0...1)
            )
            baseSpeed = autonomousEnergy.speed(
                maximumSpeed: PetAutonomousMotionTuning.productionMaximumSpeed,
                moodUnit: autonomousEnergyTestMode ? 0.5 : Double.random(in: 0...1)
            )
            speedWaveAmplitude = Double.random(in: PetAutonomousMotionTuning.productionSpeedWaveAmplitudeRange)
            speedWaveCycles = Double.random(in: PetAutonomousMotionTuning.productionSpeedWaveCyclesRange)
            speedWavePhase = Double.random(in: 0...(2 * Double.pi))
        }
        let motion = PetAutonomousMotionTween.make(
            start: start,
            target: target,
            startTime: now,
            baseSpeed: baseSpeed,
            maximumSpeed: (autonomousTestMode || autonomousEnergyTestMode) ? baseSpeed : PetAutonomousMotionTuning.productionMaximumSpeed,
            speedWaveAmplitude: speedWaveAmplitude,
            speedWaveCycles: speedWaveCycles,
            speedWavePhase: speedWavePhase
        )
        autonomousMotion = motion
        lastAutonomousFrameAt = nil
        lastAutonomousOrigin = start
        nextAutonomousRetargetAt = now + retargetDelay()
        scheduleMovementTimer(activeCadence: true)
    }

    private func shouldBeginAutonomousMotion() -> Bool {
        if autonomousTestMode {
            return true
        }
        if autonomousEnergy.shouldPauseForRest(moodUnit: fatigueMoodUnit()) {
            return false
        }
        if autonomousEnergyTestMode {
            return true
        }
        if autonomousForceBegin {
            return true
        }
        return Double.random(in: 0...1) < PetAutonomousMotionTuning.productionBeginMotionProbability
    }

    private func shouldInterruptAutonomousMotionForRest() -> Bool {
        guard !autonomousTestMode else { return false }
        return autonomousEnergy.shouldPauseForRest(moodUnit: fatigueMoodUnit())
    }

    private func scheduleAutonomousRest(now: TimeInterval, includeMoment: Bool) {
        let duration = autonomousEnergy.restDuration(
            moodUnit: autonomousEnergyTestMode ? 0 : Double.random(in: 0...1)
        )
        autonomousRestUntil = now + duration
        nextIdleMomentAt = now + Double.random(
            in: PetAutonomousMotionPolicy.restMomentDelayRange(
                windowMovementEnabled: autonomousWindowMovementEnabled
            )
        )
        if includeMoment {
            playRandomRestingMoment()
        }
    }

    private func retargetDelay() -> TimeInterval {
        if autonomousTestMode {
            return 60
        }
        if autonomousEnergyTestMode {
            return 1.6
        }
        return Double.random(in: PetAutonomousMotionTuning.productionRetargetDelayRange)
    }

    private func stopAutonomousMotion() {
        autonomousMotion = nil
        lastAutonomousFrameAt = nil
        lastAutonomousOrigin = nil
        clearMovementAnimationIfNeeded()
        movementHandler.reset()
        scheduleMovementTimer(activeCadence: false)
    }

    private func limitedAutonomousOrigin(
        desired: PetWanderPoint,
        motion: PetAutonomousMotionTween,
        now: TimeInterval
    ) -> PetWanderPoint {
        let current = lastAutonomousOrigin ?? PetWanderPoint(x: panel.frame.minX, y: panel.frame.minY)
        let elapsed = lastAutonomousFrameAt.map { now - $0 } ?? (1.0 / 60.0)
        lastAutonomousFrameAt = now
        let limited = PetAutonomousMotionFrameLimiter.limitedOrigin(
            current: current,
            desired: desired,
            maximumSpeed: maximumAutonomousFrameSpeed(for: motion),
            elapsed: elapsed
        )
        lastAutonomousOrigin = limited
        return limited
    }

    private func maximumAutonomousFrameSpeed(for motion: PetAutonomousMotionTween) -> Double {
        if autonomousTestMode {
            return 96
        }
        if autonomousEnergyTestMode {
            return 56
        }
        let distance = hypot(motion.target.x - motion.start.x, motion.target.y - motion.start.y)
        let averageSpeed = distance / max(motion.duration, 0.001)
        _ = averageSpeed
        return PetAutonomousMotionTuning.productionMaximumSpeed
    }

    private func currentScreen() -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ??
            NSScreen.main ??
            NSScreen.screens.first
    }

    private func fatigueMoodUnit() -> Double {
        autonomousEnergyTestMode ? 0 : Double.random(in: 0...1)
    }

    private func playRandomRestingMoment() {
        guard !viewModel.hasPendingConversationBubbles else { return }
        let options: [(PetAnimationState, String?)] = [
            (.idle, nil),
            (.review, viewModel.conversationLines.isEmpty ? nil : "メモ中"),
            (.waving, nil),
            (.jumping, nil),
            (.waiting, nil),
            (.waiting, nil)
        ]
        guard let option = options.randomElement() else { return }
        viewModel.playMoment(animation: option.0, bubbleText: option.1, duration: Double.random(in: 2.8...4.2))
    }

    private func currentOnScreenFrame() -> PetDragFrame {
        PetDragFrame(panel.frame)
    }

    private func rememberAutonomousHomeOrigin() {
        autonomousHomeOrigin = PetWanderPoint(x: panel.frame.minX, y: panel.frame.minY)
    }

    private func beginManualMovementTracking() {
        manualDragActive = true
        scheduleMovementTimer(activeCadence: true)
        manualMovementTrackingStarted = true
        autonomousMotion = nil
        lastAutonomousFrameAt = nil
        lastAutonomousOrigin = nil
        clearMovementAnimationIfNeeded()
        movementHandler.begin(sample: PetMovementSample(
            frame: currentOnScreenFrame(),
            timestamp: Date.timeIntervalSinceReferenceDate
        ))
    }

    private func beginManualMovementTrackingIfNeeded() {
        manualDragActive = true
        guard !manualMovementTrackingStarted else { return }
        beginManualMovementTracking()
    }

    private func endManualMovementTracking() {
        clearMovementAnimationIfNeeded()
        manualDragActive = false
        manualMovementTrackingStarted = false
        movementHandler.reset()
        scheduleMovementTimer(activeCadence: false)
    }
}

private extension PetWindowController {
    static func makeAutonomousEnergyController() -> PetAutonomousEnergyController {
        PetAutonomousEnergyController(
            stamina: environmentDouble("MIMO_AUTONOMOUS_STAMINA_INITIAL", default: 1),
            drainPerSecond: environmentDouble(
                "MIMO_AUTONOMOUS_STAMINA_DRAIN_PER_SECOND",
                default: PetAutonomousEnergyController.defaultDrainPerSecond
            ),
            recoveryPerSecond: environmentDouble(
                "MIMO_AUTONOMOUS_STAMINA_RECOVERY_PER_SECOND",
                default: PetAutonomousEnergyController.defaultRecoveryPerSecond
            )
        )
    }

    static func environmentDouble(_ key: String, default defaultValue: Double) -> Double {
        guard
            let raw = ProcessInfo.processInfo.environment[key],
            let value = Double(raw),
            value.isFinite
        else {
            return defaultValue
        }
        return value
    }

    static func environmentOptionalBool(_ key: String) -> Bool? {
        guard let value = ProcessInfo.processInfo.environment[key]?.lowercased() else {
            return nil
        }
        switch value {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}

private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        false
    }
}

private final class PetInteractionView: NSView {
    private var dragHandler = PetDragEventHandler()
    private var dragActivation = PetManualDragActivation()
    private var initialWindowFrame: NSRect?
    private var initialPointerPoint: NSPoint?
    private var didMoveDuringDrag = false
    private var pointerTarget: PetInteractionHitTarget = .none

    private let isDebugOverlay: () -> Bool
    private let accessibilityValueProvider: () -> String
    private let onPointerDown: () -> Void
    private let onDragStarted: () -> Void
    private let onDragAnimationChanged: (PetAnimationState) -> Void
    private let onDragEnded: () -> Void
    private let openableBubbleAt: (NSPoint, NSRect) -> PetSpeechBubble?
    private let interactionTargetAt: (NSPoint, NSRect) -> PetInteractionHitTarget
    private let onPointerLocationChanged: () -> Void
    private let onHoveredBubbleChanged: (PetSpeechBubble?) -> Void
    private let onBubbleClicked: (PetSpeechBubble) -> Bool
    private let onClicked: () -> Void
    private var pointerTrackingArea: NSTrackingArea?

    init(
        hostedView: NSView,
        isDebugOverlay: @escaping () -> Bool,
        accessibilityValue: @escaping () -> String,
        onPointerDown: @escaping () -> Void,
        onDragStarted: @escaping () -> Void,
        onDragAnimationChanged: @escaping (PetAnimationState) -> Void,
        onDragEnded: @escaping () -> Void,
        openableBubbleAt: @escaping (NSPoint, NSRect) -> PetSpeechBubble?,
        interactionTargetAt: @escaping (NSPoint, NSRect) -> PetInteractionHitTarget,
        onPointerLocationChanged: @escaping () -> Void,
        onHoveredBubbleChanged: @escaping (PetSpeechBubble?) -> Void,
        onBubbleClicked: @escaping (PetSpeechBubble) -> Bool,
        onClicked: @escaping () -> Void
    ) {
        self.isDebugOverlay = isDebugOverlay
        self.accessibilityValueProvider = accessibilityValue
        self.onPointerDown = onPointerDown
        self.onDragStarted = onDragStarted
        self.onDragAnimationChanged = onDragAnimationChanged
        self.onDragEnded = onDragEnded
        self.openableBubbleAt = openableBubbleAt
        self.interactionTargetAt = interactionTargetAt
        self.onPointerLocationChanged = onPointerLocationChanged
        self.onHoveredBubbleChanged = onHoveredBubbleChanged
        self.onBubbleClicked = onBubbleClicked
        self.onClicked = onClicked
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(PetSpeechBubbleAccessibility.label)
        setAccessibilityIdentifier(PetSpeechBubbleAccessibility.identifier)

        addSubview(hostedView)
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool {
        false
    }

    override func accessibilityValue() -> Any? {
        accessibilityValueProvider()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isDebugOverlay() {
            return self
        }
        return interactionTargetAt(point, bounds) == .none ? nil : self
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        pointerTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onPointerLocationChanged()
        let bubble = openableBubbleAt(point, bounds)
        onHoveredBubbleChanged(bubble)
        if bubble != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        onPointerLocationChanged()
        onHoveredBubbleChanged(nil)
        NSCursor.arrow.set()
        guard dragHandler.isDragging else { return }
        super.mouseExited(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let pointerPoint = convert(event.locationInWindow, from: nil)
        pointerTarget = isDebugOverlay()
            ? .sprite
            : interactionTargetAt(pointerPoint, bounds)
        guard PetInteractionActionPolicy.action(
            for: pointerTarget,
            debugOverlay: isDebugOverlay()
        ) == .dragSprite else { return }
        let mouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
        initialPointerPoint = pointerPoint
        didMoveDuringDrag = false
        dragActivation.begin(at: PetWanderPoint(x: Double(mouseLocation.x), y: Double(mouseLocation.y)))
        onPointerDown()

        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self, weak window] dragEvent in
            guard let self, let window else { return dragEvent }
            self.updateDragAnimation(currentMouseLocation: NSEvent.mouseLocation, fallbackFrame: window.frame)
            return dragEvent
        }

        window.performDrag(with: event)

        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        finishDrag(finalFrame: window.frame)
    }

    override func mouseUp(with event: NSEvent) {
        guard pointerTarget == .bubble else {
            pointerTarget = .none
            super.mouseUp(with: event)
            return
        }
        defer { pointerTarget = .none }
        let point = convert(event.locationInWindow, from: nil)
        guard let bubble = openableBubbleAt(point, bounds) else { return }
        _ = onBubbleClicked(bubble)
    }

    private func updateDragAnimation(currentMouseLocation: NSPoint, fallbackFrame: NSRect) {
        let activation = dragActivation.update(
            to: PetWanderPoint(x: Double(currentMouseLocation.x), y: Double(currentMouseLocation.y))
        )
        guard activation.isActive else { return }

        if activation.didActivate {
            dragHandler.begin(frame: PetDragFrame(initialWindowFrame ?? fallbackFrame))
            onDragStarted()
        }

        let update = dragHandler.update(
            screenDeltaX: activation.screenDeltaX,
            screenDeltaY: activation.screenDeltaY,
            fallbackFrame: PetDragFrame(fallbackFrame)
        )
        didMoveDuringDrag = true
        if let animation = update.animation {
            onDragAnimationChanged(animation)
        }
    }

    private func finishDrag(finalFrame: NSRect) {
        pointerTarget = .none
        let frameMoved: Bool
        if let initialWindowFrame {
            frameMoved = hypot(
                finalFrame.origin.x - initialWindowFrame.origin.x,
                finalFrame.origin.y - initialWindowFrame.origin.y
            ) >= CGFloat(dragActivation.activationDistance)
        } else {
            frameMoved = false
        }
        initialWindowFrame = nil
        let clickPoint = initialPointerPoint
        initialPointerPoint = nil
        let wasActive = dragActivation.end()
        dragHandler.end()
        if didMoveDuringDrag || wasActive || frameMoved {
            onDragEnded()
        } else {
            if let clickPoint,
               let bubble = openableBubbleAt(clickPoint, bounds),
               onBubbleClicked(bubble) {
                return
            }
            onClicked()
        }
    }
}

private extension PetDragFrame {
    init(_ rect: NSRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }
}

private extension NSRect {
    init(_ frame: PetDragFrame) {
        self.init(
            x: frame.x,
            y: frame.y,
            width: frame.width,
            height: frame.height
        )
    }
}

private extension PetWindowLevelKind {
    var nsWindowLevel: NSWindow.Level {
        switch self {
        case .screenSaver:
            return .screenSaver
        }
    }
}
