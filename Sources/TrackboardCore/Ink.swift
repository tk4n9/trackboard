import Foundation

/// Bottom-left-origin coordinates in trackpad space, independent of screen size.
public struct InkPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x.isFinite ? min(1, max(0, x)) : 0
        self.y = y.isFinite ? min(1, max(0, y)) : 0
    }
}

public struct InkStroke: Equatable, Sendable {
    public var points: [InkPoint]
    public init(points: [InkPoint]) { self.points = points }
}

public struct InkBounds: Equatable, Sendable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
}

public struct InkDocument: Equatable, Sendable {
    public private(set) var strokes: [InkStroke] = []
    public private(set) var activeStroke: InkStroke?
    public private(set) var revision: UInt64 = 0
    public var aspectRatio: Double = 1.6

    public init() {}
    public var isEmpty: Bool { strokes.isEmpty && activeStroke == nil }
    public var allStrokes: [InkStroke] { strokes + (activeStroke.map { [$0] } ?? []) }

    public mutating func begin(at point: InkPoint) {
        // An interrupted contact must never connect two unrelated strokes.
        cancelStroke()
        activeStroke = InkStroke(points: [point])
        revision &+= 1
    }

    public mutating func append(_ point: InkPoint) {
        guard let previous = activeStroke?.points.last, previous != point else { return }
        activeStroke?.points.append(point)
        revision &+= 1
    }

    public mutating func end(at point: InkPoint? = nil) {
        if let point { append(point) }
        guard let stroke = activeStroke else { return }
        strokes.append(stroke)
        activeStroke = nil
        revision &+= 1
    }

    public mutating func cancelStroke() {
        guard activeStroke != nil else { return }
        activeStroke = nil
        revision &+= 1
    }

    public mutating func undo() {
        if activeStroke != nil { cancelStroke() }
        else if !strokes.isEmpty { strokes.removeLast(); revision &+= 1 }
    }

    public mutating func clear() {
        strokes.removeAll()
        activeStroke = nil
        revision &+= 1
    }

    public var bounds: InkBounds? {
        let points = allStrokes.flatMap(\.points)
        guard let first = points.first else { return nil }
        return InkBounds(
            minX: points.reduce(first.x) { min($0, $1.x) },
            minY: points.reduce(first.y) { min($0, $1.y) },
            maxX: points.reduce(first.x) { max($0, $1.x) },
            maxY: points.reduce(first.y) { max($0, $1.y) }
        )
    }
}

/// At most one writing finger. Additional contacts cancel the unfinished stroke;
/// all fingers must lift before writing resumes. Resting contacts are filtered by UI.
public struct ContactTracker: Sendable {
    public private(set) var contact: Int?
    public private(set) var waitingForLift = false
    public init() {}

    public mutating func update(activeIDs: Set<Int>) -> Int? {
        if activeIDs.isEmpty {
            contact = nil
            waitingForLift = false
        } else if activeIDs.count > 1 {
            contact = nil
            waitingForLift = true
        } else if !waitingForLift {
            if let contact, !activeIDs.contains(contact) {
                self.contact = nil
                waitingForLift = true
            } else {
                contact = activeIDs.first
            }
        }
        return contact
    }

    public mutating func reset() { contact = nil; waitingForLift = false }

    public mutating func suppressUntilLift() { contact = nil; waitingForLift = true }
}
