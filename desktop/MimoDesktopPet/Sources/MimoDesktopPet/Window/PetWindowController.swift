import AppKit
import Combine
import SwiftUI
import MimoDesktopPetCore

@MainActor
final class PetWindowController: NSObject {
    private let panel: NSPanel
    private let viewModel: PetViewModel
    private var movementHandler = PetMovementEventHandler()
    private var movementTimer: Timer?
    private var movementAnimationActive = false
    private var cancellables: Set<AnyCancellable> = []

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel

        let size = NSSize(width: 250, height: 300)
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
        panel.hasShadow = false
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
            onDragAnimationChanged: { [weak viewModel] animation in
                viewModel?.beginDrag(animation: animation)
            },
            onDragEnded: { [weak viewModel] in
                viewModel?.endDrag()
            }
        )
        panel.contentView = interactionView

        viewModel.$clickThrough
            .receive(on: RunLoop.main)
            .sink { [weak panel] clickThrough in
                panel?.ignoresMouseEvents = clickThrough
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

    @objc private func movementTimerFired() {
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
            viewModel.beginDrag(animation: animation)
        } else if movementAnimationActive, !update.isMoving {
            clearMovementAnimationIfNeeded()
        }
    }

    private func clearMovementAnimationIfNeeded() {
        guard movementAnimationActive else { return }
        movementAnimationActive = false
        viewModel.endDrag()
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

    private let onDragAnimationChanged: (PetAnimationState) -> Void
    private let onDragEnded: () -> Void

    init(
        hostedView: NSView,
        onDragAnimationChanged: @escaping (PetAnimationState) -> Void,
        onDragEnded: @escaping () -> Void
    ) {
        self.onDragAnimationChanged = onDragAnimationChanged
        self.onDragEnded = onDragEnded
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
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        dragHandler.begin(frame: PetDragFrame(window.frame))

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
        onDragEnded()
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
