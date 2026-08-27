import Foundation

struct Schema {
    let database: Database

    private var steps: [String] {
        [
            """
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
            CREATE INDEX comment_by_status  ON comment(status, created_at);
            CREATE INDEX comment_by_project ON comment(project_root, status, created_at);
            """,
            """
            ALTER TABLE comment ADD COLUMN window_title TEXT NOT NULL DEFAULT '';
            ALTER TABLE comment ADD COLUMN bundle_id    TEXT NOT NULL DEFAULT '';
            ALTER TABLE comment ADD COLUMN source_url   TEXT NOT NULL DEFAULT '';
            """
        ]
    }

    func apply() throws {
        let version = try database.userVersion()
        guard version < steps.count else { return }
        for index in version..<steps.count {
            try database.execute(steps[index])
            try database.setUserVersion(index + 1)
        }
    }
}
