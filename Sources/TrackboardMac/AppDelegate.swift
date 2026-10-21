import AppKit
import InputMethodKit
import InputMethodBridge

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?
    private var coordinator: InputCoordinator?
    private var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let coordinator = InputCoordinator()
        self.coordinator = coordinator
        TBInputController.setEventSink(coordinator)
        guard let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
              let identifier = Bundle.main.bundleIdentifier else {
            Self.showError("Run the packaged Trackboard.app, built with scripts/build.sh.")
            NSApp.terminate(nil)
            return
        }
        server = IMKServer(name: connection, bundleIdentifier: identifier)
        guard server != nil else {
            Self.showError("Trackboard could not start its input server. Log out and back in, then select Trackboard again.")
            NSApp.terminate(nil)
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "✎"
        item.button?.toolTip = "Trackboard handwriting"
        let menu = coordinator.inputMenu()
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Trackboard", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        if CommandLine.arguments.contains("--setup") { Self.showHelp() }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        coordinator?.hide()
        return .terminateNow
    }

    @objc private func quit() { NSApp.terminate(nil) }

    static func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Trackboard"
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.runModal()
    }

    static func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Write with your trackpad"
        alert.informativeText = """
        1. Add Trackboard in System Settings → Keyboard → Text Input → Edit → +. Look under Korean or search for Trackboard. If it is missing, log out and back in after installation.

        2. Click the text field you want to use, then choose Trackboard in the macOS input menu.

        3. Write lightly with one finger, lifting between strokes. Select Korean or English, pause for suggestions, and press Return to insert.

        Escape closes the pad. Control–Shift–Space opens it again while Trackboard is selected. Space inserts a trailing space; Delete undoes a stroke. Hold Option to move the pointer without drawing.

        Recognition stays on your Mac. Trackboard does not record your handwriting or use the clipboard. Some protected fields and apps can disable third-party input methods.
        """
        alert.addButton(withTitle: "Got it")
        alert.runModal()
    }

    /// Handle installation commands before creating an AppKit input session.
    public static func runCommandLineAction() -> Int32? {
        if CommandLine.arguments.contains("--register") {
            let status = TBRegisterInputSource(Bundle.main.bundlePath)
            if status == 0 { print("Trackboard input source registered and enabled.") }
            else { print("Registration returned \(status). Log out and back in, then add Trackboard in Keyboard settings.") }
            return status == 0 ? 0 : 1
        }
        if CommandLine.arguments.contains("--languages") {
            do { print(try TextRecognizer.supportedLanguages().joined(separator: "\n")); return 0 }
            catch { fputs("\(error.localizedDescription)\n", stderr); return 1 }
        }
        return nil
    }
}
