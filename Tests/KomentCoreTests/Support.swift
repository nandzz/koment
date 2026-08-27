import KomentCore
import Foundation

final class Workspace {
    let directory: URL

    init() {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("koment-tests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    var databaseURL: URL {
        directory.appendingPathComponent("comments.db")
    }

    func path(_ name: String) -> URL {
        directory.appendingPathComponent(name)
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
    selectedText: String = ".padding(16)",
    before: [String] = ["one", "two", "three"],
    after: [String] = ["four", "five", "six"],
    blob: String? = "a1b2c3",
    confidence: String = "ax-exact",
    capturedIn: String = "Xcode",
    method: String = "ax-selected-text",
    windowTitle: String = "Bar.swift",
    bundleIdentifier: String = "com.apple.dt.Xcode",
    sourceURL: String = "",
    resolvedAt: String? = .none,
    resolution: String? = .none
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
            selectedText: selectedText,
            before: before,
            after: after,
            blob: blob,
            confidence: confidence
        ),
        capturedIn: capturedIn,
        method: method,
        windowTitle: windowTitle,
        bundleIdentifier: bundleIdentifier,
        sourceURL: sourceURL,
        resolvedAt: resolvedAt,
        resolution: resolution
    )
}
