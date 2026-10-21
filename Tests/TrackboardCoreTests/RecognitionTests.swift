import XCTest
@testable import TrackboardCore

final class RecognitionTests: XCTestCase {
    func testOldRecognitionCannotReplaceNewInkResults() {
        var state = RecognitionState()
        let old = state.begin()
        let current = state.begin()
        XCTAssertFalse(state.complete([TextCandidate(text: "old", confidence: 1)], token: old))
        XCTAssertTrue(state.isRecognizing)
        XCTAssertTrue(state.complete([TextCandidate(text: "new", confidence: 1)], token: current))
        XCTAssertEqual(state.selectedText, "new")
    }

    func testLeavingFieldInvalidatesPendingAndFinishedCandidates() {
        var state = RecognitionState()
        let token = state.begin()
        state.invalidate() // field changed while recognition was running
        XCTAssertFalse(state.complete([TextCandidate(text: "wrong field", confidence: 1)], token: token))
        XCTAssertNil(state.selectedText)
        let next = state.begin()
        state.complete([TextCandidate(text: "hello", confidence: 1)], token: next)
        state.invalidate() // field changed after suggestions arrived
        XCTAssertNil(state.selectedText)
        XCTAssertTrue(state.candidates.isEmpty)
    }

    func testSelectionWrapsAndInvalidIndicesAreIgnored() {
        var state = RecognitionState()
        let token = state.begin()
        state.complete(["one", "two", "three"].map { TextCandidate(text: $0, confidence: 1) }, token: token)
        state.moveSelection(-1)
        XCTAssertEqual(state.selectedText, "three")
        state.moveSelection(1)
        XCTAssertEqual(state.selectedText, "one")
        state.select(99)
        XCTAssertEqual(state.selectedText, "one")
        _ = state.begin()
        XCTAssertNil(state.selectedText)
    }

    func testDuplicateCallbackCannotOverwriteChosenCandidate() {
        var state = RecognitionState()
        let token = state.begin()
        XCTAssertTrue(state.complete([TextCandidate(text: "chosen", confidence: 1)], token: token))
        XCTAssertFalse(state.complete([TextCandidate(text: "duplicate", confidence: 1)], token: token))
        XCTAssertEqual(state.selectedText, "chosen")
    }

    func testKoreanIsNormalizedWithoutSplittingSyllables() {
        let candidate = TextCandidate(text: "\u{1112}\u{1161}\u{11AB}글", confidence: 0.9)
        XCTAssertEqual(candidate.text, "한글")
        XCTAssertEqual(candidate.text.count, 2)
    }

    func testObservationsAreReadTopToBottomAndLeftToRight() {
        let observations = [
            line("world", x: 0.5, y: 0.8),
            line("second line", x: 0.1, y: 0.3),
            line("hello", x: 0.1, y: 0.82)
        ]
        XCTAssertEqual(CandidateAssembler.assemble(observations).first?.text, "hello world\nsecond line")
    }

    func testAlternativesAreRankedWithoutDuplicatingTopCandidate() {
        let first = RecognizedLine(minX: 0, midY: 0.5, height: 0.2, candidates: [
            TextCandidate(text: "hello", confidence: 0.9),
            TextCandidate(text: "hallo", confidence: 0.7),
            TextCandidate(text: "hello", confidence: 0.6)
        ])
        let second = line("world", x: 0.5, y: 0.5)
        let result = CandidateAssembler.assemble([first, second])
        XCTAssertEqual(result.map(\.text), ["hello world", "hallo world"])
        XCTAssertGreaterThan(result[0].confidence, result[1].confidence)
    }

    func testNoDetectionsDoNotCreateAnEmptySuggestion() {
        XCTAssertTrue(CandidateAssembler.assemble([]).isEmpty)
        let empty = RecognizedLine(minX: 0, midY: 0, height: 0, candidates: [])
        XCTAssertTrue(CandidateAssembler.assemble([empty]).isEmpty)
        XCTAssertTrue(CandidateAssembler.assemble([line("text", x: 0, y: 0)], limit: 0).isEmpty)
    }

    private func line(_ text: String, x: Double, y: Double) -> RecognizedLine {
        RecognizedLine(minX: x, midY: y, height: 0.15, candidates: [TextCandidate(text: text, confidence: 0.9)])
    }
}
