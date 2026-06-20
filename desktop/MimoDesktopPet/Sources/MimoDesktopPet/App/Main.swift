import AppKit
import Darwin
import Foundation

@main
enum MimoDesktopPetMain {
    @MainActor
    static func main() {
        let appDelegate = AppDelegate()
        let app = NSApplication.shared

        signal(SIGPIPE, SIG_IGN)
        ProcessInfo.processInfo.disableAutomaticTermination("Mimo Desktop Pet stays available from the menu bar.")
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)
        app.run()

        _ = appDelegate
    }
}
