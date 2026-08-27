import AppKit
import KomentCore
import SwiftUI

enum CommentFilter: Int, CaseIterable, Hashable {
    case open
    case resolved
    case all

    var title: String {
        switch self {
        case .open: return "Open"
        case .resolved: return "Resolved"
        case .all: return "All"
        }
    }

    var statuses: [CommentStatus] {
        switch self {
        case .open: return [.open, .drifted]
        case .resolved: return [.resolved]
        case .all: return []
        }
    }
}

enum PromptAction: Equatable {
    case run(Set<String>)
    case delete(Set<String>)
}

enum DashboardPrompt: Equatable, Identifiable {
    case message(title: String, detail: String)
    case confirm(title: String, detail: String, button: String, action: PromptAction)

    var id: String {
        title
    }

    var title: String {
        switch self {
        case .message(let title, _), .confirm(let title, _, _, _): return title
        }
    }

    var detail: String {
        switch self {
        case .message(_, let detail), .confirm(_, let detail, _, _): return detail
        }
    }
}

@Observable
final class DashboardModel {
    var filter: CommentFilter = .open
    var query = ""
    var selection: Set<String> = []
    var sortOrder = [KeyPathComparator(\InlineComment.createdAt, order: .reverse)]
    var editing: InlineComment?
    var prompt: DashboardPrompt?
    var terminalShown = false
    var terminalHeight: CGFloat
    var isShowing = false

    var terminalApp = "Terminal"
    var fallbackRoot = ""
    var embeddedTerminal = true

    private(set) var rows: [InlineComment] = []
    private(set) var loaded = 0
    private(set) var readFailure: String?

    let terminal = TerminalModel()

    private let store: CommentStore
    private let signal = ChangeSignal()
    private let opener = FileOpener()
    private let theme: Theme

    init(store: CommentStore, theme: Theme) {
        self.store = store
        self.theme = theme
        terminalHeight = theme.terminalHeight
    }

    var summaryText: String {
        guard !query.isEmpty else {
            return rows.count == 1 ? "1 comment" : "\(rows.count) comments"
        }
        return "\(rows.count) of \(loaded) match"
    }

    var emptyText: String {
        if let readFailure {
            return "The comment database could not be read.\n\n\(readFailure)"
        }
        if !query.isEmpty {
            return "Nothing matches “\(query)”."
        }
        switch filter {
        case .open: return "No open comments. Select code and press the shortcut."
        case .resolved: return "Nothing archived yet. A comment lands here when Claude applies it."
        case .all: return "No comments yet."
        }
    }

    var terminalTitle: String {
        let running = terminal.runningCount
        if terminal.count == 0 { return "Terminal" }
        return running > 0 ? "Terminal (\(running) running)" : "Terminal (\(terminal.count))"
    }

    var runTitle: String {
        runTitle(for: selection)
    }

    var resolveTitle: String {
        resolveTitle(for: selection)
    }

    func runTitle(for ids: Set<String>) -> String {
        let count = comments(for: ids).count
        return count > 1 ? "Run \(count) in Claude" : "Run in Claude"
    }

    func resolveTitle(for ids: Set<String>) -> String {
        let comments = comments(for: ids)
        let resolved = !comments.isEmpty && comments.allSatisfy { $0.status == .resolved }
        return resolved ? "Reopen" : "Resolve"
    }

    var selected: [InlineComment] {
        rows.filter { selection.contains($0.id) }
    }

    var hasSelection: Bool {
        !selection.isEmpty
    }

    var hasFile: Bool {
        !(selected.first?.displayPath.isEmpty ?? true)
    }

    var everySelectedIsResolved: Bool {
        let comments = selected
        return !comments.isEmpty && comments.allSatisfy { $0.status == .resolved }
    }

    func reload() {
        guard isShowing else {
            rows = []
            loaded = 0
            return
        }
        fetch()
    }

    func windowClosed() {
        isShowing = false
        rows = []
        loaded = 0
        selection = []
    }

    func applySort() {
        rows.sort(using: sortOrder)
    }

    private func fetch() {
        let comments: [InlineComment]
        do {
            comments = try store.comments(in: filter.statuses)
            readFailure = .none
        } catch {
            comments = []
            readFailure = "\(error)"
        }
        loaded = comments.count
        rows = comments.filter { matches($0) }.sorted(using: sortOrder)
        selection = selection.filter { id in rows.contains { $0.id == id } }
    }

    private func matches(_ comment: InlineComment) -> Bool {
        guard !query.isEmpty else { return true }
        return comment.searchHaystack.range(of: query, options: .caseInsensitive) != .none
    }

    func select(_ filter: CommentFilter) {
        guard self.filter != filter else { return }
        self.filter = filter
        reload()
    }

    func comments(for ids: Set<String>) -> [InlineComment] {
        rows.filter { ids.contains($0.id) }
    }

    func runSelection() {
        let comments = selected
        guard !comments.isEmpty else { return }
        let runner = ClaudeRunner(terminalApp: terminalApp, fallbackRoot: fallbackRoot)
        let groups = runner.groups(for: comments)
        guard !groups.isEmpty else {
            prompt = .message(title: "Nothing to run", detail: strandedText)
            return
        }
        guard groups.count > 1 else {
            start(comments, with: runner)
            return
        }
        prompt = .confirm(
            title: "Run \(comments.count) comments in \(groups.count) projects?",
            detail: launchText(groups),
            button: "Open \(groups.count) sessions",
            action: .run(Set(comments.map(\.id)))
        )
    }

    func perform(_ action: PromptAction) {
        switch action {
        case .run(let ids):
            let comments = comments(for: ids)
            guard !comments.isEmpty else { return }
            start(comments, with: ClaudeRunner(terminalApp: terminalApp, fallbackRoot: fallbackRoot))
        case .delete(let ids):
            apply(deleting: ids)
        }
    }

    private func start(_ comments: [InlineComment], with runner: ClaudeRunner) {
        guard embeddedTerminal else {
            report(runner.launch(comments))
            return
        }
        let preparation = runner.prepare(comments)
        if !preparation.launches.isEmpty {
            showTerminal()
        }
        for launch in preparation.launches {
            terminal.start(launch)
        }
        report(
            RunOutcome(
                sessions: preparation.launches.count,
                skipped: preparation.skipped,
                failure: preparation.failure
            )
        )
    }

    private func report(_ outcome: RunOutcome) {
        if let failure = outcome.failure {
            prompt = .message(
                title: outcome.sessions == 0 ? "Could not start Claude" : "Some sessions did not start",
                detail: failure
            )
            return
        }
        guard !outcome.skipped.isEmpty else { return }
        prompt = .message(
            title: "\(countText(outcome.skipped.count)) left out",
            detail: strandedText + "\n\nThe rest are running in \(sessionText(outcome.sessions))."
        )
    }

    private var strandedText: String {
        "A comment with no project still needs a directory for Claude to start in, and the "
            + "first entry of roots in config.json does not name a folder that exists."
    }

    private func launchText(_ groups: [RunGroup]) -> String {
        let lines = groups.map { "\($0.name) — \(countText($0.comments.count))" }
        let opening = embeddedTerminal
            ? "One Claude session opens per project, in a tab of the terminal panel."
            : "One Claude session opens per project, in \(terminalApp)."
        return ([opening] + lines).joined(separator: "\n")
    }

    private func countText(_ count: Int) -> String {
        count == 1 ? "1 comment" : "\(count) comments"
    }

    private func sessionText(_ count: Int) -> String {
        count == 1 ? "one session" : "\(count) sessions"
    }

    func open(_ ids: Set<String>) {
        guard let comment = comments(for: ids).first else { return }
        open(comment)
    }

    func openSelection() {
        guard let comment = selected.first else { return }
        open(comment)
    }

    private func open(_ comment: InlineComment) {
        guard !opener.open(comment) else { return }
        prompt = .message(
            title: "Could not open the file",
            detail: comment.displayPath.isEmpty
                ? "This comment was saved without a file."
                : "\(comment.displayPath)\n\nThe file has moved or was deleted."
        )
    }

    func reveal() {
        guard let comment = selected.first, !comment.displayPath.isEmpty else { return }
        NSWorkspace.shared.selectFile(
            comment.displayPath,
            inFileViewerRootedAtPath: comment.projectRoot
        )
    }

    func copyPath() {
        guard let comment = selected.first else { return }
        copy(comment.originText)
    }

    func copyNote() {
        guard let comment = selected.first else { return }
        copy(comment.note)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func edit() {
        editing = selected.first
    }

    func save(note: String, for comment: InlineComment) {
        guard note != comment.note else { return }
        do {
            guard try store.update(id: comment.id, note: note) else {
                prompt = .message(
                    title: "Could not save the note",
                    detail: "The comment is no longer in the database."
                )
                return
            }
            signal.post()
            reload()
        } catch {
            prompt = .message(title: "Could not save the note", detail: "\(error)")
        }
    }

    func toggleResolution() {
        let comments = selected
        guard !comments.isEmpty else { return }
        let reopening = everySelectedIsResolved
        do {
            for comment in comments {
                if reopening {
                    _ = try store.reopen(id: comment.id)
                } else if comment.status != .resolved {
                    _ = try store.resolve(id: comment.id, resolution: "resolved in the history window")
                }
            }
            signal.post()
            reload()
        } catch {
            prompt = .message(title: "Could not change the status", detail: "\(error)")
        }
    }

    func confirmDeleteSelection() {
        let comments = selected
        guard !comments.isEmpty else { return }
        prompt = .confirm(
            title: comments.count == 1 ? "Delete this comment?" : "Delete \(comments.count) comments?",
            detail: deleteText(comments),
            button: comments.count == 1 ? "Delete" : "Delete \(comments.count) comments",
            action: .delete(Set(comments.map(\.id)))
        )
    }

    func confirmDeleteShown() {
        let comments = rows
        guard !comments.isEmpty else { return }
        prompt = .confirm(
            title: comments.count == 1
                ? "Delete the comment shown?"
                : "Delete all \(comments.count) comments shown?",
            detail: scopeText,
            button: comments.count == 1 ? "Delete" : "Delete \(comments.count) comments",
            action: .delete(Set(comments.map(\.id)))
        )
    }

    private func deleteText(_ comments: [InlineComment]) -> String {
        guard comments.count == 1, let comment = comments.first else {
            return "Every selected comment goes, in every project it belongs to."
                + "\n\nThis cannot be undone."
        }
        return "“\(comment.noteExcerpt)”\n\n\(comment.displayPath)\n\nThis cannot be undone."
    }

    private var scopeText: String {
        var lines: [String] = []
        switch filter {
        case .open: lines.append("Every open comment in the list goes, in every project.")
        case .resolved: lines.append("Every resolved comment in the list goes.")
        case .all: lines.append("Every comment in the list goes, open and resolved.")
        }
        if !query.isEmpty {
            lines.append("Only the rows matching “\(query)” are included.")
        }
        lines.append("This cannot be undone.")
        return lines.joined(separator: "\n\n")
    }

    private func apply(deleting ids: Set<String>) {
        let removed = (try? store.delete(ids: ids)) ?? 0
        signal.post()
        reload()
        guard removed < ids.count else { return }
        prompt = .message(
            title: "Some comments were left behind",
            detail: "\(removed) of \(ids.count) were deleted. "
                + "The database refused the rest; the diagnostics log says why."
        )
    }

    func toggleTerminal() {
        terminalShown ? hideTerminal() : showTerminal()
    }

    private func showTerminal() {
        terminalShown = true
        terminal.focus()
    }

    private func hideTerminal() {
        terminalShown = false
    }

    func setTerminalHeight(_ height: CGFloat, limit: CGFloat) {
        terminalHeight = min(max(height, theme.terminalMinimumHeight), max(theme.terminalMinimumHeight, limit))
    }
}
