import AppKit
import Combine
import MimoDesktopPetCore

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let viewModel: PetViewModel
    private let onShow: () -> Void
    private let onHide: () -> Void
    private let onReconnect: () -> Void
    private let onQuit: () -> Void
    private let menuLogURL: URL?
    private var clickThroughItem: NSMenuItem?
    private var debugOverlayItem: NSMenuItem?
    private var cancellables: Set<AnyCancellable> = []

    init(
        viewModel: PetViewModel,
        onShow: @escaping () -> Void,
        onHide: @escaping () -> Void,
        onReconnect: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onShow = onShow
        self.onHide = onHide
        self.onReconnect = onReconnect
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menuLogURL = Self.resolveMenuLogURL()
        super.init()

        statusItem.button?.title = "Mimo"
        configureMenu()

        viewModel.$clickThrough
            .receive(on: RunLoop.main)
            .sink { [weak self] clickThrough in
                self?.clickThroughItem?.state = clickThrough ? .on : .off
            }
            .store(in: &cancellables)

        viewModel.$debugOverlay
            .receive(on: RunLoop.main)
            .sink { [weak self] debugOverlay in
                self?.debugOverlayItem?.state = debugOverlay ? .on : .off
            }
            .store(in: &cancellables)
    }

    private func configureMenu() {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Mimo", action: #selector(showMimo), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let hideItem = NSMenuItem(title: "Hide Mimo", action: #selector(hideMimo), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(.separator())

        let clickItem = NSMenuItem(title: "Click Through", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickItem.target = self
        clickItem.state = viewModel.clickThrough ? .on : .off
        clickThroughItem = clickItem
        menu.addItem(clickItem)

        if PetDebugOverlayPolicy.isMenuVisible() {
            let debugItem = NSMenuItem(title: "Debug Overlay", action: #selector(toggleDebugOverlay), keyEquivalent: "")
            debugItem.target = self
            debugItem.state = viewModel.debugOverlay ? .on : .off
            debugOverlayItem = debugItem
            menu.addItem(debugItem)
        }

        let reconnectItem = NSMenuItem(title: "Reconnect Codex", action: #selector(reconnectCodex), keyEquivalent: "")
        reconnectItem.target = self
        menu.addItem(reconnectItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        appendMenuLog(menu)
    }

    @objc private func showMimo() {
        onShow()
    }

    @objc private func hideMimo() {
        onHide()
    }

    @objc private func toggleClickThrough() {
        viewModel.toggleClickThrough()
    }

    @objc private func toggleDebugOverlay() {
        viewModel.toggleDebugOverlay()
    }

    @objc private func reconnectCodex() {
        onReconnect()
    }

    @objc private func quit() {
        onQuit()
    }

    private static func resolveMenuLogURL() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["MIMO_STATUS_MENU_LOG"], !path.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)
        FileManager.default.createFile(atPath: path, contents: nil)
        return url
    }

    private func appendMenuLog(_ menu: NSMenu) {
        guard let menuLogURL else { return }
        let itemTitles = menu.items.compactMap { item in
            item.isSeparatorItem ? nil : item.title
        }
        let object: [String: Any] = [
            "buttonTitle": statusItem.button?.title ?? "",
            "menuTitles": itemTitles,
            "debugMenuVisible": itemTitles.contains("Debug Overlay")
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: object),
            let newline = "\n".data(using: .utf8)
        else { return }

        if let handle = try? FileHandle(forWritingTo: menuLogURL) {
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
            _ = try? handle.write(contentsOf: newline)
            _ = try? handle.close()
        } else {
            var line = data
            line.append(newline)
            try? line.write(to: menuLogURL)
        }
    }
}
