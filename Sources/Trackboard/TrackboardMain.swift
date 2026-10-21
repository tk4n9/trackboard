import AppKit
import TrackboardMac

@main
struct TrackboardMain {
    @MainActor
    static func main() {
        if let status = AppDelegate.runCommandLineAction() { exit(status) }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
