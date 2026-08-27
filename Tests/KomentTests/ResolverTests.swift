@testable import Koment
import KomentCore
import Foundation
import Testing

@Suite("Resolver")
struct ResolverTests {
    let space: Workspace
    let resolver: Resolver

    init() {
        space = Workspace()
        resolver = Resolver(shell: Shell(), roots: [space.root])
    }

    private func capture(
        _ selectedText: String,
        documentPath: String? = .none,
        windowTitle: String? = .none,
        axLine: Int? = .none
    ) -> Capture {
        Capture(
            selectedText: selectedText,
            appName: "Xcode",
            documentPath: documentPath,
            windowTitle: windowTitle,
            axLine: axLine,
            method: "ax-selected-text"
        )
    }

    @Test("a window title that is only a file name gives the file name")
    func fileNamePlain() {
        #expect(resolver.fileName(from: "Bar.swift") == "Bar.swift")
    }

    @Test("a window title with the project after a dash gives the file name")
    func fileNameWithProject() {
        #expect(resolver.fileName(from: "Bar.swift — MyApp") == "Bar.swift")
        #expect(resolver.fileName(from: "Bar.swift - MyApp") == "Bar.swift")
        #expect(resolver.fileName(from: "Bar.swift | MyApp") == "Bar.swift")
    }

    @Test("the dot an editor puts before an unsaved file is dropped")
    func fileNameWithEditedMark() {
        #expect(resolver.fileName(from: "● Bar.swift") == "Bar.swift")
        #expect(resolver.fileName(from: "• Bar.swift — MyApp") == "Bar.swift")
    }

    @Test("a chat window names no file")
    func fileNameFromChat() {
        let title = "Federica Giordano (DM) - Tripadvisor - 7 new items - Slack"
        #expect(resolver.fileName(from: title) == .none)
    }

    @Test("a title holding a path is not a file name")
    func fileNameWithPath() {
        #expect(resolver.fileName(from: "/Users/you/Bar.swift") == .none)
    }

    @Test("a title holding a space inside the name is not taken as a file name")
    func fileNameWithSpace() {
        #expect(resolver.fileName(from: "My Notes.txt — Notes") == .none)
    }

    @Test("no title names no file")
    func fileNameFromNothing() {
        #expect(resolver.fileName(from: .none) == .none)
        #expect(resolver.fileName(from: "") == .none)
    }

    @Test("the first line holding the selection is found")
    func firstLine() {
        let path = space.file("proj/Sources/Bar.swift", "alpha\nbeta\ngamma\nbeta again")
        #expect(resolver.firstLine(matching: "beta", inFile: path) == 2)
        #expect(resolver.firstLine(matching: "gamma", inFile: path) == 3)
    }

    @Test("a selection that is not in the file is not found")
    func firstLineMissing() {
        let path = space.file("proj/Sources/Bar.swift", "alpha\nbeta")
        #expect(resolver.firstLine(matching: "omega", inFile: path) == .none)
    }

    @Test("an empty selection matches nothing rather than the first line")
    func firstLineEmptyNeedle() {
        let path = space.file("proj/Sources/Bar.swift", "alpha\nbeta")
        #expect(resolver.firstLine(matching: "", inFile: path) == .none)
    }

    @Test("a file that is not there matches nothing")
    func firstLineMissingFile() {
        #expect(resolver.firstLine(matching: "alpha", inFile: space.root + "/gone.swift") == .none)
    }

    @Test("a path inside the project is stored relative to it")
    func relativePath() {
        #expect(resolver.relativePath(of: "/a/b/Sources/C.swift", root: "/a/b")
            == "Sources/C.swift")
    }

    @Test("a path outside the project is stored as it stands")
    func relativePathOutside() {
        #expect(resolver.relativePath(of: "/x/C.swift", root: "/a/b") == "/x/C.swift")
    }

    @Test("the project root itself is relative to nothing")
    func relativePathOfRoot() {
        #expect(resolver.relativePath(of: "/a/b", root: "/a/b").isEmpty)
    }

    @Test("a document path and a line from the editor need no search at all")
    func resolvesExactly() throws {
        let path = space.file("proj/Sources/Bar.swift", "one\ntwo\nthree\nfour\nfive")
        let taken = capture("three", documentPath: path, axLine: 3)

        let location = try #require(resolver.resolve(taken))
        #expect(location.confidence == "ax-exact")
        #expect(location.line == 3)
        #expect(location.endLine == 3)
        #expect(location.absolutePath == path)
        #expect(location.relativePath == "Sources/Bar.swift")
        #expect(location.repoRoot == space.root + "/proj")
    }

    @Test("a selection of three lines spans three lines")
    func resolvesSpan() throws {
        let path = space.file("proj/Sources/Bar.swift", "one\ntwo\nthree\nfour\nfive")
        let taken = capture("two\nthree\nfour", documentPath: path, axLine: 2)

        let location = try #require(resolver.resolve(taken))
        #expect(location.line == 2)
        #expect(location.endLine == 4)
    }

    @Test("a document path with no line is searched for the selected text")
    func resolvesBySearch() throws {
        let path = space.file("proj/Sources/Bar.swift", "one\ntwo\n    .padding(16)\nfour")
        let taken = capture("    .padding(16)", documentPath: path)

        let location = try #require(resolver.resolve(taken))
        #expect(location.confidence == "document-search")
        #expect(location.line == 3)
    }

    @Test("a file that does not hold the selection anchors to the file alone")
    func resolvesToDocumentOnly() throws {
        let path = space.file("proj/Sources/Bar.swift", "one\ntwo\nthree")
        let taken = capture("something else entirely", documentPath: path)

        let location = try #require(resolver.resolve(taken))
        #expect(location.confidence == "document-only")
        #expect(location.line == 1)
        #expect(location.absolutePath == path)
    }

    @Test("nothing to go on resolves to nothing rather than a guess")
    func resolvesToNothing() {
        let taken = capture("ab", documentPath: space.root + "/gone.swift")
        #expect(resolver.resolve(taken)?.absolutePath == .none)
    }

    @Test("a folder holding a claude folder is the project a file belongs to")
    func anchorRootFromClaudeFolder() {
        space.folder("proj/.claude")
        let path = space.file("proj/Sources/Bar.swift", "one")
        #expect(resolver.anchorRoot(containing: path) == space.root + "/proj")
    }

    @Test("a nested claude folder wins over the one further up")
    func anchorRootTakesTheNearest() {
        space.folder(".claude")
        space.folder("proj/inner/.claude")
        let path = space.file("proj/inner/Sources/Bar.swift", "one")
        #expect(resolver.anchorRoot(containing: path) == space.root + "/proj/inner")
    }

    @Test("a file with no claude folder anchors to the first folder under the root")
    func anchorRootFromRoot() {
        let path = space.file("proj/Sources/deep/Bar.swift", "one")
        #expect(resolver.anchorRoot(containing: path) == space.root + "/proj")
    }

    @Test("a file outside every configured root anchors to nothing")
    func anchorRootOutside() {
        let other = Resolver(shell: Shell(), roots: ["/nowhere/at/all"])
        let path = space.file("proj/Sources/Bar.swift", "one")
        #expect(other.anchorRoot(containing: path) == .none)
    }

    @Test("the anchor keeps the three lines either side of the selection")
    func anchorContext() {
        let body = (1...10).map { "line \($0)" }.joined(separator: "\n")
        let path = space.file("proj/Sources/Bar.swift", body)
        let location = Location(
            repoRoot: space.root + "/proj",
            relativePath: "Sources/Bar.swift",
            absolutePath: path,
            line: 5,
            endLine: 6,
            confidence: "ax-exact"
        )

        let anchor = resolver.anchor(for: capture("line 5\nline 6"), at: location)
        #expect(anchor.before == ["line 2", "line 3", "line 4"])
        #expect(anchor.after == ["line 7", "line 8", "line 9"])
        #expect(anchor.selectedText == "line 5\nline 6")
        #expect(anchor.confidence == "ax-exact")
    }

    @Test("a selection at the top of a file has no lines before it")
    func anchorAtTop() {
        let path = space.file("proj/Sources/Bar.swift", "line 1\nline 2\nline 3")
        let location = Location(
            repoRoot: space.root + "/proj",
            relativePath: "Sources/Bar.swift",
            absolutePath: path,
            line: 1,
            endLine: 1,
            confidence: "ax-exact"
        )

        let anchor = resolver.anchor(for: capture("line 1"), at: location)
        #expect(anchor.before.isEmpty)
        #expect(anchor.after == ["line 2", "line 3"])
    }

    @Test("a selection at the end of a file has no lines after it")
    func anchorAtEnd() {
        let path = space.file("proj/Sources/Bar.swift", "line 1\nline 2\nline 3")
        let location = Location(
            repoRoot: space.root + "/proj",
            relativePath: "Sources/Bar.swift",
            absolutePath: path,
            line: 3,
            endLine: 3,
            confidence: "ax-exact"
        )

        let anchor = resolver.anchor(for: capture("line 3"), at: location)
        #expect(anchor.before == ["line 1", "line 2"])
        #expect(anchor.after.isEmpty)
    }

    @Test("a file that is not there has no hash")
    func anchorWithoutBlob() {
        let location = Location(
            repoRoot: space.root,
            relativePath: "gone.swift",
            absolutePath: space.root + "/gone.swift",
            line: 1,
            endLine: 1,
            confidence: "title-search"
        )
        #expect(resolver.anchor(for: capture("x"), at: location).blob == .none)
    }

    @Test("a file the app cannot read keeps the context the capture carried")
    func anchorFallsBackToCapture() {
        let location = Location(
            repoRoot: space.root,
            relativePath: "gone.swift",
            absolutePath: space.root + "/gone.swift",
            line: 5,
            endLine: 5,
            confidence: "title-search"
        )
        var taken = capture("x")
        taken.contextBefore = ["before"]
        taken.contextAfter = ["after"]

        let anchor = resolver.anchor(for: taken, at: location)
        #expect(anchor.before == ["before"])
        #expect(anchor.after == ["after"])
    }

    @Test("the anchor holds the hash of the file, whether or not it is in a repository")
    func anchorBlob() {
        let path = space.file("proj/Sources/Bar.swift", "line 1")
        let location = Location(
            repoRoot: space.root + "/proj",
            relativePath: "Sources/Bar.swift",
            absolutePath: path,
            line: 1,
            endLine: 1,
            confidence: "ax-exact"
        )
        let blob = resolver.anchor(for: capture("line 1"), at: location).blob
        #expect(blob?.count == 40)
        #expect(blob?.allSatisfy { $0.isHexDigit } == true)
    }
}
