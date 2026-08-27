import KomentCore
import Foundation
import Testing

@Suite("Database")
struct DatabaseTests {
    let space: Workspace
    let database: Database

    init() throws {
        space = Workspace()
        database = try Database(url: space.databaseURL)
    }

    @Test("opening a database creates the file and the folder above it")
    func createsFile() throws {
        let nested = space.path("deep/deeper/comments.db")
        _ = try Database(url: nested)
        #expect(FileManager.default.fileExists(atPath: nested.path))
    }

    @Test("the journal is write-ahead, so the app and the server can both write")
    func walMode() throws {
        let mode = try database.query("PRAGMA journal_mode") { $0.text(0) }.first
        #expect(mode?.lowercased() == "wal")
    }

    @Test("a fresh database carries every schema step")
    func userVersion() throws {
        #expect(try database.userVersion() == 2)
    }

    @Test("the user version can be set and read back")
    func setUserVersion() throws {
        try database.setUserVersion(7)
        #expect(try database.userVersion() == 7)
    }

    @Test("a bound text value comes back as it went in")
    func bindText() throws {
        try database.execute("CREATE TABLE thing (name TEXT, count INTEGER, note TEXT)")
        try database.run(
            "INSERT INTO thing (name, count, note) VALUES (?, ?, ?)",
            [.text("Bar.swift"), .integer(42), .null]
        )
        let rows = try database.query("SELECT name, count, note FROM thing") { row in
            (row.text(0), row.integer(1), row.optionalText(2))
        }
        #expect(rows.count == 1)
        #expect(rows[0].0 == "Bar.swift")
        #expect(rows[0].1 == 42)
        #expect(rows[0].2 == .none)
    }

    @Test("a value built from an optional string is null when the string is absent")
    func valueFromOptional() throws {
        try database.execute("CREATE TABLE thing (note TEXT)")
        try database.run("INSERT INTO thing (note) VALUES (?)", [Value(String?.none)])
        try database.run("INSERT INTO thing (note) VALUES (?)", [Value("here")])
        let notes = try database.query("SELECT note FROM thing ORDER BY rowid") {
            $0.optionalText(0)
        }
        #expect(notes == [.none, "here"])
    }

    @Test("a missing text column reads as an empty string")
    func textOfNull() throws {
        try database.execute("CREATE TABLE thing (note TEXT)")
        try database.run("INSERT INTO thing (note) VALUES (NULL)")
        #expect(try database.query("SELECT note FROM thing") { $0.text(0) } == [""])
    }

    @Test("running a statement reports how many rows it changed")
    func changeCount() throws {
        try database.execute("CREATE TABLE thing (name TEXT)")
        try database.run("INSERT INTO thing (name) VALUES ('a'), ('b'), ('c')")
        #expect(try database.run("DELETE FROM thing WHERE name IN ('a', 'b')") == 2)
        #expect(try database.run("DELETE FROM thing WHERE name = 'zzz'") == 0)
    }

    @Test("a query with no rows returns nothing rather than failing")
    func emptyQuery() throws {
        try database.execute("CREATE TABLE thing (name TEXT)")
        #expect(try database.query("SELECT name FROM thing") { $0.text(0) }.isEmpty)
    }

    @Test("a statement that will not parse throws")
    func badStatement() {
        #expect(throws: DatabaseError.self) {
            try database.run("SELECT * FROM a_table_that_is_not_there")
        }
        #expect(throws: DatabaseError.self) {
            try database.execute("THIS IS NOT SQL")
        }
        #expect(throws: DatabaseError.self) {
            try database.query("SELECT nope FROM nope") { $0.text(0) }
        }
    }

    @Test("a database error says which statement failed and why")
    func errorDescriptions() {
        #expect(DatabaseError.couldNotOpen("/tmp/x.db").description
            == "could not open the database at /tmp/x.db")
        #expect(DatabaseError.failed("SELECT 1", "boom").description == "boom — SELECT 1")
    }

    @Test("two connections can read the same file")
    func secondConnection() throws {
        try database.run(
            "INSERT INTO comment (id, created_at, status, note, project_root, file, path, "
                + "line, end_line, selected_text, before_lines, after_lines, confidence, "
                + "captured_in, method) VALUES ('a', 'now', 'open', 'n', '', '', '', 0, 0, "
                + "'', '[]', '[]', 'c', 'x', 'm')"
        )
        let other = try Database(url: space.databaseURL)
        #expect(try other.query("SELECT id FROM comment") { $0.text(0) } == ["a"])
    }
}
