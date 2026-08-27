import Foundation

public struct ClaudeBinary {
    private let shell = Shell()

    public init() {}

    public func path() -> String? {
        let found = shell.trimmed(["zsh", "-lc", "command -v claude"])
        if !found.isEmpty, FileManager.default.fileExists(atPath: found) {
            return found
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.local/bin/claude"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
