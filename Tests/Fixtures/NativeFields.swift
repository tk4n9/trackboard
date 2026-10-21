// Run on macOS with: swift Tests/Fixtures/NativeFields.swift
import AppKit

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 640, height: 430),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Trackboard native input checks"
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 430))
        window.contentView = root
        let instructions = NSTextField(wrappingLabelWithString:
            "Click a field, select Trackboard, then write Korean and English. Test replacing a selection and Edit → Undo.")
        instructions.frame = NSRect(x: 24, y: 360, width: 592, height: 45)
        root.addSubview(instructions)

        let field = NSTextField(string: "Replace this selection")
        field.frame = NSRect(x: 24, y: 300, width: 592, height: 32)
        field.placeholderString = "Single-line text field"
        root.addSubview(field)

        let scroll = NSScrollView(frame: NSRect(x: 24, y: 116, width: 592, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let text = NSTextView(frame: scroll.bounds)
        text.font = .systemFont(ofSize: 22)
        text.isRichText = true
        text.allowsUndo = true
        scroll.documentView = text
        root.addSubview(scroll)

        let label = NSTextField(labelWithString: "Protected field — input methods may be disabled by macOS:")
        label.frame = NSRect(x: 24, y: 76, width: 592, height: 22)
        root.addSubview(label)
        let secure = NSSecureTextField(frame: NSRect(x: 24, y: 30, width: 592, height: 32))
        root.addSubview(secure)

        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editItem.submenu = edit
        NSApp.mainMenu = menu
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = FixtureDelegate()
application.delegate = delegate
application.run()
