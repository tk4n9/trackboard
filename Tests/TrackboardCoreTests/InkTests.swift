import XCTest
@testable import TrackboardCore

final class InkTests: XCTestCase {
    func testStrokeLiftsDoNotJoinLetters() {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.1, y: 0.1))
        ink.end(at: InkPoint(x: 0.2, y: 0.7))
        ink.begin(at: InkPoint(x: 0.8, y: 0.2))
        ink.end(at: InkPoint(x: 0.9, y: 0.8))
        XCTAssertEqual(ink.strokes.count, 2)
        XCTAssertEqual(ink.strokes[0].points.count, 2)
        XCTAssertEqual(ink.strokes[1].points.first, InkPoint(x: 0.8, y: 0.2))
        XCTAssertNil(ink.activeStroke)
    }

    func testRepeatedStationarySamplesDoNotGrowStroke() {
        var ink = InkDocument()
        let point = InkPoint(x: 0.4, y: 0.4)
        ink.begin(at: point)
        let revision = ink.revision
        for _ in 0..<1_000 { ink.append(point) }
        XCTAssertEqual(ink.activeStroke?.points.count, 1)
        XCTAssertEqual(ink.revision, revision)
        ink.end()
        XCTAssertEqual(ink.strokes[0].points, [point]) // dots are meaningful ink
    }

    func testCancelledContactDoesNotDeletePreviousLetters() {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.2, y: 0.2))
        ink.end()
        ink.begin(at: InkPoint(x: 0.8, y: 0.8))
        ink.cancelStroke()
        XCTAssertEqual(ink.strokes.count, 1)
        XCTAssertNil(ink.activeStroke)
        XCTAssertEqual(ink.bounds?.maxX, 0.2)
    }

    func testUndoAndClearInvalidateRevision() {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.2, y: 0.2)); ink.end()
        let previous = ink.revision
        ink.undo()
        XCTAssertTrue(ink.isEmpty)
        XCTAssertGreaterThan(ink.revision, previous)
        ink.begin(at: InkPoint(x: 0.8, y: 0.8))
        ink.undo()
        XCTAssertTrue(ink.isEmpty)
        let beforeClear = ink.revision
        ink.clear()
        XCTAssertGreaterThan(ink.revision, beforeClear)
        XCTAssertNil(ink.bounds)
    }

    func testCoordinatesAreBoundedAndFinite() {
        XCTAssertEqual(InkPoint(x: -3, y: 10), InkPoint(x: 0, y: 1))
        XCTAssertEqual(InkPoint(x: .nan, y: .infinity), InkPoint(x: 0, y: 0))
    }

    func testNewContactCannotConnectInterruptedInk() {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.1, y: 0.1))
        ink.begin(at: InkPoint(x: 0.9, y: 0.9))
        ink.end()
        XCTAssertEqual(ink.strokes.count, 1)
        XCTAssertEqual(ink.strokes[0].points, [InkPoint(x: 0.9, y: 0.9)])
    }

    func testMultitouchRequiresAllFingersToLift() {
        var tracker = ContactTracker()
        XCTAssertEqual(tracker.update(activeIDs: [1]), 1)
        XCTAssertNil(tracker.update(activeIDs: [1, 2]))
        XCTAssertTrue(tracker.waitingForLift)
        XCTAssertNil(tracker.update(activeIDs: [2]))
        XCTAssertNil(tracker.update(activeIDs: []))
        XCTAssertFalse(tracker.waitingForLift)
        XCTAssertEqual(tracker.update(activeIDs: [3]), 3)
    }

    func testUnexpectedIdentityChangeRequiresLift() {
        var tracker = ContactTracker()
        XCTAssertEqual(tracker.update(activeIDs: [7]), 7)
        XCTAssertNil(tracker.update(activeIDs: [8]))
        XCTAssertTrue(tracker.waitingForLift)
        tracker.reset()
        XCTAssertEqual(tracker.update(activeIDs: [9]), 9)
    }
}
