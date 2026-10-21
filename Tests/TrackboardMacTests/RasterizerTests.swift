import XCTest
import AppKit
import TrackboardCore
@testable import TrackboardMac

final class RasterizerTests: XCTestCase {
    func testEmptyInkIsNotSentToVision() {
        XCTAssertThrowsError(try InkRasterizer.image(from: InkDocument()))
    }

    func testDotAndHorizontalLineHaveNonzeroPaddedRaster() throws {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.5, y: 0.5)); ink.end()
        let dot = try InkRasterizer.image(from: ink)
        XCTAssertGreaterThan(dot.width, 56)
        XCTAssertGreaterThan(dot.height, 56)
        ink.begin(at: InkPoint(x: 0, y: 1))
        ink.end(at: InkPoint(x: 1, y: 1))
        let line = try InkRasterizer.image(from: ink)
        XCTAssertLessThanOrEqual(line.width, 1656)
        XCTAssertLessThanOrEqual(line.height, 568)
    }

    func testDeviceAspectRatioChangesRasterWidth() throws {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.2, y: 0.2))
        ink.end(at: InkPoint(x: 0.5, y: 0.9))
        ink.aspectRatio = 1
        let squareDevice = try InkRasterizer.image(from: ink)
        ink.aspectRatio = 2
        let wideDevice = try InkRasterizer.image(from: ink)
        XCTAssertGreaterThan(wideDevice.width, squareDevice.width)
        XCTAssertEqual(wideDevice.height, squareDevice.height)
    }

    func testTargetLanguagesExistOnRunningMac() throws {
        let languages = try TextRecognizer.supportedLanguages()
        XCTAssertTrue(languages.contains("ko-KR"), "The required Korean recognizer is missing on this Mac.")
        XCTAssertTrue(languages.contains("en-US"), "The required English recognizer is missing on this Mac.")
    }

    func testUnknownLanguageProducesActionableError() {
        var ink = InkDocument()
        ink.begin(at: InkPoint(x: 0.2, y: 0.2)); ink.end()
        XCTAssertThrowsError(try TextRecognizer.recognize(ink, language: "invalid-language", correctSpelling: false)) {
            XCTAssertTrue($0.localizedDescription.contains("invalid-language"))
        }
    }
}
