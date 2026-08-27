import KomentCore
import Foundation

private let prunedDirectories = [
    ".git", ".build", "DerivedData", "Pods", "Carthage",
    "node_modules", ".swiftpm", "build", "vendor"
]

struct Resolver {
    let shell: Shell
    let roots: [String]
    private let reader = DocumentReader()

    func resolve(_ capture: Capture) -> Location? {
        if let location = fromDocumentPath(capture) { return location }
        if let location = fromWindowTitle(capture) { return location }
        return fromRepositorySearch(capture)
    }

    private func fromDocumentPath(_ capture: Capture) -> Location? {
        guard
            let path = capture.documentPath,
            FileManager.default.fileExists(atPath: path)
        else {
            return .none
        }
        let root = anchorRoot(containing: path) ?? (path as NSString).deletingLastPathComponent
        if let axLine = capture.axLine {
            return location(root: root, path: path, line: axLine, capture: capture, confidence: "ax-exact")
        }
        guard let found = firstLine(matching: capture.needle, inFile: path) else {
            return location(root: root, path: path, line: 1, capture: capture, confidence: "document-only")
        }
        return location(root: root, path: path, line: found, capture: capture, confidence: "document-search")
    }

    private func fromWindowTitle(_ capture: Capture) -> Location? {
        guard let name = fileName(from: capture.windowTitle) else { return .none }
        for root in roots {
            for candidate in files(named: name, under: root) {
                guard
                    let found = firstLine(matching: capture.needle, inFile: candidate),
                    let repository = anchorRoot(containing: candidate)
                else {
                    continue
                }
                return location(root: repository, path: candidate, line: found, capture: capture, confidence: "title-search")
            }
        }
        return .none
    }

    private func fromRepositorySearch(_ capture: Capture) -> Location? {
        guard capture.needle.count >= 8 else { return .none }
        let preferredName = fileName(from: capture.windowTitle)
        for repository in repositories() {
            let hits = grep(needle: capture.needle, in: repository)
            guard !hits.isEmpty else { continue }
            let hit = hits.first(where: { ($0.path as NSString).lastPathComponent == preferredName }) ?? hits[0]
            let path = (repository as NSString).appendingPathComponent(hit.path)
            return location(root: repository, path: path, line: hit.line, capture: capture, confidence: "repo-search")
        }
        return .none
    }

    private func location(root: String, path: String, line: Int, capture: Capture, confidence: String) -> Location {
        let span = max(1, capture.lines.count)
        return Location(
            repoRoot: root,
            relativePath: relativePath(of: path, root: root),
            absolutePath: path,
            line: line,
            endLine: line + span - 1,
            confidence: confidence
        )
    }

    func anchor(for capture: Capture, at location: Location) -> CommentAnchor {
        let rows = reader.lines(of: location.absolutePath)
        let start = min(rows.count, max(0, location.line - 4))
        let beforeEnd = max(start, min(rows.count, location.line - 1))
        let afterStart = min(rows.count, location.endLine)
        let before = rows.isEmpty ? capture.contextBefore : Array(rows[start..<beforeEnd])
        let after = rows.isEmpty
            ? capture.contextAfter
            : Array(rows[afterStart..<min(rows.count, afterStart + 3)])
        let blob = shell.trimmed(["git", "hash-object", location.relativePath], in: location.repoRoot)

        return CommentAnchor(
            selectedText: capture.selectedText,
            before: before,
            after: after,
            blob: blob.isEmpty ? .none : blob,
            confidence: location.confidence
        )
    }

    func anchorRoot(containing path: String) -> String? {
        let directory = (path as NSString).deletingLastPathComponent
        let gitRoot = shell.trimmed(["git", "rev-parse", "--show-toplevel"], in: directory)
        if !gitRoot.isEmpty {
            return gitRoot
        }
        if let owned = nearestDirectoryWithClaudeFolder(from: directory) {
            return owned
        }
        return projectDirectory(containing: path)
    }

    private func nearestDirectoryWithClaudeFolder(from directory: String) -> String? {
        var current = directory
        while roots.contains(where: { current.hasPrefix($0) }) {
            if FileManager.default.fileExists(atPath: (current as NSString).appendingPathComponent(".claude")) {
                return current
            }
            let parent = (current as NSString).deletingLastPathComponent
            if parent == current {
                return .none
            }
            current = parent
        }
        return .none
    }

    private func projectDirectory(containing path: String) -> String? {
        for root in roots where path.hasPrefix(root + "/") {
            let remainder = path.dropFirst(root.count + 1)
            guard let first = remainder.split(separator: "/").first else { continue }
            return (root as NSString).appendingPathComponent(String(first))
        }
        return .none
    }

    func relativePath(of path: String, root: String) -> String {
        guard path.hasPrefix(root) else { return path }
        return String(path.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func repositories() -> [String] {
        var found: [String] = []
        for root in roots {
            let output = shell.run(["find", root, "-maxdepth", "3", "-name", ".git"])
            for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                let repository = (line as NSString).deletingLastPathComponent
                if !found.contains(repository) {
                    found.append(repository)
                }
            }
        }
        return found
    }

    private func files(named name: String, under root: String) -> [String] {
        var arguments = ["find", root, "-maxdepth", "8"]
        for directory in prunedDirectories {
            arguments += ["-name", directory, "-prune", "-o"]
        }
        arguments += ["-name", name, "-print"]
        let output = shell.run(arguments)
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private func grep(needle: String, in repository: String) -> [(path: String, line: Int)] {
        let output = shell.run(
            ["git", "grep", "-n", "--fixed-strings", "--no-color", "-e", needle],
            in: repository
        )
        var hits: [(path: String, line: Int)] = []
        for row in output.components(separatedBy: .newlines) where !row.isEmpty {
            let parts = row.components(separatedBy: ":")
            guard parts.count >= 3, let line = Int(parts[1]) else { continue }
            hits.append((path: parts[0], line: line))
        }
        return hits
    }

    func firstLine(matching needle: String, inFile path: String) -> Int? {
        guard !needle.isEmpty else { return .none }
        for (index, row) in reader.lines(of: path).enumerated() where row.contains(needle) {
            return index + 1
        }
        return .none
    }

    func fileName(from title: String?) -> String? {
        guard let title else { return .none }
        let separators = CharacterSet(charactersIn: "—–-|")
        let parts = title.components(separatedBy: separators)
        for part in parts {
            let candidate = part
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "●•* "))
            if candidate.contains("."), !candidate.contains("/"), !candidate.contains(" ") {
                return candidate
            }
        }
        return .none
    }
}
