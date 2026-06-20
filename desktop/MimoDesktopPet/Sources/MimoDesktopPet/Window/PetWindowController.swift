import AppKit
import Combine
import SwiftUI
import MimoDesktopPetCore

@MainActor
final class PetWindowController: NSObject {
    private static let productionSize = NSSize(width: 270, height: 300)
    private static let debugSize = NSSize(width: 320, height: 430)

    private let panel: NSPanel
    private let viewModel: PetViewModel
    private var movementHandler = PetMovementEventHandler()
    private var movementTimer: Timer?
    private var movementAnimationActive = false
    private var manualDragActive = false
    private var autonomousTarget: NSPoint?
    private var autonomousBaseSpeed: CGFloat = 72
    private var autonomousRestUntil = Date.timeIntervalSinceReferenceDate + 2.0
    private var nextIdleMomentAt = Date.timeIntervalSinceReferenceDate + 4.0
    private var lastAutonomousTick = Date.timeIntervalSinceReferenceDate
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

        panel.title = "Mimo Desktop Pet"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = viewModel.debugOverlay
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
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
                self?.autonomousTarget = nil
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
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func startMovementTracking() {
        movementTimer?.invalidate()
        let timer = Timer(
            timeInterval: 1.0 / 15.0,
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
        panel.setFrame(NSRect(origin: nextOrigin, size: size), display: true, animate: false)
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
        movementAnimationActive = false
        viewModel.endDrag()
    }

    private func updateAutonomousMotion() {
        let now = Date.timeIntervalSinceReferenceDate
        let deltaTime = min(max(now - lastAutonomousTick, 0), 0.2)
        lastAutonomousTick = now

        guard panel.isVisible, !manualDragActive else { return }

        if now >= nextIdleMomentAt, autonomousTarget == nil {
            playRandomRestingMoment()
            nextIdleMomentAt = now + Double.random(in: 4.5...9.0)
        }

        if autonomousTarget == nil, now >= autonomousRestUntil {
            if Double.random(in: 0...1) < 0.72 {
                chooseNextAutonomousTarget()
            } else {
                autonomousRestUntil = now + Double.random(in: 2.0...5.0)
                playRandomRestingMoment()
            }
        }

        guard let target = autonomousTarget else { return }

        var frame = panel.frame
        let current = frame.origin
        let wave = 0.82 + 0.24 * sin(now * 2.7)
        let jitter = CGFloat.random(in: 0.84...1.18)
        let step = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: current.x, y: current.y),
            target: PetWanderPoint(x: target.x, y: target.y),
            baseSpeed: Double(autonomousBaseSpeed),
            elapsed: deltaTime,
            wave: wave,
            jitter: Double(jitter)
        )
        guard !step.reachedTarget else {
            autonomousTarget = nil
            autonomousRestUntil = now + Double.random(in: 2.0...6.0)
            return
        }
        frame.origin = NSPoint(x: CGFloat(step.origin.x), y: CGFloat(step.origin.y))
        panel.setFrame(frame, display: true)

        if Double.random(in: 0...1) < 0.002 {
            chooseNextAutonomousTarget()
        }
    }

    private func chooseNextAutonomousTarget() {
        let screens = NSScreen.screens
        let screen = screens.randomElement() ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_280, height: 800)
        let target = PetAutonomousMotionPlanner.target(
            visibleFrame: PetDragFrame(visibleFrame),
            petWidth: panel.frame.width,
            petHeight: panel.frame.height,
            randomX: Double.random(in: 0...1),
            randomY: Double.random(in: 0...1)
        )
        autonomousTarget = NSPoint(
            x: CGFloat(target.x),
            y: CGFloat(target.y)
        )
        autonomousBaseSpeed = CGFloat.random(in: 42...105)
    }

    private func playRandomRestingMoment() {
        let options: [(PetAnimationState, String?)] = [
            (.running, viewModel.conversationLines.isEmpty ? nil : "メモ中"),
            (.waving, nil),
            (.jumping, nil),
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
