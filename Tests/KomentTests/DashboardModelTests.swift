@testable import Koment
import KomentCore
import Foundation
import SwiftUI
import Testing

@Suite("CommentFilter")
struct CommentFilterTests {
    @Test("the three tabs are named for what they hold")
    func titles() {
        #expect(CommentFilter.open.title == "Open")
        #expect(CommentFilter.resolved.title == "Resolved")
        #expect(CommentFilter.all.title == "All")
    }

    @Test("the open tab holds the outstanding work, which includes the drifted comments")
    func openStatuses() {
        #expect(CommentFilter.open.statuses == [.open, .drifted])
    }

    @Test("the resolved tab holds only what Claude closed")
    func resolvedStatuses() {
        #expect(CommentFilter.resolved.statuses == [.resolved])
    }

    @Test("the all tab asks for no status, so the store returns every one")
    func allStatuses() {
        #expect(CommentFilter.all.statuses.isEmpty)
    }
}

@Suite("DashboardPrompt")
struct DashboardPromptTests {
    @Test("a message carries its title and its detail")
    func message() {
        let prompt = DashboardPrompt.message(title: "Nothing to run", detail: "why not")
        #expect(prompt.title == "Nothing to run")
        #expect(prompt.detail == "why not")
        #expect(prompt.id == "Nothing to run")
    }

    @Test("a confirmation carries its title, its detail and what it would do")
    func confirm() {
        let prompt = DashboardPrompt.confirm(
            title: "Delete this comment?",
            detail: "it cannot be undone",
            button: "Delete",
            action: .delete(["a"])
        )
        #expect(prompt.title == "Delete this comment?")
        #expect(prompt.detail == "it cannot be undone")
        #expect(prompt.id == "Delete this comment?")
    }

    @Test("two actions over the same comments are the same action")
    func actionEquality() {
        #expect(PromptAction.delete(["a", "b"]) == PromptAction.delete(["b", "a"]))
        #expect(PromptAction.delete(["a"]) != PromptAction.run(["a"]))
    }
}

@Suite("DashboardModel")
struct DashboardModelTests {
    let space: Workspace
    let database: Database
    let store: CommentStore
    let model: DashboardModel

    init() throws {
        space = Workspace()
        database = try Database(url: space.databaseURL)
        store = CommentStore(database: database)
        model = DashboardModel(store: store, theme: Theme())
        model.fallbackRoot = space.root
    }

    private func show() {
        model.isShowing = true
        model.reload()
    }

    @Test("a window that is not on screen holds no rows")
    func hiddenWindowHoldsNothing() throws {
        try store.insert(sample(id: "a"))
        model.reload()
        #expect(model.rows.isEmpty)
        #expect(model.loaded == 0)
    }

    @Test("showing the window reads the open comments")
    func showReadsOpenComments() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .drifted))
        try store.insert(sample(id: "c", status: .resolved))
        show()
        #expect(Set(model.rows.map(\.id)) == ["a", "b"])
    }

    @Test("changing the tab reads again")
    func selectFilter() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "c", status: .resolved))
        show()

        model.select(.resolved)
        #expect(model.rows.map(\.id) == ["c"])

        model.select(.all)
        #expect(model.rows.count == 2)
    }

    @Test("rows come back newest first")
    func newestFirst() throws {
        try store.insert(sample(id: "old", createdAt: "2026-08-01T10:00:00Z"))
        try store.insert(sample(id: "new", createdAt: "2026-08-27T10:00:00Z"))
        show()
        #expect(model.rows.map(\.id) == ["new", "old"])
    }

    @Test("the sort can be turned round")
    func applySort() throws {
        try store.insert(sample(id: "old", createdAt: "2026-08-01T10:00:00Z"))
        try store.insert(sample(id: "new", createdAt: "2026-08-27T10:00:00Z"))
        show()

        model.sortOrder = [KeyPathComparator(\InlineComment.createdAt, order: .forward)]
        model.applySort()
        #expect(model.rows.map(\.id) == ["old", "new"])
    }

    @Test("the filter field narrows the rows without changing what was read")
    func query() throws {
        try store.insert(sample(id: "a", note: "use the token"))
        try store.insert(sample(id: "b", note: "rename this"))
        show()

        model.query = "token"
        model.reload()
        #expect(model.rows.map(\.id) == ["a"])
        #expect(model.loaded == 2)
        #expect(model.summaryText == "1 of 2 match")
    }

    @Test("the filter field ignores capitals")
    func queryIgnoresCase() throws {
        try store.insert(sample(id: "a", note: "use the Token"))
        show()
        model.query = "TOKEN"
        model.reload()
        #expect(model.rows.map(\.id) == ["a"])
    }

    @Test("the count under the table says how many rows are shown")
    func summaryText() throws {
        show()
        #expect(model.summaryText == "0 comments")

        try store.insert(sample(id: "a"))
        model.reload()
        #expect(model.summaryText == "1 comment")

        try store.insert(sample(id: "b"))
        model.reload()
        #expect(model.summaryText == "2 comments")
    }

    @Test("an empty table says why it is empty")
    func emptyText() {
        show()
        #expect(model.emptyText.contains("No open comments"))

        model.select(.resolved)
        #expect(model.emptyText.contains("Nothing archived yet"))

        model.select(.all)
        #expect(model.emptyText == "No comments yet.")
    }

    @Test("an empty table under a filter blames the filter")
    func emptyTextWithQuery() throws {
        try store.insert(sample(id: "a"))
        show()
        model.query = "zzz"
        model.reload()
        #expect(model.emptyText == "Nothing matches “zzz”.")
    }

    @Test("a database that cannot be read says so rather than looking empty")
    func readFailure() throws {
        try store.insert(sample(id: "a"))
        show()
        try database.execute("DROP TABLE comment")
        model.reload()

        #expect(model.rows.isEmpty)
        #expect(model.emptyText.contains("could not be read"))
    }

    @Test("a selection that is no longer in the table is dropped")
    func selectionIsPruned() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .open))
        show()

        model.selection = ["a", "b"]
        _ = try store.resolve(id: "a", resolution: "done")
        model.reload()
        #expect(model.selection == ["b"])
    }

    @Test("the buttons act on every selected row")
    func selected() throws {
        try store.insert(sample(id: "a"))
        try store.insert(sample(id: "b"))
        show()

        model.selection = ["a", "b"]
        #expect(model.selected.count == 2)
        #expect(model.hasSelection)
        #expect(model.comments(for: ["a"]).map(\.id) == ["a"])
    }

    @Test("with nothing selected there is nothing to act on")
    func noSelection() {
        show()
        #expect(!model.hasSelection)
        #expect(model.selected.isEmpty)
        #expect(!model.hasFile)
    }

    @Test("the run button says how many comments it would run")
    func runTitle() throws {
        try store.insert(sample(id: "a"))
        try store.insert(sample(id: "b"))
        show()

        model.selection = ["a"]
        #expect(model.runTitle == "Run in Claude")

        model.selection = ["a", "b"]
        #expect(model.runTitle == "Run 2 in Claude")
    }

    @Test("the resolve button turns into reopen when everything selected is closed")
    func resolveTitle() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .resolved))
        show()
        model.select(.all)

        model.selection = ["a"]
        #expect(model.resolveTitle == "Resolve")

        model.selection = ["b"]
        #expect(model.resolveTitle == "Reopen")
        #expect(model.everySelectedIsResolved)

        model.selection = ["a", "b"]
        #expect(model.resolveTitle == "Resolve")
    }

    @Test("nothing selected is not the same as everything selected being closed")
    func resolveTitleWithoutSelection() {
        show()
        #expect(model.resolveTitle == "Resolve")
        #expect(!model.everySelectedIsResolved)
    }

    @Test("a comment with a file can be opened and one without cannot")
    func hasFile() throws {
        try store.insert(sample(id: "a", path: "/a/Bar.swift"))
        try store.insert(sample(id: "b", projectRoot: "", file: "", path: ""))
        show()

        model.selection = ["a"]
        #expect(model.hasFile)

        model.selection = ["b"]
        #expect(!model.hasFile)
    }

    @Test("resolving from the window closes the comment and reopening opens it again")
    func toggleResolution() throws {
        try store.insert(sample(id: "a", status: .open))
        show()
        model.selection = ["a"]

        model.toggleResolution()
        let closed = try #require(try store.comment(id: "a"))
        #expect(closed.status == .resolved)
        #expect(closed.resolution == "resolved in the history window")

        model.select(.resolved)
        model.selection = ["a"]
        model.toggleResolution()
        let reopened = try #require(try store.comment(id: "a"))
        #expect(reopened.status == .open)
    }

    @Test("resolving with nothing selected does nothing")
    func toggleWithoutSelection() throws {
        try store.insert(sample(id: "a"))
        show()
        model.toggleResolution()
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .open)
    }

    @Test("editing a note writes it and reads it back")
    func saveNote() throws {
        try store.insert(sample(id: "a", note: "before"))
        show()
        let comment = try #require(model.rows.first)

        model.save(note: "after", for: comment)
        #expect(model.rows.first?.note == "after")
    }

    @Test("saving a note that did not change writes nothing")
    func saveUnchangedNote() throws {
        try store.insert(sample(id: "a", note: "same"))
        show()
        let comment = try #require(model.rows.first)

        model.save(note: "same", for: comment)
        #expect(model.prompt == .none)
    }

    @Test("saving a note over a comment that is gone says so")
    func saveMissingNote() throws {
        try store.insert(sample(id: "a", note: "before"))
        show()
        let comment = try #require(model.rows.first)
        _ = try store.delete(ids: ["a"])

        model.save(note: "after", for: comment)
        #expect(model.prompt?.title == "Could not save the note")
    }

    @Test("deleting the selected rows asks first and names what would go")
    func confirmDeleteSelection() throws {
        try store.insert(sample(id: "a", note: "the note"))
        show()
        model.selection = ["a"]

        model.confirmDeleteSelection()
        let prompt = try #require(model.prompt)
        #expect(prompt.title == "Delete this comment?")
        #expect(prompt.detail.contains("the note"))
        #expect(prompt.detail.contains("cannot be undone"))
    }

    @Test("deleting several rows says how many")
    func confirmDeleteSeveral() throws {
        try store.insert(sample(id: "a"))
        try store.insert(sample(id: "b"))
        show()
        model.selection = ["a", "b"]

        model.confirmDeleteSelection()
        #expect(model.prompt?.title == "Delete 2 comments?")
    }

    @Test("deleting with nothing selected asks nothing")
    func confirmDeleteNothing() {
        show()
        model.confirmDeleteSelection()
        #expect(model.prompt == .none)
    }

    @Test("deleting everything shown says which rows that is")
    func confirmDeleteShown() throws {
        try store.insert(sample(id: "a", note: "keep"))
        try store.insert(sample(id: "b", note: "keep"))
        show()
        model.query = "keep"
        model.reload()

        model.confirmDeleteShown()
        let prompt = try #require(model.prompt)
        #expect(prompt.title == "Delete all 2 comments shown?")
        #expect(prompt.detail.contains("Every open comment"))
        #expect(prompt.detail.contains("“keep”"))
    }

    @Test("the warning names the tab the rows came from")
    func confirmDeleteShownScope() throws {
        try store.insert(sample(id: "a", status: .resolved))
        show()
        model.select(.resolved)

        model.confirmDeleteShown()
        #expect(model.prompt?.detail.contains("Every resolved comment") == true)
    }

    @Test("agreeing to the deletion removes the rows for good")
    func performDelete() throws {
        try store.insert(sample(id: "a"))
        try store.insert(sample(id: "b"))
        show()

        model.perform(.delete(["a"]))
        #expect(model.rows.map(\.id) == ["b"])
        #expect(try store.comment(id: "a")?.id == .none)
    }

    @Test("running comments with no project and no folder to start in says so")
    func runWithoutRoot() throws {
        model.fallbackRoot = ""
        try store.insert(sample(id: "a", projectRoot: "", file: "", path: ""))
        show()
        model.selection = ["a"]

        model.runSelection()
        #expect(model.prompt?.title == "Nothing to run")
        #expect(model.prompt?.detail.contains("config.json") == true)
    }

    @Test("running comments from three projects asks before opening three sessions")
    func runAcrossProjects() throws {
        try store.insert(sample(id: "a", projectRoot: "/one"))
        try store.insert(sample(id: "b", projectRoot: "/two"))
        show()
        model.selection = ["a", "b"]

        model.runSelection()
        let prompt = try #require(model.prompt)
        #expect(prompt.title == "Run 2 comments in 2 projects?")
        #expect(prompt.detail.contains("one — 1 comment"))
        #expect(prompt.detail.contains("two — 1 comment"))
    }

    @Test("running nothing asks nothing")
    func runNothing() {
        show()
        model.runSelection()
        #expect(model.prompt == .none)
    }

    @Test("closing the window drops the rows and the selection")
    func windowClosed() throws {
        try store.insert(sample(id: "a"))
        show()
        model.selection = ["a"]

        model.windowClosed()
        #expect(!model.isShowing)
        #expect(model.rows.isEmpty)
        #expect(model.loaded == 0)
        #expect(model.selection.isEmpty)
    }

    @Test("the terminal button says how many sessions are running")
    func terminalTitle() {
        #expect(model.terminalTitle == "Terminal")
    }

    @Test("the terminal panel is hidden until it is asked for")
    func toggleTerminal() {
        #expect(!model.terminalShown)
        model.toggleTerminal()
        #expect(model.terminalShown)
        model.toggleTerminal()
        #expect(!model.terminalShown)
    }

    @Test("the terminal panel never shrinks below the height it needs")
    func terminalHeightMinimum() {
        model.setTerminalHeight(20, limit: 600)
        #expect(model.terminalHeight == Theme().terminalMinimumHeight)
    }

    @Test("the terminal panel never grows past the window")
    func terminalHeightLimit() {
        model.setTerminalHeight(900, limit: 600)
        #expect(model.terminalHeight == 600)
    }

    @Test("a limit smaller than the minimum still leaves the panel usable")
    func terminalHeightTightLimit() {
        model.setTerminalHeight(300, limit: 40)
        #expect(model.terminalHeight == Theme().terminalMinimumHeight)
    }

    @Test("a height between the two is taken as it is")
    func terminalHeightBetween() {
        model.setTerminalHeight(300, limit: 600)
        #expect(model.terminalHeight == 300)
    }
}
