import AppKit
import TrackboardCore

final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen, coordinator: InputCoordinator, showsControls: Bool) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // A nonactivating panel keeps the IMK client focused, including in a
        // full-screen app. Every display captures touches without cursor locking.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = CaptureView(frame: NSRect(origin: .zero, size: screen.frame.size),
                                  coordinator: coordinator, showsControls: showsControls)
        setAccessibilityLabel("Trackboard handwriting")
    }
}

final class CaptureView: NSView {
    private weak var coordinator: InputCoordinator?
    private let showsControls: Bool
    private let titleLabel = NSTextField(labelWithString: "Trackboard")
    private let subtitleLabel = NSTextField(labelWithString: "Write on your trackpad. Your text field stays selected.")
    private let languageLabel = NSTextField(labelWithString: "Language")
    private let languagePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let correctionButton = NSButton(checkboxWithTitle: "Spelling suggestions", target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "← → choose   Return insert   Space insert + space   Esc close")
    private var candidates: [NSButton] = []
    private let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let recognizeButton = NSButton(title: "Recognize", target: nil, action: nil)
    private let insertButton = NSButton(title: "Insert ↵", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close ⎋", target: nil, action: nil)
    private var mouseDrawing = false

    private var card: NSRect {
        let size = NSSize(width: min(780, bounds.width - 40), height: min(590, bounds.height - 60))
        return NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
    private var pad: NSRect {
        NSRect(x: card.minX + 24, y: card.minY + 177,
               width: card.width - 48, height: max(80, card.height - 312))
    }
    private var inkRect: NSRect {
        let inset = pad.insetBy(dx: 16, dy: 16)
        let aspect = coordinator?.document.aspectRatio ?? 1.6
        let width = min(inset.width, inset.height * aspect)
        let height = width / aspect
        return NSRect(x: inset.midX - width / 2, y: inset.midY - height / 2, width: width, height: height)
    }

    init(frame: NSRect, coordinator: InputCoordinator, showsControls: Bool) {
        self.coordinator = coordinator
        self.showsControls = showsControls
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        acceptsTouchEvents = true
        allowedTouchTypes = .indirect
        wantsRestingTouches = false
        setAccessibilityLabel("Handwriting surface")
        guard showsControls else { return }

        titleLabel.font = .systemFont(ofSize: 25, weight: .semibold)
        subtitleLabel.textColor = .secondaryLabelColor
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = .systemFont(ofSize: 11)
        statusLabel.font = .systemFont(ofSize: 12)
        languagePicker.target = self
        languagePicker.action = #selector(languageChanged)
        languagePicker.setAccessibilityLabel("Handwriting language")
        for code in coordinator.languages {
            let title: String
            switch code {
            case "ko-KR": title = "한국어 · Korean"
            case "en-US": title = "English"
            default: title = Locale.current.localizedString(forIdentifier: code) ?? code
            }
            languagePicker.addItem(withTitle: title)
            languagePicker.lastItem?.representedObject = code
        }
        correctionButton.target = self
        correctionButton.action = #selector(correctionChanged)
        for view in [titleLabel, subtitleLabel, languageLabel, languagePicker, correctionButton, statusLabel, hintLabel] {
            addSubview(view)
        }
        for index in 0..<5 {
            let button = NSButton(title: "", target: self, action: #selector(candidateClicked(_:)))
            button.tag = index
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 17)
            button.setAccessibilityLabel("Suggestion \(index + 1)")
            candidates.append(button)
            addSubview(button)
        }
        configure(undoButton, action: #selector(undo))
        configure(clearButton, action: #selector(clear))
        configure(recognizeButton, action: #selector(recognize))
        configure(insertButton, action: #selector(insert))
        configure(closeButton, action: #selector(close))
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:coordinator:showsControls:)") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func configure(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        addSubview(button)
    }

    override func layout() {
        super.layout()
        guard showsControls else { return }
        let x = card.minX + 24
        titleLabel.frame = NSRect(x: x, y: card.maxY - 54, width: 300, height: 32)
        subtitleLabel.frame = NSRect(x: x, y: card.maxY - 80, width: card.width - 48, height: 20)
        languageLabel.frame = NSRect(x: x, y: card.maxY - 116, width: 72, height: 24)
        languagePicker.frame = NSRect(x: x + 76, y: card.maxY - 117, width: 235, height: 27)
        correctionButton.frame = NSRect(x: x + 326, y: card.maxY - 114, width: 210, height: 24)
        statusLabel.frame = NSRect(x: x, y: card.minY + 139, width: card.width - 48, height: 32)
        let gap: CGFloat = 8
        let candidateWidth = (card.width - 48 - gap * 4) / 5
        for (index, button) in candidates.enumerated() {
            button.frame = NSRect(x: x + CGFloat(index) * (candidateWidth + gap),
                                  y: card.minY + 93, width: candidateWidth, height: 38)
        }
        hintLabel.frame = NSRect(x: x, y: card.minY + 66, width: card.width - 48, height: 19)
        undoButton.frame = NSRect(x: x, y: card.minY + 21, width: 76, height: 32)
        clearButton.frame = NSRect(x: x + 84, y: card.minY + 21, width: 76, height: 32)
        recognizeButton.frame = NSRect(x: x + 168, y: card.minY + 21, width: 112, height: 32)
        closeButton.frame = NSRect(x: card.maxX - 128, y: card.minY + 21, width: 104, height: 32)
        insertButton.frame = NSRect(x: card.maxX - 242, y: card.minY + 21, width: 106, height: 32)
    }

    func refresh() {
        needsDisplay = true
        guard showsControls, let coordinator else { return }
        statusLabel.stringValue = coordinator.message
        languagePicker.selectItem(at: coordinator.languages.firstIndex(of: coordinator.language) ?? -1)
        correctionButton.state = coordinator.correctSpelling ? .on : .off
        undoButton.isEnabled = !coordinator.document.isEmpty
        clearButton.isEnabled = !coordinator.document.isEmpty
        recognizeButton.isEnabled = !coordinator.document.isEmpty && !coordinator.recognition.isRecognizing
            && coordinator.document.activeStroke == nil
        insertButton.isEnabled = coordinator.recognition.selectedText != nil
            && coordinator.document.activeStroke == nil
        for (index, button) in candidates.enumerated() {
            guard coordinator.recognition.candidates.indices.contains(index) else {
                button.title = "—"
                button.isEnabled = false
                button.state = .off
                continue
            }
            button.title = coordinator.recognition.candidates[index].text.replacingOccurrences(of: "\n", with: " · ")
            button.toolTip = coordinator.recognition.candidates[index].text
            button.isEnabled = true
            button.contentTintColor = index == coordinator.recognition.selectedIndex ? .controlAccentColor : .labelColor
            button.state = index == coordinator.recognition.selectedIndex ? .on : .off
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.18).setFill()
        bounds.fill()
        guard showsControls, let coordinator else { return }
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: card, xRadius: 20, yRadius: 20).fill()
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(roundedRect: pad, xRadius: 12, yRadius: 12).fill()
        NSColor.separatorColor.setStroke()
        let frame = NSBezierPath(roundedRect: pad, xRadius: 12, yRadius: 12)
        frame.lineWidth = 1
        frame.stroke()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: pad).addClip()
        let rect = inkRect
        let grid = NSBezierPath()
        for fraction in [0.25, 0.5, 0.75] {
            let x = rect.minX + rect.width * fraction
            grid.move(to: NSPoint(x: x, y: rect.minY))
            grid.line(to: NSPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * fraction
            grid.move(to: NSPoint(x: rect.minX, y: y))
            grid.line(to: NSPoint(x: rect.maxX, y: y))
        }
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        grid.lineWidth = 0.5
        grid.stroke()
        for stroke in coordinator.document.allStrokes {
            let points = stroke.points.map {
                NSPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
            }
            guard let first = points.first else { continue }
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()
            if points.count == 1 {
                NSBezierPath(ovalIn: NSRect(x: first.x - 1.5, y: first.y - 1.5, width: 3, height: 3)).fill()
            } else {
                let path = NSBezierPath()
                path.lineWidth = 3
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: first)
                for point in points.dropFirst() { path.line(to: point) }
                path.stroke()
            }
        }
        if coordinator.document.isEmpty {
            let text = "Write here using your whole trackpad\nNo need to press down"
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            (text as NSString).draw(in: NSRect(x: pad.minX + 20, y: pad.midY - 25,
                                             width: pad.width - 40, height: 55),
                                   withAttributes: [.font: NSFont.systemFont(ofSize: 18),
                                                    .foregroundColor: NSColor.tertiaryLabelColor,
                                                    .paragraphStyle: style])
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    override func touchesBegan(with event: NSEvent) { coordinator?.processTouches(event, in: self) }
    override func touchesMoved(with event: NSEvent) { coordinator?.processTouches(event, in: self) }
    override func touchesEnded(with event: NSEvent) { coordinator?.processTouches(event, in: self) }
    override func touchesCancelled(with event: NSEvent) { coordinator?.cancelContact(event, in: self) }

    private func point(for event: NSEvent) -> InkPoint {
        let location = convert(event.locationInWindow, from: nil)
        return InkPoint(x: (location.x - inkRect.minX) / inkRect.width,
                        y: (location.y - inkRect.minY) / inkRect.height)
    }

    override func mouseDown(with event: NSEvent) {
        guard showsControls, coordinator?.isTouching == false,
              !event.modifierFlags.contains(.option),
              inkRect.contains(convert(event.locationInWindow, from: nil)) else { return }
        mouseDrawing = true
        coordinator?.beginMouse(at: point(for: event))
    }
    override func mouseDragged(with event: NSEvent) {
        guard mouseDrawing, coordinator?.isTouching == false else { return }
        coordinator?.moveMouse(to: point(for: event))
    }
    override func mouseUp(with event: NSEvent) {
        guard mouseDrawing else { return }
        mouseDrawing = false
        if coordinator?.isTouching == false { coordinator?.endMouse(at: point(for: event)) }
    }

    @objc private func languageChanged() {
        if let code = languagePicker.selectedItem?.representedObject as? String { coordinator?.setLanguage(code) }
    }
    @objc private func correctionChanged() { coordinator?.setCorrection(correctionButton.state == .on) }
    @objc private func candidateClicked(_ sender: NSButton) { coordinator?.selectCandidate(sender.tag) }
    @objc private func undo() { coordinator?.undo() }
    @objc private func clear() { coordinator?.clear() }
    @objc private func recognize() { coordinator?.recognizeNow() }
    @objc private func insert() { coordinator?.insert() }
    @objc private func close() { coordinator?.hide() }
}
