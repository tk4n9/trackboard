import AppKit
import TrackboardMac

if let status = AppDelegate.runCommandLineAction() { exit(status) }
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
