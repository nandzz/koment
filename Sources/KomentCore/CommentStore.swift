import Foundation

private let columns = """
id, created_at, status, note, project_root, file, path, line, end_line, \
selected_text, before_lines, after_lines, blob, confidence, captured_in, \
method, window_title, bundle_id, source_url, resolved_at, resolution
"""

public struct CommentStore {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func insert(_ comment: InlineComment) throws {
        try database.run(
            "INSERT OR REPLACE INTO comment (\(columns)) VALUES (\(placeholders(21)))",
            [
                .text(comment.id),
                .text(comment.createdAt),
                .text(comment.status.rawValue),
                .text(comment.note),
                .text(comment.projectRoot),
                .text(comment.file),
                .text(comment.path),
                .integer(comment.line),
                .integer(comment.endLine),
                .text(comment.anchor.selectedText),
                .text(encoded(comment.anchor.before)),
                .text(encoded(comment.anchor.after)),
                Value(comment.anchor.blob),
                .text(comment.anchor.confidence),
                .text(comment.capturedIn),
                .text(comment.method),
                .text(comment.windowTitle),
                .text(comment.bundleIdentifier),
                .text(comment.sourceURL),
                Value(comment.resolvedAt),
                Value(comment.resolution)
            ]
        )
    }

    public func comments(
        in statuses: [CommentStatus] = [],
        project: String? = .none,
        matching query: String = "",
        limit: Int? = .none
    ) throws -> [InlineComment] {
        var conditions: [String] = []
        var values: [Value] = []

        if !statuses.isEmpty {
            conditions.append("status IN (\(placeholders(statuses.count)))")
            values += statuses.map { Value.text($0.rawValue) }
        }
        if let project {
            conditions.append("project_root = ?")
            values.append(.text(project))
        }
        if !query.isEmpty {
            conditions.append(
                """
                (note LIKE ? OR path LIKE ? OR project_root LIKE ? OR captured_in LIKE ? \
                OR window_title LIKE ? OR source_url LIKE ?)
                """
            )
            values += Array(repeating: Value.text("%\(query)%"), count: 6)
        }

        var sql = "SELECT \(columns) FROM comment"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY created_at DESC"
        if let limit {
            sql += " LIMIT ?"
            values.append(.integer(limit))
        }
        return try database.query(sql, values, read: comment(from:))
    }

    public func comment(id: String) throws -> InlineComment? {
        try database
            .query("SELECT \(columns) FROM comment WHERE id = ?", [.text(id)], read: comment(from:))
            .first
    }

    public func projects() throws -> [Project] {
        try database.query(
            """
            SELECT project_root, SUM(status = 'open') FROM comment
            GROUP BY project_root ORDER BY project_root
            """
        ) { row in
            Project(root: row.text(0), openCount: row.integer(1))
        }
    }

    @discardableResult
    public func delete(ids: Set<String>) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        return try database.run(
            "DELETE FROM comment WHERE id IN (\(placeholders(ids.count)))",
            ids.map { Value.text($0) }
        )
    }

    @discardableResult
    public func update(id: String, note: String) throws -> Bool {
        try database.run(
            "UPDATE comment SET note = ? WHERE id = ?",
            [.text(note), .text(id)]
        ) > 0
    }

    @discardableResult
    public func resolve(id: String, resolution: String) throws -> Bool {
        try close(id: id, status: .resolved, resolution: resolution)
    }

    @discardableResult
    public func reopen(id: String) throws -> Bool {
        try database.run(
            "UPDATE comment SET status = ?, resolved_at = NULL, resolution = NULL WHERE id = ?",
            [.text(CommentStatus.open.rawValue), .text(id)]
        ) > 0
    }

    @discardableResult
    public func markDrifted(id: String, reason: String) throws -> Bool {
        try close(id: id, status: .drifted, resolution: reason)
    }

    private func close(id: String, status: CommentStatus, resolution: String) throws -> Bool {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let changed = try database.run(
            "UPDATE comment SET status = ?, resolved_at = ?, resolution = ? WHERE id = ?",
            [.text(status.rawValue), .text(stamp), .text(resolution), .text(id)]
        )
        return changed > 0
    }

    private func comment(from row: Row) -> InlineComment {
        InlineComment(
            id: row.text(0),
            createdAt: row.text(1),
            status: CommentStatus(rawValue: row.text(2)) ?? .open,
            note: row.text(3),
            projectRoot: row.text(4),
            file: row.text(5),
            path: row.text(6),
            line: row.integer(7),
            endLine: row.integer(8),
            anchor: CommentAnchor(
                selectedText: row.text(9),
                before: decoded(row.text(10)),
                after: decoded(row.text(11)),
                blob: row.optionalText(12),
                confidence: row.text(13)
            ),
            capturedIn: row.text(14),
            method: row.text(15),
            windowTitle: row.text(16),
            bundleIdentifier: row.text(17),
            sourceURL: row.text(18),
            resolvedAt: row.optionalText(19),
            resolution: row.optionalText(20)
        )
    }

    private func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }

    private func encoded(_ lines: [String]) -> String {
        guard let data = try? JSONEncoder().encode(lines) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func decoded(_ text: String) -> [String] {
        guard
            let data = text.data(using: .utf8),
            let lines = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return lines
    }
}
