import KomentCore
import Foundation

struct RunGroup {
    let root: String
    let comments: [InlineComment]
    let anchored: Bool

    var name: String {
        anchored ? (root as NSString).lastPathComponent : "no project"
    }
}

struct RunLaunch {
    let group: RunGroup
    let script: URL
}

struct RunPreparation {
    let launches: [RunLaunch]
    let skipped: [InlineComment]
    let failure: String?
}

struct RunOutcome {
    let sessions: Int
    let skipped: [InlineComment]
    let failure: String?
}

struct ClaudeRunner {
    let terminalApp: String
    let fallbackRoot: String

    private let shell = Shell()
    private let paths = Paths()
    private let binary = ClaudeBinary()
    private let fallbackTerminal = "Terminal"

    func groups(for comments: [InlineComment]) -> [RunGroup] {
        var order: [String] = []
        var byRoot: [String: [InlineComment]] = [:]
        for comment in comments where !comment.projectRoot.isEmpty {
            let gathered = byRoot[comment.projectRoot] ?? []
            if gathered.isEmpty {
                order.append(comment.projectRoot)
            }
            byRoot[comment.projectRoot] = gathered + [comment]
        }
        var groups = order.map {
            RunGroup(root: $0, comments: byRoot[$0] ?? [], anchored: true)
        }
        let loose = comments.filter { $0.projectRoot.isEmpty }
        if !loose.isEmpty, let root = startingPoint() {
            groups.append(RunGroup(root: root, comments: loose, anchored: false))
        }
        return groups
    }

    func skipped(from comments: [InlineComment]) -> [InlineComment] {
        guard startingPoint() == .none else { return [] }
        return comments.filter { $0.projectRoot.isEmpty }
    }

    private func startingPoint() -> String? {
        var directory = ObjCBool(false)
        guard
            !fallbackRoot.isEmpty,
            FileManager.default.fileExists(atPath: fallbackRoot, isDirectory: &directory),
            directory.boolValue
        else {
            return .none
        }
        return fallbackRoot
    }

    func prepare(_ comments: [InlineComment]) -> RunPreparation {
        let left = skipped(from: comments)
        let running = groups(for: comments)
        guard !running.isEmpty else {
            return RunPreparation(launches: [], skipped: left, failure: .none)
        }
        guard let claude = binary.path() else {
            return RunPreparation(
                launches: [],
                skipped: left,
                failure: "The app cannot find the claude command. "
                    + "Install Claude Code, then open Setup… to check the connection."
            )
        }
        do {
            try prepareDirectory()
        } catch {
            return RunPreparation(launches: [], skipped: left, failure: "\(error)")
        }

        var launches: [RunLaunch] = []
        for group in running {
            do {
                launches.append(RunLaunch(group: group, script: try write(group, claude: claude)))
            } catch {
                return RunPreparation(launches: launches, skipped: left, failure: "\(error)")
            }
        }
        return RunPreparation(launches: launches, skipped: left, failure: .none)
    }

    func launch(_ comments: [InlineComment]) -> RunOutcome {
        let preparation = prepare(comments)
        if let failure = preparation.failure {
            return RunOutcome(sessions: 0, skipped: preparation.skipped, failure: failure)
        }
        var opened = 0
        for launch in preparation.launches {
            guard open(launch.script) else {
                return RunOutcome(
                    sessions: opened,
                    skipped: preparation.skipped,
                    failure: "Neither \(terminalApp) nor \(fallbackTerminal) would open "
                        + launch.script.path
                )
            }
            opened += 1
        }
        return RunOutcome(sessions: opened, skipped: preparation.skipped, failure: .none)
    }

    private func prepareDirectory() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: paths.runsDirectory, withIntermediateDirectories: true)
        let stale = Date().addingTimeInterval(-86_400)
        let existing = try? manager.contentsOfDirectory(
            at: paths.runsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        for url in existing ?? [] {
            let written = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            guard let written, written < stale else { continue }
            try? manager.removeItem(at: url)
        }
    }

    func script(for group: RunGroup, claude: String) -> String {
        let ids = group.comments.map(\.id).joined(separator: " ")
        return """
        #!/bin/zsh
        cd "\(escaped(group.root))" || exit 1
        exec "\(escaped(claude))" "/koment \(ids)"

        """
    }

    private func write(_ group: RunGroup, claude: String) throws -> URL {
        let url = paths.runsDirectory.appendingPathComponent(filename(for: group))
        try script(for: group, claude: claude).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
        return url
    }

    func filename(for group: RunGroup) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let suffix = group.comments.first.map { String($0.id.prefix(4)) } ?? "0000"
        let name = (group.anchored ? group.name : "no-project")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "\(name.isEmpty ? "project" : name)-\(stamp)-\(suffix).command"
    }

    func open(_ script: URL) -> Bool {
        if shell.execute(["open", "-a", terminalApp, script.path]).succeeded {
            return true
        }
        guard terminalApp != fallbackTerminal else { return false }
        return shell.execute(["open", "-a", fallbackTerminal, script.path]).succeeded
    }

    func escaped(_ value: String) -> String {
        var result = ""
        for character in value {
            if character == "\\" || character == "\"" || character == "$" || character == "`" {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }
}
