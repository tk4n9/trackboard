import AppKit
import Vision
import TrackboardCore

public enum RecognitionError: LocalizedError {
    case emptyInk, imageCreation, unsupportedLanguage(String)
    public var errorDescription: String? {
        switch self {
        case .emptyInk: return "Write a character or a short word first."
        case .imageCreation: return "Could not prepare your handwriting. Clear the pad and try again."
        case .unsupportedLanguage(let language):
            return "This version of macOS does not provide recognition for \(language)."
        }
    }
}

public enum InkRasterizer {
    /// Rasterize only the ink, with padding and the physical trackpad aspect
    /// ratio preserved. UI labels and the pad grid never reach the recognizer.
    public static func image(from document: InkDocument) throws -> CGImage {
        guard let bounds = document.bounds else { throw RecognitionError.emptyInk }
        let aspect = document.aspectRatio.isFinite && document.aspectRatio > 0
            ? document.aspectRatio : 1.6
        let contentWidth = max(bounds.width * aspect, 0.12)
        let contentHeight = max(bounds.height, 0.15)
        let scale = min(512 / contentHeight, 1600 / contentWidth)
        let padding: Double = 28
        let width = Int(ceil(contentWidth * scale + 2 * padding))
        let height = Int(ceil(contentHeight * scale + 2 * padding))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RecognitionError.imageCreation }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(gray: 0, alpha: 1)
        context.setFillColor(gray: 0, alpha: 1)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let lineWidth = max(2.5, min(9, scale * 0.006))
        context.setLineWidth(lineWidth)
        let offsetX = padding + (contentWidth - bounds.width * aspect) * scale / 2
        let offsetY = padding + (contentHeight - bounds.height) * scale / 2
        for stroke in document.allStrokes {
            let points = stroke.points.map {
                CGPoint(x: offsetX + ($0.x - bounds.minX) * aspect * scale,
                        y: offsetY + ($0.y - bounds.minY) * scale)
            }
            guard let first = points.first else { continue }
            if points.count == 1 {
                context.fillEllipse(in: CGRect(x: first.x - lineWidth / 2,
                                               y: first.y - lineWidth / 2,
                                               width: lineWidth, height: lineWidth))
            } else {
                context.beginPath()
                context.move(to: first)
                for point in points.dropFirst() { context.addLine(to: point) }
                context.strokePath()
            }
        }
        guard let image = context.makeImage() else { throw RecognitionError.imageCreation }
        return image
    }
}

public enum TextRecognizer {
    private static func request() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        // Revision 3 is available on our macOS 13 minimum, including Korean.
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        return request
    }

    public static func supportedLanguages() throws -> [String] {
        try request().supportedRecognitionLanguages()
    }

    public static func recognize(
        _ document: InkDocument, language: String, correctSpelling: Bool
    ) throws -> [TextCandidate] {
        let request = request()
        guard try request.supportedRecognitionLanguages().contains(language) else {
            throw RecognitionError.unsupportedLanguage(language)
        }
        request.recognitionLanguages = [language]
        request.usesLanguageCorrection = correctSpelling
        request.automaticallyDetectsLanguage = false
        request.minimumTextHeight = 0.015
        let handler = VNImageRequestHandler(cgImage: try InkRasterizer.image(from: document), options: [:])
        try handler.perform([request])
        let lines = (request.results ?? []).map { observation in
            RecognizedLine(
                minX: observation.boundingBox.minX,
                midY: observation.boundingBox.midY,
                height: observation.boundingBox.height,
                candidates: observation.topCandidates(5).map {
                    TextCandidate(text: $0.string, confidence: $0.confidence)
                }
            )
        }
        return CandidateAssembler.assemble(lines)
    }
}
