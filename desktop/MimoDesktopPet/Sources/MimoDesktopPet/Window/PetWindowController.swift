import AppKit
import Combine
import SwiftUI
import MimoDesktopPetCore

@MainActor
final class PetWindowController: NSObject {
    private static let productionSize = NSSize(width: 360, height: 350)
    private static let debugSize = NSSize(width: 320, height: 430)
    private static let maximumProductionSpeed = 52.0
    private static let maximumProductionStepDistance = 170.0

    private let panel: NSPanel
    private let viewModel: PetViewModel
    private let zOrderPolicy = PetWindowZOrderPolicy.alwaysOnTopCompanion
    private let autonomousTestMode = ProcessInfo.processInfo.environment["MIMO_AUTONOMOUS_TEST_MODE"] == "1"
    private var movementHandler = PetMovementEventHandler()
    private var movementTimer: Timer?
    private var movementAnimationActive = false
    private var movementAnimationWasManual = false
    private var manualDragActive = false
    private var autonomousMotion: PetAutonomousMotionTween?
    private var autonomousRestUntil = Date.timeIntervalSinceReferenceDate + 2.0
    private var nextAutonomousRetargetAt = Date.timeIntervalSinceReferenceDate + 10.0
    private var nextIdleMomentAt = Date.timeIntervalSinceReferenceDate + 4.0
    private var cancellables: Set<AnyCancellable> = []

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel

        let size = viewModel.debugOverlay ? Self.debugSize : Self.productionSize
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_280, height: 800)
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 32,
            y: visibleFrame.minY + 80
        )

        panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        if autonomousTestMode {
            let now = Date.timeIntervalSinceReferenceDate
            autonomousRestUntil = now
            nextAutonomousRetargetAt = now + 60
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
            onDragStarted: { [weak self] in
                self?.manualDragActive = true
                self?.autonomousMotion = nil
            },
            onDragAnimationChanged: { [weak viewModel] animation in
                viewModel?.beginDrag(animation: animation)
            },
            onDragEnded: { [weak self, weak viewModel] in
                self?.manualDragActive = false
                self?.autonomousRestUntil = Date.timeIntervalSinceReferenceDate + Double.random(in: 2.0...5.0)
                viewModel?.endDrag()
            },
            onClicked: { [weak self, weak viewModel] in
                self?.manualDragActive = false
                self?.autonomousRestUntil = Date.timeIntervalSinceReferenceDate + Double.random(in: 1.5...4.0)
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

        startMovementTracking()
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
        updateAutonomousMotion()
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
            movementAnimationActive = true
            movementAnimationWasManual = manualDragActive
            if manualDragActive {
                viewModel.beginDrag(animation: animation)
            } else {
                viewModel.beginAmbientMovement(animation: animation)
            }
        } else if movementAnimationActive, !update.isMoving {
            clearMovementAnimationIfNeeded()
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

    private func updateAutonomousMotion() {
        let now = Date.timeIntervalSinceReferenceDate

        guard panel.isVisible, !manualDragActive else { return }

        if now >= nextIdleMomentAt, autonomousMotion == nil {
            playRandomRestingMoment()
            nextIdleMomentAt = now + Double.random(in: 3.0...6.5)
        }

        if autonomousMotion == nil, now >= autonomousRestUntil {
            if autonomousTestMode || Double.random(in: 0...1) < 0.52 {
                chooseNextAutonomousMotion(now: now)
            } else {
                autonomousRestUntil = now + Double.random(in: 3.5...8.0)
                playRandomRestingMoment()
            }
        }

        guard let motion = autonomousMotion else { return }

        let position = motion.position(at: now)
        panel.setFrameOrigin(NSPoint(x: position.origin.x, y: position.origin.y))

        if position.isComplete {
            autonomousMotion = nil
            autonomousRestUntil = now + Double.random(in: 3.5...8.5)
            playRandomRestingMoment()
            return
        }

        if now >= nextAutonomousRetargetAt {
            chooseNextAutonomousMotion(now: now)
        }
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
                maximumDistance: Self.maximumProductionStepDistance
            )
            baseSpeed = Double.random(in: 30...Self.maximumProductionSpeed)
            speedWaveAmplitude = Double.random(in: 0.08...0.18)
            speedWaveCycles = Double.random(in: 1.0...2.4)
            speedWavePhase = Double.random(in: 0...(2 * Double.pi))
        }
        autonomousMotion = PetAutonomousMotionTween.make(
            start: start,
            target: target,
            startTime: now,
            baseSpeed: baseSpeed,
            maximumSpeed: Self.maximumProductionSpeed,
            speedWaveAmplitude: speedWaveAmplitude,
            speedWaveCycles: speedWaveCycles,
            speedWavePhase: speedWavePhase
        )
        nextAutonomousRetargetAt = now + (autonomousTestMode ? 60 : Double.random(in: 10.0...22.0))
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
        guard
            panel.windowNumber > 0,
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionIncludingWindow],
                CGWindowID(panel.windowNumber)
            ) as? [[String: Any]],
            let bounds = windowInfo.first?[kCGWindowBounds as String] as? [String: Any],
            let x = bounds["X"] as? Double,
            let y = bounds["Y"] as? Double,
            let width = bounds["Width"] as? Double,
            let height = bounds["Height"] as? Double
        else {
            return PetDragFrame(panel.frame)
        }

        return PetDragFrame(x: x, y: y, width: width, height: height)
    }
}

private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        false
    }
}

private final class PetInteractionView: NSView {
    private var dragHandler = PetDragEventHandler()
    private var initialMouseLocation: NSPoint?
    private var didMoveDuringDrag = false

    private let isDebugOverlay: () -> Bool
    private let onDragStarted: () -> Void
    private let onDragAnimationChanged: (PetAnimationState) -> Void
    private let onDragEnded: () -> Void
    private let onClicked: () -> Void

    init(
        hostedView: NSView,
        isDebugOverlay: @escaping () -> Bool,
        onDragStarted: @escaping () -> Void,
        onDragAnimationChanged: @escaping (PetAnimationState) -> Void,
        onDragEnded: @escaping () -> Void,
        onClicked: @escaping () -> Void
    ) {
        self.isDebugOverlay = isDebugOverlay
        self.onDragStarted = onDragStarted
        self.onDragAnimationChanged = onDragAnimationChanged
        self.onDragEnded = onDragEnded
        self.onClicked = onClicked
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false

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
        initialMouseLocation = NSEvent.mouseLocation
        didMoveDuringDrag = false
        dragHandler.begin(frame: PetDragFrame(window.frame))
        onDragStarted()

        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self, weak window] dragEvent in
            guard let self, let window else { return dragEvent }
            self.updateDragAnimation(currentMouseLocation: NSEvent.mouseLocation, fallbackFrame: window.frame)
            return dragEvent
        }

        window.performDrag(with: event)

        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        finishDrag()
    }

    private func updateDragAnimation(currentMouseLocation: NSPoint, fallbackFrame: NSRect) {
        let initialMouseLocation = initialMouseLocation ?? currentMouseLocation
        let update = dragHandler.update(
            screenDeltaX: currentMouseLocation.x - initialMouseLocation.x,
            screenDeltaY: currentMouseLocation.y - initialMouseLocation.y,
            fallbackFrame: PetDragFrame(fallbackFrame)
        )
        if abs(currentMouseLocation.x - initialMouseLocation.x) > 2 || abs(currentMouseLocation.y - initialMouseLocation.y) > 2 {
            didMoveDuringDrag = true
        }
        if let animation = update.animation {
            onDragAnimationChanged(animation)
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard dragHandler.isDragging else { return }
        super.mouseExited(with: event)
    }

    private func finishDrag() {
        initialMouseLocation = nil
        dragHandler.end()
        if didMoveDuringDrag {
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
