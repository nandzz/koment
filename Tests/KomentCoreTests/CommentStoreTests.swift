import KomentCore
import Foundation
import Testing

@Suite("CommentStore")
struct CommentStoreTests {
    let space: Workspace
    let database: Database
    let store: CommentStore

    init() throws {
        space = Workspace()
        database = try Database(url: space.databaseURL)
        store = CommentStore(database: database)
    }

    @Test("a comment comes back with every field it went in with")
    func insertRoundTrip() throws {
        let original = sample(
            id: "9C1F",
            resolvedAt: "2026-08-26T09:00:00Z",
            resolution: "used the token"
        )
        try store.insert(original)

        let stored = try #require(try store.comment(id: "9C1F"))
        #expect(stored.id == original.id)
        #expect(stored.createdAt == original.createdAt)
        #expect(stored.status == original.status)
        #expect(stored.note == original.note)
        #expect(stored.projectRoot == original.projectRoot)
        #expect(stored.file == original.file)
        #expect(stored.path == original.path)
        #expect(stored.line == original.line)
        #expect(stored.endLine == original.endLine)
        #expect(stored.anchor.selectedText == original.anchor.selectedText)
        #expect(stored.anchor.before == original.anchor.before)
        #expect(stored.anchor.after == original.anchor.after)
        #expect(stored.anchor.blob == original.anchor.blob)
        #expect(stored.anchor.confidence == original.anchor.confidence)
        #expect(stored.capturedIn == original.capturedIn)
        #expect(stored.method == original.method)
        #expect(stored.windowTitle == original.windowTitle)
        #expect(stored.bundleIdentifier == original.bundleIdentifier)
        #expect(stored.sourceURL == original.sourceURL)
        #expect(stored.resolvedAt == original.resolvedAt)
        #expect(stored.resolution == original.resolution)
    }

    @Test("an anchor with no blob stays without one")
    func insertWithoutBlob() throws {
        try store.insert(sample(id: "a", blob: .none))
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.anchor.blob == .none)
    }

    @Test("an unanchored comment is a row with an empty project")
    func insertUnanchored() throws {
        try store.insert(
            sample(
                id: "a",
                projectRoot: "",
                file: "",
                path: "",
                line: 0,
                endLine: 0,
                windowTitle: "#checkout (TheFork) - Slack",
                bundleIdentifier: "com.tinyspeck.slackmacgap"
            )
        )
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.projectRoot.isEmpty)
        #expect(stored.displayPath.isEmpty)
        #expect(stored.windowTitle == "#checkout (TheFork) - Slack")
    }

    @Test("context lines with quotes and newlines survive the round trip")
    func insertAwkwardText() throws {
        let before = ["let text = \"a \\\"quoted\\\" thing\"", "", "  // ⏎ ·"]
        try store.insert(
            sample(
                id: "a",
                note: "don't \"guess\"\nask instead",
                selectedText: "line one\nline two",
                before: before,
                after: []
            )
        )
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.note == "don't \"guess\"\nask instead")
        #expect(stored.anchor.selectedText == "line one\nline two")
        #expect(stored.anchor.before == before)
        #expect(stored.anchor.after == [])
    }

    @Test("a note that looks like SQL is stored as text")
    func insertInjection() throws {
        let note = "'; DROP TABLE comment; --"
        try store.insert(sample(id: "a", note: note))
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.note == note)
    }

    @Test("inserting the same id twice replaces the row instead of adding one")
    func insertReplaces() throws {
        try store.insert(sample(id: "a", note: "first"))
        try store.insert(sample(id: "a", note: "second"))
        let all = try store.comments()
        #expect(all.count == 1)
        #expect(all[0].note == "second")
    }

    @Test("an id nobody wrote returns nothing")
    func missingComment() throws {
        #expect(try store.comment(id: "nope")?.id == .none)
    }

    @Test("no status asked for means every status returned")
    func everyStatus() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .resolved))
        try store.insert(sample(id: "c", status: .drifted))
        #expect(try store.comments().count == 3)
    }

    @Test("the open tab asks for the outstanding work and gets it")
    func openAndDrifted() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .resolved))
        try store.insert(sample(id: "c", status: .drifted))
        let outstanding = try store.comments(in: [.open, .drifted]).map(\.id)
        #expect(Set(outstanding) == ["a", "c"])
    }

    @Test("a project filter keeps only that project")
    func projectFilter() throws {
        try store.insert(sample(id: "a", projectRoot: "/one"))
        try store.insert(sample(id: "b", projectRoot: "/two"))
        #expect(try store.comments(project: "/one").map(\.id) == ["a"])
    }

    @Test("an empty project filter finds the unanchored comments")
    func unanchoredFilter() throws {
        try store.insert(sample(id: "a", projectRoot: "/one"))
        try store.insert(sample(id: "b", projectRoot: ""))
        #expect(try store.comments(project: "").map(\.id) == ["b"])
    }

    @Test(
        "the search covers the note, the path, the project, the app, the window and the address",
        arguments: [
            "spacing token", "Bar.swift", "Workspace", "Xcode", "the window", "notion.so"
        ]
    )
    func searchMatches(query: String) throws {
        try store.insert(
            sample(
                id: "a",
                note: "this must use the Tasty spacing token",
                projectRoot: "/Users/you/Workspace/app",
                path: "/Users/you/Workspace/app/Sources/Foo/Bar.swift",
                capturedIn: "Xcode",
                windowTitle: "the window title",
                sourceURL: "https://notion.so/page"
            )
        )
        #expect(try store.comments(matching: query).map(\.id) == ["a"])
    }

    @Test("the search leaves out what does not match")
    func searchMisses() throws {
        try store.insert(sample(id: "a"))
        #expect(try store.comments(matching: "zzzzz").isEmpty)
    }

    @Test("no search term means no filtering")
    func emptySearch() throws {
        try store.insert(sample(id: "a"))
        #expect(try store.comments(matching: "").count == 1)
    }

    @Test("comments come back newest first")
    func newestFirst() throws {
        try store.insert(sample(id: "old", createdAt: "2026-08-01T10:00:00Z"))
        try store.insert(sample(id: "new", createdAt: "2026-08-27T10:00:00Z"))
        try store.insert(sample(id: "middle", createdAt: "2026-08-15T10:00:00Z"))
        #expect(try store.comments().map(\.id) == ["new", "middle", "old"])
    }

    @Test("a limit takes the newest ones")
    func limit() throws {
        try store.insert(sample(id: "old", createdAt: "2026-08-01T10:00:00Z"))
        try store.insert(sample(id: "new", createdAt: "2026-08-27T10:00:00Z"))
        #expect(try store.comments(limit: 1).map(\.id) == ["new"])
    }

    @Test("a status, a project and a search term all apply together")
    func combinedFilters() throws {
        try store.insert(sample(id: "a", status: .open, note: "keep me", projectRoot: "/one"))
        try store.insert(sample(id: "b", status: .open, note: "keep me", projectRoot: "/two"))
        try store.insert(sample(id: "c", status: .resolved, note: "keep me", projectRoot: "/one"))
        try store.insert(sample(id: "d", status: .open, note: "not me", projectRoot: "/one"))

        let found = try store.comments(in: [.open], project: "/one", matching: "keep me")
        #expect(found.map(\.id) == ["a"])
    }

    @Test("a status the app does not know reads as open")
    func unknownStatus() throws {
        try store.insert(sample(id: "a"))
        try database.run("UPDATE comment SET status = ? WHERE id = ?", [.text("weird"), .text("a")])
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .open)
    }

    @Test("context lines that are not JSON read as no lines")
    func brokenAnchorLines() throws {
        try store.insert(sample(id: "a"))
        try database.run(
            "UPDATE comment SET before_lines = ?, after_lines = ? WHERE id = ?",
            [.text("not json"), .text(""), .text("a")]
        )
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.anchor.before.isEmpty)
        #expect(stored.anchor.after.isEmpty)
    }

    @Test("the project list counts the open comments of each project")
    func projects() throws {
        try store.insert(sample(id: "a", status: .open, projectRoot: "/one"))
        try store.insert(sample(id: "b", status: .drifted, projectRoot: "/one"))
        try store.insert(sample(id: "c", status: .resolved, projectRoot: "/one"))
        try store.insert(sample(id: "d", status: .open, projectRoot: "/two"))
        try store.insert(sample(id: "e", status: .resolved, projectRoot: "/two"))

        let projects = try store.projects()
        #expect(projects.map(\.root) == ["/one", "/two"])
        #expect(projects.map(\.name) == ["one", "two"])
        #expect(projects.map(\.openCount) == [1, 1])
    }

    @Test("an unanchored comment shows up as a project with no root")
    func unanchoredProject() throws {
        try store.insert(sample(id: "a", projectRoot: ""))
        let projects = try store.projects()
        #expect(projects.count == 1)
        #expect(projects[0].root.isEmpty)
        #expect(projects[0].name == "unanchored")
    }

    @Test("no comments means no projects")
    func noProjects() throws {
        #expect(try store.projects().isEmpty)
    }

    @Test("deleting takes the rows named and says how many went")
    func delete() throws {
        try store.insert(sample(id: "a"))
        try store.insert(sample(id: "b"))
        try store.insert(sample(id: "c"))
        #expect(try store.delete(ids: ["a", "b"]) == 2)
        #expect(try store.comments().map(\.id) == ["c"])
    }

    @Test("deleting nothing touches nothing")
    func deleteNothing() throws {
        try store.insert(sample(id: "a"))
        #expect(try store.delete(ids: []) == 0)
        #expect(try store.comments().count == 1)
    }

    @Test("deleting an id that is not there removes nothing")
    func deleteMissing() throws {
        try store.insert(sample(id: "a"))
        #expect(try store.delete(ids: ["nope"]) == 0)
        #expect(try store.comments().count == 1)
    }

    @Test("editing a note writes the new text")
    func update() throws {
        try store.insert(sample(id: "a", note: "before"))
        #expect(try store.update(id: "a", note: "after"))
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.note == "after")
    }

    @Test("editing a comment that is gone says so")
    func updateMissing() throws {
        #expect(try store.update(id: "nope", note: "after") == false)
    }

    @Test("resolving stamps the time and records what changed")
    func resolve() throws {
        try store.insert(sample(id: "a"))
        #expect(try store.resolve(id: "a", resolution: "used the token"))

        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .resolved)
        #expect(stored.resolution == "used the token")
        let stamp = try #require(stored.resolvedAt)
        #expect(ISO8601DateFormatter().date(from: stamp) != .none)
    }

    @Test("marking drifted records the reason without pretending it was applied")
    func markDrifted() throws {
        try store.insert(sample(id: "a"))
        #expect(try store.markDrifted(id: "a", reason: "the lines are gone"))

        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .drifted)
        #expect(stored.resolution == "the lines are gone")
        #expect(stored.resolvedAt != .none)
    }

    @Test("closing a comment that is not there says so")
    func closeMissing() throws {
        #expect(try store.resolve(id: "nope", resolution: "x") == false)
        #expect(try store.markDrifted(id: "nope", reason: "x") == false)
    }

    @Test("reopening clears the closing stamp and the resolution")
    func reopen() throws {
        try store.insert(sample(id: "a"))
        _ = try store.resolve(id: "a", resolution: "used the token")
        #expect(try store.reopen(id: "a"))

        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .open)
        #expect(stored.resolvedAt == .none)
        #expect(stored.resolution == .none)
    }

    @Test("reopening a comment that is not there says so")
    func reopenMissing() throws {
        #expect(try store.reopen(id: "nope") == false)
    }

    @Test("a comment written by one connection is read by another")
    func acrossConnections() throws {
        try store.insert(sample(id: "a"))
        let other = CommentStore(database: try Database(url: space.databaseURL))
        _ = try other.resolve(id: "a", resolution: "closed by the server")

        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .resolved)
    }
}
