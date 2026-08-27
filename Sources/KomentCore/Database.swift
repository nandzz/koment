import Foundation
import SQLite3

private let transientText = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DatabaseError: Error, CustomStringConvertible {
    case couldNotOpen(String)
    case failed(String, String)

    public var description: String {
        switch self {
        case .couldNotOpen(let path):
            return "could not open the database at \(path)"
        case .failed(let statement, let message):
            return "\(message) — \(statement)"
        }
    }
}

public enum Value {
    case text(String)
    case integer(Int)
    case null

    public init(_ value: String?) {
        guard let value else {
            self = .null
            return
        }
        self = .text(value)
    }
}

public struct Row {
    fileprivate let statement: OpaquePointer

    public func text(_ column: Int32) -> String {
        guard let raw = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: raw)
    }

    public func optionalText(_ column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return .none }
        return text(column)
    }

    public func integer(_ column: Int32) -> Int {
        Int(sqlite3_column_int64(statement, column))
    }
}

public final class Database {
    private let handle: OpaquePointer

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &opened, flags, .none) == SQLITE_OK, let opened else {
            throw DatabaseError.couldNotOpen(url.path)
        }
        handle = opened
        try tune()
        try Schema(database: self).apply()
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    public func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, .none, .none, &message) == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(message)
            throw DatabaseError.failed(sql, text)
        }
    }

    @discardableResult
    public func run(_ sql: String, _ values: [Value] = []) throws -> Int {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        let outcome = sqlite3_step(statement)
        guard outcome == SQLITE_DONE || outcome == SQLITE_ROW else {
            throw DatabaseError.failed(sql, message())
        }
        return Int(sqlite3_changes(handle))
    }

    public func query<T>(_ sql: String, _ values: [Value] = [], read: (Row) -> T) throws -> [T] {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        var results: [T] = []
        while true {
            let outcome = sqlite3_step(statement)
            if outcome == SQLITE_DONE { break }
            guard outcome == SQLITE_ROW else {
                throw DatabaseError.failed(sql, message())
            }
            results.append(read(Row(statement: statement)))
        }
        return results
    }

    public func userVersion() throws -> Int {
        try query("PRAGMA user_version") { $0.integer(0) }.first ?? 0
    }

    public func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    private func prepare(_ sql: String, _ values: [Value]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, .none) == SQLITE_OK,
              let statement
        else {
            throw DatabaseError.failed(sql, message())
        }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .text(let text):
                sqlite3_bind_text(statement, index, text, -1, transientText)
            case .integer(let number):
                sqlite3_bind_int64(statement, index, Int64(number))
            case .null:
                sqlite3_bind_null(statement, index)
            }
        }
        return statement
    }

    private func message() -> String {
        String(cString: sqlite3_errmsg(handle))
    }

    private func tune() throws {
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA busy_timeout = 3000")
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA foreign_keys = ON")
    }
}
