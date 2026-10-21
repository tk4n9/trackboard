import Foundation

public struct TextCandidate: Equatable, Sendable {
    public let text: String
    public let confidence: Float
    public init(text: String, confidence: Float) {
        self.text = text.precomposedStringWithCanonicalMapping
        self.confidence = confidence
    }
}

public struct RecognizedLine: Sendable {
    public let minX: Double
    public let midY: Double
    public let height: Double
    public let candidates: [TextCandidate]
    public init(minX: Double, midY: Double, height: Double, candidates: [TextCandidate]) {
        self.minX = minX; self.midY = midY; self.height = height
        self.candidates = candidates
    }
}

public enum CandidateAssembler {
    /// Group observations into lines before joining; sorting pairwise with a
    /// vertical tolerance is non-transitive and can randomly reorder handwriting.
    public static func assemble(_ observations: [RecognizedLine], limit: Int = 5) -> [TextCandidate] {
        guard limit > 0 else { return [] }
        var rows: [[RecognizedLine]] = []
        for line in observations.filter({ !$0.candidates.isEmpty }).sorted(by: { $0.midY > $1.midY }) {
            if let index = rows.firstIndex(where: { row in
                guard let anchor = row.first else { return false }
                return abs(anchor.midY - line.midY) <= min(anchor.height, line.height) * 0.5
            }) {
                rows[index].append(line)
            } else { rows.append([line]) }
        }
        let orderedRows = rows.map { $0.sorted { $0.minX < $1.minX } }
        var beam: [TextCandidate] = [TextCandidate(text: "", confidence: 1)]
        for (rowIndex, row) in orderedRows.enumerated() {
            for (columnIndex, line) in row.enumerated() {
                let separator = columnIndex > 0 ? " " : (rowIndex > 0 ? "\n" : "")
                beam = beam.flatMap { prefix in
                    line.candidates.prefix(limit).map { suffix in
                        TextCandidate(text: prefix.text + separator + suffix.text,
                                      confidence: prefix.confidence * suffix.confidence)
                    }
                }.sorted { $0.confidence > $1.confidence }
                var seen = Set<String>()
                beam = Array(beam.filter { !$0.text.isEmpty && seen.insert($0.text).inserted }.prefix(limit))
            }
        }
        return orderedRows.isEmpty ? [] : beam
    }
}

/// A session token invalidates asynchronous OCR whenever ink, language, or focus
/// changes. Candidates can only be committed from the current request.
public struct RecognitionState: Sendable {
    public private(set) var generation: UInt64 = 0
    public private(set) var candidates: [TextCandidate] = []
    public private(set) var selectedIndex = 0
    public private(set) var isRecognizing = false
    public init() {}

    @discardableResult public mutating func invalidate() -> UInt64 {
        generation &+= 1
        candidates = []
        selectedIndex = 0
        isRecognizing = false
        return generation
    }

    public mutating func begin() -> UInt64 {
        let token = invalidate()
        isRecognizing = true
        return token
    }

    @discardableResult public mutating func complete(_ values: [TextCandidate], token: UInt64) -> Bool {
        guard generation == token, isRecognizing else { return false }
        candidates = values
        selectedIndex = 0
        isRecognizing = false
        return true
    }

    public mutating func select(_ index: Int) {
        guard candidates.indices.contains(index) else { return }
        selectedIndex = index
    }

    public mutating func moveSelection(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = ((selectedIndex + delta) % candidates.count + candidates.count) % candidates.count
    }

    public var selectedText: String? {
        guard !isRecognizing, candidates.indices.contains(selectedIndex) else { return nil }
        return candidates[selectedIndex].text
    }
}
