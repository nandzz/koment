import Foundation

struct Catalogue {
    var tools: [[String: Any]] {
        [
            tool(
                name: "list_comments",
                description: """
                List the inline comments a human attached to lines of code with the Claude \
                Comments app. Without arguments it returns the open comments of the current \
                project. Each entry carries the absolute path, the line span at capture time, \
                and an anchor for finding the code again after it moved. A comment captured \
                where there is no file has an empty path, and says where it came from through \
                windowTitle, sourceURL and bundleIdentifier instead.
                """,
                properties: [
                    "status": [
                        "type": "string",
                        "enum": ["open", "resolved", "drifted", "all"],
                        "description": "Which comments to return. Defaults to open, the work that is left."
                    ],
                    "project": [
                        "type": "string",
                        "description": "Absolute path of a project root, or all for every project. Defaults to the current repository."
                    ],
                    "limit": [
                        "type": "integer",
                        "description": "How many comments to return, newest first. Defaults to 50."
                    ]
                ],
                required: []
            ),
            tool(
                name: "get_comment",
                description: "Return one comment in full, with the text that was selected and the lines around it.",
                properties: [
                    "id": ["type": "string", "description": "The comment id."]
                ],
                required: ["id"]
            ),
            tool(
                name: "resolve_comment",
                description: """
                Close a comment after applying it. Records what was changed, so the comment \
                stops appearing in the open list.
                """,
                properties: [
                    "id": ["type": "string", "description": "The comment id."],
                    "summary": [
                        "type": "string",
                        "description": "One line saying what you changed."
                    ]
                ],
                required: ["id", "summary"]
            ),
            tool(
                name: "mark_drifted",
                description: """
                Record that a comment can no longer be located: the code it points at moved \
                or went away. Use this instead of guessing which lines were meant.
                """,
                properties: [
                    "id": ["type": "string", "description": "The comment id."],
                    "reason": [
                        "type": "string",
                        "description": "One line saying what you looked for and did not find."
                    ]
                ],
                required: ["id", "reason"]
            ),
            tool(
                name: "list_projects",
                description: "List every project that holds comments, with how many are still open.",
                properties: [:],
                required: []
            )
        ]
    }

    private func tool(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "inputSchema": [
                "type": "object",
                "properties": properties,
                "required": required
            ]
        ]
    }
}
