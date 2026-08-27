import KomentCore
import Foundation
import Testing

@Suite("Model")
struct ModelTests {
    @Test("a status keeps the spelling the database column holds")
    func statusRawValues() {
        #expect(CommentStatus.open.rawValue == "open")
        #expect(CommentStatus.resolved.rawValue == "resolved")
        #expect(CommentStatus.drifted.rawValue == "drifted")
        #expect(CommentStatus(rawValue: "nonsense") == .none)
    }

    @Test("only an open comment is open")
    func isOpen() {
        #expect(sample(status: .open).isOpen)
        #expect(!sample(status: .resolved).isOpen)
        #expect(!sample(status: .drifted).isOpen)
    }

    @Test("a line span reads as one number when it is one line")
    func lineSpanSingle() {
        #expect(sample(line: 42, endLine: 42).lineSpan == "42")
    }

    @Test("a line span reads as a range when it covers more than one line")
    func lineSpanRange() {
        #expect(sample(line: 42, endLine: 44).lineSpan == "42-44")
    }

    @Test("a comment with no line has no span")
    func lineSpanUnanchored() {
        #expect(sample(line: 0, endLine: 0).lineSpan.isEmpty)
    }

    @Test("the display path is the absolute path when there is one")
    func displayPathFromPath() {
        #expect(sample(path: "/a/b/C.swift").displayPath == "/a/b/C.swift")
    }

    @Test("the display path is built from the project root when the path is empty")
    func displayPathFromRoot() {
        let comment = sample(projectRoot: "/a/b", file: "Sources/C.swift", path: "")
        #expect(comment.displayPath == "/a/b/Sources/C.swift")
    }

    @Test("the display path falls back to the relative file with no project")
    func displayPathFromFile() {
        #expect(sample(projectRoot: "", file: "C.swift", path: "").displayPath == "C.swift")
    }

    @Test("an unanchored comment has no display path at all")
    func displayPathEmpty() {
        #expect(sample(projectRoot: "", file: "", path: "").displayPath.isEmpty)
    }

    @Test("a created date is read back from the stamp")
    func createdDate() throws {
        let date = try #require(sample(createdAt: "2026-08-25T13:40:12Z").createdDate)
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 25
        components.hour = 13
        components.minute = 40
        components.second = 12
        components.timeZone = TimeZone(identifier: "UTC")
        let expected = try #require(Calendar(identifier: .gregorian).date(from: components))
        #expect(date == expected)
    }

    @Test("a stamp that is not a date reads as no date")
    func createdDateInvalid() {
        #expect(sample(createdAt: "last tuesday").createdDate == .none)
    }

    @Test("a comment survives an encode and a decode")
    func codableRoundTrip() throws {
        let original = sample(resolvedAt: "2026-08-26T09:00:00Z", resolution: "applied")
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(InlineComment.self, from: data)

        #expect(restored.id == original.id)
        #expect(restored.status == original.status)
        #expect(restored.note == original.note)
        #expect(restored.line == original.line)
        #expect(restored.endLine == original.endLine)
        #expect(restored.anchor.selectedText == original.anchor.selectedText)
        #expect(restored.anchor.before == original.anchor.before)
        #expect(restored.anchor.after == original.anchor.after)
        #expect(restored.anchor.blob == original.anchor.blob)
        #expect(restored.anchor.confidence == original.anchor.confidence)
        #expect(restored.windowTitle == original.windowTitle)
        #expect(restored.bundleIdentifier == original.bundleIdentifier)
        #expect(restored.sourceURL == original.sourceURL)
        #expect(restored.resolvedAt == original.resolvedAt)
        #expect(restored.resolution == original.resolution)
    }

    @Test("an anchor with no blob encodes without one")
    func codableWithoutBlob() throws {
        let data = try JSONEncoder().encode(sample(blob: .none))
        let restored = try JSONDecoder().decode(InlineComment.self, from: data)
        #expect(restored.anchor.blob == .none)
    }
}
