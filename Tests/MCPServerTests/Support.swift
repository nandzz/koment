import KomentCore
import Foundation

final class Workspace {
    let directory: URL

    init() {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("koment-mcp-tests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    var databaseURL: URL {
        directory.appendingPathComponent("comments.db")
    }
}

func sample(
    id: String = UUID().uuidString,
    createdAt: String = "2026-08-25T13:40:12Z",
    status: CommentStatus = .open,
    note: String = "this must use the Tasty spacing token",
    projectRoot: String = "/Users/you/Workspace/app",
    file: String = "Sources/Foo/Bar.swift",
    path: String = "/Users/you/Workspace/app/Sources/Foo/Bar.swift",
    line: Int = 42,
    endLine: Int = 44,
    windowTitle: String = "Bar.swift",
    sourceURL: String = ""
) -> InlineComment {
    InlineComment(
        id: id,
        createdAt: createdAt,
        status: status,
        note: note,
        projectRoot: projectRoot,
        file: file,
        path: path,
        line: line,
        endLine: endLine,
        anchor: CommentAnchor(
            selectedText: ".padding(16)",
            before: ["one", "two"],
            after: ["three"],
            blob: "a1b2c3",
            confidence: "ax-exact"
        ),
        capturedIn: "Xcode",
        method: "ax-selected-text",
        windowTitle: windowTitle,
        bundleIdentifier: "com.apple.dt.Xcode",
        sourceURL: sourceURL
    )
}

func objects(from payload: String) throws -> [[String: Any]] {
    let data = Data(payload.utf8)
    return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
}

func object(from payload: String) throws -> [String: Any] {
    let data = Data(payload.utf8)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
}
