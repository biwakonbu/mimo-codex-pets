import AppKit
import Darwin
import Foundation
import MimoDesktopPetCore

@main
enum MimoDesktopPetMain {
    private static var singleInstanceLock: ProcessSingleInstanceLock?

    @MainActor
    static func main() {
        guard let lock = ProcessSingleInstanceLock.acquire(identifier: "com.biwakonbu.MimoDesktopPet") else {
            fputs("MimoDesktopPet is already running.\n", stderr)
            return
        }
        singleInstanceLock = lock

        let appDelegate = AppDelegate()
        let app = NSApplication.shared

        signal(SIGPIPE, SIG_IGN)
        ProcessInfo.processInfo.disableAutomaticTermination("Mimo Desktop Pet stays available from the menu bar.")
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)
        app.run()

        _ = appDelegate
        _ = singleInstanceLock
    }
}
