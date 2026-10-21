import AppKit
import InputMethodBridge
import TrackboardCore

@MainActor
final class InputCoordinator: NSObject, TBInputEventSink {
    private var capture = StrokeCapture()
    var document: InkDocument { capture.document }
    private(set) var recognition = RecognitionState()
    private(set) var message = "Write lightly with one finger. Lift between strokes."
    private(set) var languages: [String] = []
    private(set) var language: String
    private(set) var correctSpelling: Bool
    private(set) var isVisible = false
    var isTouching: Bool { capture.isTouching }
    private weak var controller: TBInputController?
    private var panels: [CapturePanel] = []
    private var identities: [NSObject: Int] = [:]
    private var nextIdentity = 0
    private var debounce: DispatchWorkItem?
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Trackboard recognition"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    override init() {
        language = UserDefaults.standard.string(forKey: "recognitionLanguage") ?? "ko-KR"
        correctSpelling = UserDefaults.standard.object(forKey: "correctSpelling") as? Bool ?? true
        super.init()
        do {
            let available = try TextRecognizer.supportedLanguages()
            languages = ["ko-KR", "en-US"].filter(available.contains)
                + available.filter { $0 != "ko-KR" && $0 != "en-US" }.sorted()
            if !languages.contains(language), let first = languages.first { language = first }
        } catch {
            message = "Recognition is unavailable: \(error.localizedDescription)"
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil)
    }

    func sessionActivated(_ controller: TBInputController) {
        if self.controller !== controller { clear() }
        self.controller = controller
        show()
    }

    func sessionDeactivated(_ controller: TBInputController) {
        guard self.controller === controller else { return }
        hide()
        self.controller = nil
        clear()
    }

    func handleInputEvent(_ event: NSEvent, controller: TBInputController) -> Bool {
        guard self.controller === controller, event.type == .keyDown else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 49, modifiers.contains([.control, .shift]),
           modifiers.isDisjoint(with: [.command, .option]) {
            if !event.isARepeat { isVisible ? hide() : show() }
            return true
        }
        guard isVisible else { return false }
        if event.keyCode == 53 { hide(); return true }
        // Let app shortcuts (copy, save, quit, etc.) keep their usual behavior.
        if modifiers.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "z" { undo(); return true }
            hide()
            return false
        }
        switch event.keyCode {
        case 36, 76: insert(); return true
        case 51, 117: undo(); return true
        case 123: recognition.moveSelection(-1); refresh(); return true
        case 124, 48:
            recognition.moveSelection(modifiers.contains(.shift) ? -1 : 1)
            refresh(); return true
        case 49:
            if recognition.selectedText != nil { insert(appendSpace: true) }
            else { recognizeNow() }
            return true
        default:
            // A physical keyboard remains usable with Trackboard selected.
            // Do not insert handwriting later into a field the user is typing in.
            hide()
            return false
        }
    }

    func inputMenu() -> NSMenu {
        let menu = NSMenu()
        let show = NSMenuItem(title: "Show Handwriting  ⌃⇧Space", action: #selector(showFromMenu), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let help = NSMenuItem(title: "Trackboard Help", action: #selector(showHelp), keyEquivalent: "")
        help.target = self
        menu.addItem(help)
        return menu
    }

    @objc private func showFromMenu() {
        if controller == nil { AppDelegate.showHelp() } else { show() }
    }
    @objc private func showHelp() { hide(); AppDelegate.showHelp() }
    @objc private func screenConfigurationChanged() { hide() }
    @objc private func systemWillSleep() { hide(); clear() }

    func show() {
        guard controller != nil, !isVisible else { return }
        isVisible = true
        let preferredScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        panels = NSScreen.screens.map { screen in
            CapturePanel(screen: screen, coordinator: self, showsControls: screen === preferredScreen)
        }
        panels.forEach { $0.orderFrontRegardless() }
        scheduleRecognition()
        refresh()
    }

    func hide() {
        isVisible = false
        cancelPendingRecognition()
        capture.stop()
        identities.removeAll()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func cancelPendingRecognition() {
        debounce?.cancel()
        debounce = nil
        queue.cancelAllOperations()
        recognition.invalidate()
    }

    func clear() {
        cancelPendingRecognition()
        capture.clear()
        // Keep IDs stable until the current physical contact ends. Otherwise
        // a cleared contact can be mistaken for a newly placed finger.
        if !capture.isTouching { identities.removeAll() }
        message = "Write lightly with one finger. Lift between strokes."
        refresh()
    }

    func undo() {
        cancelPendingRecognition()
        capture.undo()
        message = document.isEmpty ? "Write a character or a short word." : "Last stroke removed."
        scheduleRecognition()
        refresh()
    }

    func setLanguage(_ value: String) {
        guard languages.contains(value), value != language else { return }
        language = value
        UserDefaults.standard.set(value, forKey: "recognitionLanguage")
        cancelPendingRecognition()
        scheduleRecognition()
        refresh()
    }

    func setCorrection(_ value: Bool) {
        correctSpelling = value
        UserDefaults.standard.set(value, forKey: "correctSpelling")
        cancelPendingRecognition()
        scheduleRecognition()
        refresh()
    }

    func selectCandidate(_ index: Int) { recognition.select(index); refresh() }

    func insert(appendSpace: Bool = false) {
        guard document.activeStroke == nil, let text = recognition.selectedText else {
            if !document.isEmpty { recognizeNow() }
            return
        }
        guard let controller, controller.commitText(text + (appendSpace ? " " : "")) else {
            message = "The text field is no longer available. Close the pad and select your field again."
            refresh()
            return
        }
        // Clear only after IMK has accepted the insertion for the active client.
        clear()
        message = "Inserted. Write the next word, or press Escape to close."
        refresh()
    }

    func recognizeNow() {
        debounce?.cancel()
        guard isVisible, !document.isEmpty, document.activeStroke == nil,
              !recognition.isRecognizing else { return }
        queue.cancelAllOperations()
        let snapshot = document
        let language = language
        let correction = correctSpelling
        let token = recognition.begin()
        message = "Recognizing…"
        refresh()
        queue.addOperation {
            let result: Result<[TextCandidate], Error> = autoreleasepool {
                Result { try TextRecognizer.recognize(snapshot, language: language, correctSpelling: correction) }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isVisible else { return }
                switch result {
                case .success(let candidates):
                    guard self.recognition.complete(candidates, token: token) else { return }
                    self.message = candidates.isEmpty
                        ? "No match yet. Try larger, separate letters or another language."
                        : "Choose a suggestion, then press Return to insert."
                case .failure(let error):
                    guard self.recognition.complete([], token: token) else { return }
                    self.message = error.localizedDescription
                }
                self.refresh()
            }
        }
    }

    private func scheduleRecognition() {
        guard !document.isEmpty, document.activeStroke == nil, isVisible else { return }
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recognizeNow() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: work)
    }

    private func identity(for touch: NSTouch) -> Int? {
        let key = touch.identity as AnyObject
        // AppKit identities are NSObject-backed; compare equality across snapshots.
        guard let object = key as? NSObject else { return nil }
        if let id = identities[object] { return id }
        nextIdentity += 1
        identities[object] = nextIdentity
        return nextIdentity
    }

    func processTouches(_ event: NSEvent, in view: NSView) {
        guard isVisible else { return }
        let touches = event.touches(matching: .touching, in: view)
            .filter { $0.type == .indirect && !$0.isResting }
        func samples<S: Sequence>(_ values: S) -> [Int: InkPoint] where S.Element == NSTouch {
            let pairs = values.compactMap { touch -> (Int, InkPoint)? in
                guard let id = identity(for: touch) else { return nil }
                return (id, InkPoint(x: touch.normalizedPosition.x, y: touch.normalizedPosition.y))
            }
            return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
        }
        let before = document.revision
        let device = touches.first?.deviceSize
        capture.process(
            active: samples(touches), ended: samples(event.touches(matching: .ended, in: view)),
            navigating: event.modifierFlags.contains(.option),
            deviceAspectRatio: device.flatMap { $0.height > 0 ? Double($0.width / $0.height) : nil }
        )
        if before != document.revision {
            cancelPendingRecognition()
        }
        if document.activeStroke != nil {
            message = "Lift your finger between strokes. Recognition starts when you pause."
        } else if capture.waitingForLift {
            message = "Lift all fingers before writing again."
        }
        if !capture.isTouching {
            identities.removeAll()
            scheduleRecognition()
        }
        refresh()
    }

    func cancelContact(_ event: NSEvent, in view: NSView) {
        let interruptedStroke = document.activeStroke != nil
        let contactsRemain = event.touches(matching: .touching, in: view)
            .contains { $0.type == .indirect && !$0.isResting }
        capture.cancelTouches(contactsRemain: contactsRemain)
        if !contactsRemain { identities.removeAll() }
        if interruptedStroke {
            cancelPendingRecognition()
            scheduleRecognition()
        }
        refresh()
    }

    func beginMouse(at point: InkPoint) {
        let before = document.revision
        capture.beginMouse(at: point)
        guard before != document.revision else { return }
        cancelPendingRecognition()
        refresh()
    }

    func moveMouse(to point: InkPoint) { capture.moveMouse(to: point); refresh() }
    func endMouse(at point: InkPoint) { capture.endMouse(at: point); scheduleRecognition(); refresh() }

    private func refresh() {
        panels.forEach { ($0.contentView as? CaptureView)?.refresh() }
    }
}
