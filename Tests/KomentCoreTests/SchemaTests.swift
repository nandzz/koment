import KomentCore
import Foundation
import Testing

private let firstVersionTable = """
CREATE TABLE comment (
    id            TEXT PRIMARY KEY,
    created_at    TEXT NOT NULL,
    status        TEXT NOT NULL,
    note          TEXT NOT NULL,
    project_root  TEXT NOT NULL,
    file          TEXT NOT NULL,
    path          TEXT NOT NULL,
    line          INTEGER NOT NULL,
    end_line      INTEGER NOT NULL,
    selected_text TEXT NOT NULL,
    before_lines  TEXT NOT NULL,
    after_lines   TEXT NOT NULL,
    blob          TEXT,
    confidence    TEXT NOT NULL,
    captured_in   TEXT NOT NULL,
    method        TEXT NOT NULL,
    resolved_at   TEXT,
    resolution    TEXT
);
"""

@Suite("Schema")
struct SchemaTests {
    let space: Workspace

    init() {
        space = Workspace()
    }

    private func columns(of database: Database) throws -> [String] {
        try database.query("PRAGMA table_info(comment)") { $0.text(1) }
    }

    @Test("a fresh database has every column the store writes")
    func freshColumns() throws {
        let database = try Database(url: space.databaseURL)
        let names = Set(try columns(of: database))
        let expected: Set<String> = [
            "id", "created_at", "status", "note", "project_root", "file", "path",
            "line", "end_line", "selected_text", "before_lines", "after_lines",
            "blob", "confidence", "captured_in", "method", "resolved_at", "resolution",
            "window_title", "bundle_id", "source_url"
        ]
        #expect(names == expected)
    }

    @Test("a fresh database has the indexes the queries need")
    func freshIndexes() throws {
        let database = try Database(url: space.databaseURL)
        let indexes = Set(
            try database.query(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'comment'"
            ) { $0.text(0) }
        )
        #expect(indexes.contains("comment_by_status"))
        #expect(indexes.contains("comment_by_project"))
    }

    @Test("opening a database twice leaves the schema alone")
    func idempotent() throws {
        _ = try Database(url: space.databaseURL)
        let reopened = try Database(url: space.databaseURL)
        #expect(try reopened.userVersion() == 2)
        #expect(try columns(of: reopened).count == 21)
    }

    @Test("a database written by the first version gains the window columns")
    func migratesFromFirstVersion() throws {
        do {
            let old = try Database(url: space.databaseURL)
            try old.execute("DROP TABLE comment")
            try old.execute(firstVersionTable)
            try old.setUserVersion(1)
            let before = try columns(of: old)
            #expect(!before.contains("window_title"))
        }

        let migrated = try Database(url: space.databaseURL)
        #expect(try migrated.userVersion() == 2)
        let names = Set(try columns(of: migrated))
        #expect(names.contains("window_title"))
        #expect(names.contains("bundle_id"))
        #expect(names.contains("source_url"))
    }

    @Test("a comment written before the migration keeps its note and gains empty window columns")
    func migrationKeepsRows() throws {
        do {
            let old = try Database(url: space.databaseURL)
            try old.execute("DROP TABLE comment")
            try old.execute(firstVersionTable)
            try old.setUserVersion(1)
            try old.run(
                "INSERT INTO comment (id, created_at, status, note, project_root, file, path, "
                    + "line, end_line, selected_text, before_lines, after_lines, confidence, "
                    + "captured_in, method) VALUES ('old', '2026-01-01T00:00:00Z', 'open', "
                    + "'an old note', '/root', 'a.swift', '/root/a.swift', 3, 3, 'x', "
                    + "'[]', '[]', 'ax-exact', 'Xcode', 'ax-selected-text')"
            )
        }

        let store = CommentStore(database: try Database(url: space.databaseURL))
        let comment = try #require(try store.comment(id: "old"))
        #expect(comment.note == "an old note")
        #expect(comment.windowTitle.isEmpty)
        #expect(comment.bundleIdentifier.isEmpty)
        #expect(comment.sourceURL.isEmpty)
    }
}
