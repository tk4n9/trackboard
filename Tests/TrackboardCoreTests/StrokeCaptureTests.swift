import XCTest
@testable import TrackboardCore

final class StrokeCaptureTests: XCTestCase {
    private let first = InkPoint(x: 0.2, y: 0.2)
    private let middle = InkPoint(x: 0.5, y: 0.7)
    private let last = InkPoint(x: 0.8, y: 0.9)

    func testCompleteContactIncludesLiftPosition() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.process(active: [1: middle])
        capture.process(active: [:], ended: [1: last])
        XCTAssertEqual(capture.document.strokes.map(\.points), [[first, middle, last]])
        XCTAssertNil(capture.document.activeStroke)
        XCTAssertFalse(capture.isTouching)
    }

    func testOptionNavigationDoesNotRestartInkBeforeLift() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.process(active: [1: middle], navigating: true)
        capture.process(active: [1: last]) // Option released, same finger remains.
        XCTAssertTrue(capture.document.isEmpty)
        XCTAssertTrue(capture.waitingForLift)
        capture.process(active: [:], ended: [1: last])
        capture.process(active: [2: first])
        capture.process(active: [:], ended: [2: middle])
        XCTAssertEqual(capture.document.strokes.map(\.points), [[first, middle]])
    }

    func testOptionWithNoContactDoesNotSuppressNextStroke() {
        var capture = StrokeCapture()
        capture.process(active: [:], navigating: true)
        capture.process(active: [1: first])
        XCTAssertEqual(capture.document.activeStroke?.points, [first])
    }

    func testClearWhileDrawingRequiresLiftBeforeMoreInk() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.clear()
        capture.process(active: [1: middle])
        capture.process(active: [:], ended: [1: last])
        XCTAssertTrue(capture.document.isEmpty)
        capture.process(active: [2: first])
        XCTAssertEqual(capture.document.activeStroke?.points, [first])
    }

    func testUndoAnUnfinishedStrokeKeepsCompletedInkAndSuppressesTail() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.process(active: [:], ended: [1: middle])
        capture.process(active: [2: last])
        capture.undo()
        capture.process(active: [2: middle])
        capture.process(active: [:], ended: [2: first])
        XCTAssertEqual(capture.document.strokes.map(\.points), [[first, middle]])
        XCTAssertNil(capture.document.activeStroke)
    }

    func testMultitouchCancellationDoesNotResumeWithRemainingFinger() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.process(active: [1: middle, 2: last])
        capture.process(active: [2: last], ended: [1: middle])
        XCTAssertTrue(capture.document.isEmpty)
        XCTAssertTrue(capture.waitingForLift)
        capture.process(active: [:], ended: [2: last])
        capture.process(active: [3: first])
        XCTAssertEqual(capture.document.activeStroke?.points, [first])
    }

    func testCancellationWithRemainingContactSuppressesIt() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.cancelTouches(contactsRemain: true)
        capture.process(active: [1: middle])
        XCTAssertTrue(capture.document.isEmpty)
        capture.process(active: [:])
        capture.process(active: [2: last])
        XCTAssertEqual(capture.document.activeStroke?.points, [last])
    }

    func testOSCancelledSequenceDoesNotLoseNextGesture() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.cancelTouches(contactsRemain: false)
        // AppKit may end a canceled sequence without delivering touchesEnded.
        capture.process(active: [2: last])
        XCTAssertEqual(capture.document.activeStroke?.points, [last])
    }

    func testMouseEndCannotAppendAfterClear() {
        var capture = StrokeCapture()
        capture.beginMouse(at: first)
        capture.clear()
        capture.moveMouse(to: middle)
        capture.endMouse(at: last)
        XCTAssertTrue(capture.document.isEmpty)
    }

    func testRawContactReplacesDuplicateMouseStroke() {
        var capture = StrokeCapture()
        capture.beginMouse(at: last) // OS mouse event arrives before raw touch.
        capture.process(active: [1: first])
        capture.moveMouse(to: last)
        capture.process(active: [:], ended: [1: middle])
        capture.endMouse(at: last)
        XCTAssertEqual(capture.document.strokes.map(\.points), [[first, middle]])
    }

    func testAspectRatioStaysStableForAnExistingDocument() {
        var capture = StrokeCapture()
        capture.process(active: [1: first], deviceAspectRatio: 2)
        capture.process(active: [:], ended: [1: middle])
        capture.process(active: [2: last], deviceAspectRatio: 3)
        XCTAssertEqual(capture.document.aspectRatio, 2)
        capture.process(active: [:], ended: [2: last])
        capture.clear()
        capture.process(active: [3: first], deviceAspectRatio: .nan)
        XCTAssertTrue(capture.document.aspectRatio.isFinite)
    }

    func testClosingOverlayCancelsActiveInputButPreservesCompletedInk() {
        var capture = StrokeCapture()
        capture.process(active: [1: first])
        capture.process(active: [:], ended: [1: middle])
        capture.process(active: [2: last])
        capture.stop()
        capture.endMouse(at: last)
        XCTAssertEqual(capture.document.strokes.map(\.points), [[first, middle]])
        XCTAssertFalse(capture.isTouching)
        XCTAssertFalse(capture.waitingForLift)
    }
}
