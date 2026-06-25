import AppKit
import MimoDesktopPetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = PetViewModel()
    private var petWindowController: PetWindowController?
    private var statusItemController: StatusItemController?
    private var appServerClient: CodexAppServerClient?
    private var showcaseDriver: PetShowcaseDriver?
    private let showcaseMode = ProcessInfo.processInfo.environment["MIMO_SHOWCASE_MODE"] == "1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowController = PetWindowController(viewModel: viewModel)
        let statusController = StatusItemController(
            viewModel: viewModel,
            onShow: { [weak windowController] in windowController?.show() },
            onHide: { [weak windowController] in windowController?.hide() },
            onReconnect: { [weak self] in self?.reconnectCodex() },
            onQuit: { NSApp.terminate(nil) }
        )

        petWindowController = windowController
        statusItemController = statusController
        windowController.show()

        if showcaseMode {
            startShowcase()
        } else {
            reconnectCodex()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appServerClient?.stop()
        showcaseDriver?.stop()
    }

    private func reconnectCodex() {
        guard !showcaseMode else {
            startShowcase()
            return
        }

        appServerClient?.stop()

        let client = CodexAppServerClient()
        client.onStateSnapshot = { [weak viewModel] snapshot in
            Task { @MainActor in
                viewModel?.apply(snapshot: snapshot)
            }
        }
        client.onConnectionState = { [weak viewModel] isConnected in
            Task { @MainActor in
                viewModel?.setConnectionAvailable(isConnected)
            }
        }

        appServerClient = client
        client.start()
    }

    private func startShowcase() {
        appServerClient?.stop()
        if showcaseDriver == nil {
            showcaseDriver = PetShowcaseDriver(viewModel: viewModel)
        }
        showcaseDriver?.start()
    }
}
