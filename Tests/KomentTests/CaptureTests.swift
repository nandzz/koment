@testable import Koment
import Foundation
import Testing

@Suite("Capture")
struct CaptureTests {
    private func capture(_ text: String, method: String = "ax-selected-text") -> Capture {
        Capture(selectedText: text, appName: "Xcode", method: method)
    }

    @Test("a selection of one line is one line")
    func singleLine() {
        #expect(capture(".padding(16)").lines == [".padding(16)"])
    }

    @Test("a selection keeps its blank lines in the middle")
    func innerBlankLines() {
        #expect(capture("a\n\nb").lines == ["a", "", "b"])
    }

    @Test("the blank line an editor adds at the end is dropped")
    func trailingNewline() {
        #expect(capture("a\nb\n").lines == ["a", "b"])
        #expect(capture("a\nb\n\n   \n").lines == ["a", "b"])
    }

    @Test("a selection of nothing has no lines")
    func empty() {
        #expect(capture("").lines.isEmpty)
        #expect(capture("\n  \n").lines.isEmpty)
    }

    @Test("the needle is the first line with something to search for")
    func needle() {
        #expect(capture("    .padding(16)\n    .frame()").needle == ".padding(16)")
    }

    @Test("the needle skips lines too short to find anything")
    func needleSkipsShortLines() {
        #expect(capture("}\n  {\n    let value = 3").needle == "let value = 3")
    }

    @Test("a selection with nothing worth searching for has no needle")
    func noNeedle() {
        #expect(capture("}\n{\n").needle.isEmpty)
        #expect(capture("").needle.isEmpty)
    }

    @Test("a note about a window says so")
    func windowNote() {
        #expect(capture("", method: "window").isWindowNote)
        #expect(!capture("x", method: "ax-selected-text").isWindowNote)
        #expect(!capture("x", method: "clipboard").isWindowNote)
    }

    @Test("a capture starts with nothing known about the window")
    func defaults() {
        let capture = capture("x")
        #expect(capture.documentPath == .none)
        #expect(capture.windowTitle == .none)
        #expect(capture.bundleIdentifier == .none)
        #expect(capture.sourceURL == .none)
        #expect(capture.axLine == .none)
        #expect(capture.contextBefore.isEmpty)
        #expect(capture.contextAfter.isEmpty)
    }
}

@Suite("Location")
struct LocationTests {
    private func location(line: Int, endLine: Int) -> Location {
        Location(
            repoRoot: "/Users/you/Workspace/app",
            relativePath: "Sources/Foo/Bar.swift",
            absolutePath: "/Users/you/Workspace/app/Sources/Foo/Bar.swift",
            line: line,
            endLine: endLine,
            confidence: "ax-exact"
        )
    }

    @Test("one line reads as one number and a range reads as a range")
    func lineSpan() {
        #expect(location(line: 42, endLine: 42).lineSpan == "42")
        #expect(location(line: 42, endLine: 44).lineSpan == "42-44")
    }

    @Test("the file name is the last part of the absolute path")
    func fileName() {
        #expect(location(line: 1, endLine: 1).fileName == "Bar.swift")
    }

    @Test("two locations of the same lines in the same file are the same location")
    func equality() {
        #expect(location(line: 1, endLine: 2) == location(line: 1, endLine: 2))
        #expect(location(line: 1, endLine: 2) != location(line: 1, endLine: 3))
    }
}
