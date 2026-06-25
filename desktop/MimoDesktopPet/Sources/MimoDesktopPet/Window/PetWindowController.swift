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
    private let autonomousDisabled = ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_DISABLED"] == "1" ||
        ProcessInfo.processInfo.environment["MIMO_SHOWCASE_MODE"] == "1"
    private var movementHandler = PetMovementEventHandler()
    private var movementTimer: Timer?
    private var movementAnimationActive = false
    private var movementAnimationWasManual = false
    private var manualDragActive = false
    private var manualMovementTrackingStarted = false
    private var autonomousEnergy = PetWindowController.makeAutonomousEnergyController()
    private var autonomousMotion: PetAutonomousMotionTween?
    private var autonomousMotionAnimation: PetAnimationState?
    private var autonomousRestUntil = Date.timeIntervalSinceReferenceDate + PetWindowController.environmentDouble(
        "MIMO_AUTONOMOUS_INITIAL_REST_SECONDS",
        default: PetAutonomousMotionTuning.productionInitialRestSeconds
    )
    private var nextAutonomousRetargetAt = Date.timeIntervalSinceReferenceDate +
        PetAutonomousMotionTuning.productionRetargetDelayRange.lowerBound
    private var nextIdleMomentAt = Date.timeIntervalSinceReferenceDate +
        PetAutonomousMotionTuning.productionInitialRestSeconds
    private var cancellables: Set<AnyCancellable> = []

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

        if autonomousTestMode || autonomousEnergyTestMode {
            let now = Date.timeIntervalSinceReferenceDate
            autonomousRestUntil = now
            nextAutonomousRetargetAt = now + (autonomousEnergyTestMode ? 0.8 : 60)
            nextIdleMomentAt = .greatestFiniteMagnitude
        }

        panel.title = "Mimo Desktop Pet"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = viewModel.debugOverlay
        applyWindowZOrderPolicy()
        panel.isMovableByWindowBackground = true

        let frameProvider: AtlasFrameImageProvider?
        do {
            let package = try PetAssetLocator.findMimoPackage()
            frameProvider = try AtlasFrameImageProvider(spritesheetURL: package.spritesheetURL)
        } catch {
            frameProvider = nil
            viewModel.apply(snapshot: .offline)
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
                    self.scheduleAutonomousRest(
                        now: Date.timeIntervalSinceReferenceDate,
                        includeMoment: false
                    )
                }
                viewModel?.endDrag()
            },
            onClicked: { [weak self, weak viewModel] in
                if let self {
                    self.endManualMovementTracking()
                    self.autonomousMotion = nil
                    self.autonomousMotionAnimation = nil
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
            .sink { [weak panel] clickThrough in
                panel?.ignoresMouseEvents = clickThrough
            }
            .store(in: &cancellables)

        viewModel.$debugOverlay
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] debugOverlay in
                self?.updateWindowAppearance(debugOverlay: debugOverlay)
            }
            .store(in: &cancellables)

        if !showcaseMode {
            startMovementTracking()
        }
    }

    deinit {
        movementTimer?.invalidate()
    }

    func show() {
        applyWindowZOrderPolicy()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func startMovementTracking() {
        movementTimer?.invalidate()
        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(movementTimerFired),
            userInfo: nil,
            repeats: true
        )
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

    @objc private func movementTimerFired() {
        if manualDragActive {
            updateMovementAnimation()
            return
        }
        guard !autonomousDisabled else {
            clearMovementAnimationIfNeeded()
            movementHandler.reset()
            return
        }
        if updateAutonomousMotion() {
            return
        }
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
            nextIdleMomentAt = now + Double.random(in: PetAutonomousMotionTuning.productionIdleMomentDelayRange)
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
        panel.setFrameOrigin(NSPoint(x: position.origin.x, y: position.origin.y))
        beginMovementAnimation(autonomousMotionAnimation ?? motion.directionAnimation, manual: false)

        if position.isComplete {
            autonomousMotion = nil
            autonomousMotionAnimation = nil
            clearMovementAnimationIfNeeded()
            movementHandler.reset()
            scheduleAutonomousRest(now: now, includeMoment: true)
            return true
        }

        if now >= nextAutonomousRetargetAt {
            if shouldInterruptAutonomousMotionForRest() {
                autonomousMotion = nil
                autonomousMotionAnimation = nil
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
        let screens = NSScreen.screens
        let screen = screens.randomElement() ?? NSScreen.main
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
        } else {
            let rawTarget = PetAutonomousMotionPlanner.target(
                visibleFrame: PetDragFrame(visibleFrame),
                petWidth: panel.frame.width,
                petHeight: panel.frame.height,
                randomX: Double.random(in: 0...1),
                randomY: Double.random(in: 0...1)
            )
            target = PetAutonomousMotionPlanner.limitedTarget(
                start: start,
                rawTarget: rawTarget,
                maximumDistance: PetAutonomousMotionTuning.productionMaximumStepDistance
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
            maximumSpeed: autonomousTestMode ? baseSpeed : PetAutonomousMotionTuning.productionMaximumSpeed,
            speedWaveAmplitude: speedWaveAmplitude,
            speedWaveCycles: speedWaveCycles,
            speedWavePhase: speedWavePhase
        )
        autonomousMotion = motion
        autonomousMotionAnimation = motion.directionAnimation
        nextAutonomousRetargetAt = now + retargetDelay()
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
        nextIdleMomentAt = now + Double.random(in: PetAutonomousMotionTuning.productionRestMomentDelayRange)
        if includeMoment {
            playRandomRestingMoment()
        }
    }

    private func retargetDelay() -> TimeInterval {
        if autonomousTestMode {
            return 60
        }
        if autonomousEnergyTestMode {
            return 0.8
        }
        return Double.random(in: PetAutonomousMotionTuning.productionRetargetDelayRange)
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
        viewModel.playMoment(animation: option.0, bubbleText: option.1, duration: Double.random(in: 1.4...2.4))
    }

    private func currentOnScreenFrame() -> PetDragFrame {
        PetDragFrame(panel.frame)
    }

    private func beginManualMovementTracking() {
        manualDragActive = true
        manualMovementTrackingStarted = true
        autonomousMotion = nil
        autonomousMotionAnimation = nil
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
    private var didMoveDuringDrag = false

    private let isDebugOverlay: () -> Bool
    private let accessibilityValueProvider: () -> String
    private let onPointerDown: () -> Void
    private let onDragStarted: () -> Void
    private let onDragAnimationChanged: (PetAnimationState) -> Void
    private let onDragEnded: () -> Void
    private let onClicked: () -> Void

    init(
        hostedView: NSView,
        isDebugOverlay: @escaping () -> Bool,
        accessibilityValue: @escaping () -> String,
        onPointerDown: @escaping () -> Void,
        onDragStarted: @escaping () -> Void,
        onDragAnimationChanged: @escaping (PetAnimationState) -> Void,
        onDragEnded: @escaping () -> Void,
        onClicked: @escaping () -> Void
    ) {
        self.isDebugOverlay = isDebugOverlay
        self.accessibilityValueProvider = accessibilityValue
        self.onPointerDown = onPointerDown
        self.onDragStarted = onDragStarted
        self.onDragAnimationChanged = onDragAnimationChanged
        self.onDragEnded = onDragEnded
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
        PetInteractionHitRegion.contains(
            point: PetWanderPoint(x: Double(point.x), y: Double(point.y)),
            bounds: PetDragFrame(bounds),
            debugOverlay: isDebugOverlay()
        ) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let mouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
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

    override func mouseExited(with event: NSEvent) {
        guard dragHandler.isDragging else { return }
        super.mouseExited(with: event)
    }

    private func finishDrag(finalFrame: NSRect) {
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
        let wasActive = dragActivation.end()
        dragHandler.end()
        if didMoveDuringDrag || wasActive || frameMoved {
            onDragEnded()
        } else {
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
