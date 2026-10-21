import Foundation

/// Owns the actual stroke transitions used by the AppKit adapter. The adapter
/// supplies stable contact IDs and normalized positions, never mouse deltas.
public struct StrokeCapture: Sendable {
    public private(set) var document = InkDocument()
    public private(set) var isTouching = false
    public private(set) var isMouseDrawing = false
    public var waitingForLift: Bool { contacts.waitingForLift }
    private var contacts = ContactTracker()
    private var drawingContact: Int?

    public init() {}

    public mutating func process(
        active: [Int: InkPoint], ended: [Int: InkPoint] = [:],
        navigating: Bool = false, deviceAspectRatio: Double? = nil
    ) {
        isTouching = !active.isEmpty
        if navigating {
            cancelUnfinishedStroke()
            if active.isEmpty { contacts.reset() }
            else { contacts.suppressUntilLift() }
            return
        }

        // A trackpad can emit both mouse events and raw touch events for one
        // contact. Raw touches take ownership; a later mouseUp must not append.
        if isMouseDrawing && isTouching {
            document.cancelStroke()
            isMouseDrawing = false
        }
        if let drawingContact, let lastPoint = ended[drawingContact] {
            document.end(at: lastPoint)
            self.drawingContact = nil
        }
        let contact = contacts.update(activeIDs: Set(active.keys))
        if let previous = drawingContact, previous != contact {
            document.cancelStroke()
            drawingContact = nil
        }
        guard let contact, let point = active[contact] else { return }
        if drawingContact == nil {
            if document.isEmpty, let ratio = deviceAspectRatio, ratio.isFinite, ratio > 0 {
                document.aspectRatio = ratio
            }
            document.begin(at: point)
            drawingContact = contact
        } else { document.append(point) }
    }

    /// After an interrupted gesture, do not reuse a finger still on the pad.
    /// Only a subsequent empty active-contact set can rearm touch capture.
    public mutating func cancelTouches(contactsRemain: Bool) {
        cancelUnfinishedStroke()
        isTouching = contactsRemain
        if contactsRemain { contacts.suppressUntilLift() }
        else { contacts.reset() }
    }

    public mutating func undo() {
        document.undo()
        interruptInput()
    }

    public mutating func clear() {
        document.clear()
        interruptInput()
    }

    /// The overlay has closed, so its input event stream is no longer live.
    /// Preserve completed ink, but no contact may survive into a new overlay.
    public mutating func stop() {
        cancelUnfinishedStroke()
        isTouching = false
        contacts.reset()
    }

    public mutating func beginMouse(at point: InkPoint) {
        guard !isTouching, !waitingForLift else { return }
        document.begin(at: point)
        isMouseDrawing = true
    }

    public mutating func moveMouse(to point: InkPoint) {
        guard isMouseDrawing else { return }
        document.append(point)
    }

    public mutating func endMouse(at point: InkPoint) {
        guard isMouseDrawing else { return }
        document.end(at: point)
        isMouseDrawing = false
    }

    private mutating func interruptInput() {
        drawingContact = nil
        isMouseDrawing = false
        if isTouching { contacts.suppressUntilLift() }
        else { contacts.reset() }
    }

    private mutating func cancelUnfinishedStroke() {
        document.cancelStroke()
        drawingContact = nil
        isMouseDrawing = false
    }
}
