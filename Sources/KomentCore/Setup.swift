import Foundation

public enum SetupState: Equatable {
    case done(String)
    case todo(String)

    public var isDone: Bool {
        switch self {
        case .done: return true
        case .todo: return false
        }
    }

    public var text: String {
        switch self {
        case .done(let detail), .todo(let detail): return detail
        }
    }
}

public enum SetupError: Error, CustomStringConvertible {
    case noRepository
    case noCommandFile
    case noServerBinary(String)
    case registrationFailed(String)

    public var description: String {
        switch self {
        case .noRepository:
            return "the app is not running from its development checkout, "
                + "so it cannot find the repository it belongs to"
        case .noCommandFile:
            return "the /koment command is missing from the app bundle"
        case .noServerBinary(let path):
            return "no server binary at \(path) — build the app first"
        case .registrationFailed(let message):
            return message
        }
    }
}

public protocol SetupStep: AnyObject {
    var title: String { get }
    var detail: String { get }
    var command: String? { get }
    var watchesExternalChange: Bool { get }
    func state() -> SetupState
    func run() throws
}

public extension SetupStep {
    var watchesExternalChange: Bool {
        false
    }
}

public struct DevelopmentRepository {
    public init() {}

    public var root: URL? {
        let stamped = Bundle.main.object(forInfoDictionaryKey: "KomentDevelopmentRoot") as? String
        if let stamped, let checkout = checkout(at: URL(fileURLWithPath: stamped)) {
            return checkout
        }
        var directory = Bundle.main.bundleURL
        while directory.path != "/" {
            directory = directory.deletingLastPathComponent()
            if let checkout = checkout(at: directory) {
                return checkout
            }
        }
        return .none
    }

    private func checkout(at directory: URL) -> URL? {
        let manifest = directory.appendingPathComponent("Package.swift")
        return FileManager.default.fileExists(atPath: manifest.path) ? directory : .none
    }
}

public final class ClaudeCodeConnection: SetupStep {
    private let shell = Shell()
    private let repository = DevelopmentRepository()
    private let serverName = "koment"

    public init() {}

    public var title: String {
        "Connect to Claude Code"
    }

    public var detail: String {
        "Registers the comment server so Claude can read and resolve your notes "
            + "in every project, with no slash command needed to find them."
    }

    public var command: String? {
        guard let binary = binaryURL else { return .none }
        return "claude mcp add -s user \(serverName) -- \(binary.path)"
    }

    public func state() -> SetupState {
        guard let binary = binaryURL else {
            return .todo("cannot find the development checkout")
        }
        guard FileManager.default.fileExists(atPath: binary.path) else {
            return .todo("the server is not built yet")
        }
        guard let registered = registeredCommand() else {
            return .todo("not registered")
        }
        guard registered == binary.path else {
            return .todo("registered at another path")
        }
        return .done("connected")
    }

    public func run() throws {
        guard let binary = binaryURL else { throw SetupError.noRepository }
        guard FileManager.default.fileExists(atPath: binary.path) else {
            throw SetupError.noServerBinary(binary.path)
        }
        if let claude = ClaudeBinary().path() {
            _ = shell.execute([claude, "mcp", "remove", "-s", "user", serverName])
            let outcome = shell.execute(
                [claude, "mcp", "add", "-s", "user", serverName, "--", binary.path]
            )
            if outcome.succeeded, state().isDone { return }
        }
        try register(binary.path)
        guard state().isDone else {
            throw SetupError.registrationFailed("the registration did not take effect")
        }
    }

    private var binaryURL: URL? {
        let embedded = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/KomentMCP")
        guard !FileManager.default.fileExists(atPath: embedded.path) else { return embedded }
        return repository.root?
            .appendingPathComponent(".build/release/KomentMCP")
    }

    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    private func registeredCommand() -> String? {
        guard
            let data = try? Data(contentsOf: configURL),
            let document = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let servers = document["mcpServers"] as? [String: Any],
            let server = servers[serverName] as? [String: Any]
        else {
            return .none
        }
        return server["command"] as? String
    }

    private func register(_ path: String) throws {
        let data = (try? Data(contentsOf: configURL)) ?? Data("{}".utf8)
        guard var document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SetupError.registrationFailed("~/.claude.json is not a JSON object")
        }
        let entry: [String: Any] = [
            "type": "stdio",
            "command": path,
            "args": [String](),
            "env": [String: String]()
        ]
        var servers = document["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = entry
        document["mcpServers"] = servers
        let written = try JSONSerialization.data(withJSONObject: document, options: [])
        try written.write(to: configURL, options: .atomic)
    }
}

public final class CommandInstallation: SetupStep {
    private let repository = DevelopmentRepository()

    public init() {}

    public var title: String {
        "Install the /koment command"
    }

    public var detail: String {
        "Copies the command into ~/.claude/commands, so /koment works in any repository."
    }

    public var command: String? {
        guard let source else { return .none }
        return "cp \(source.path) \(destination.path)"
    }

    public func state() -> SetupState {
        guard let source else {
            return .todo("the command is missing from the app")
        }
        let manager = FileManager.default
        guard manager.fileExists(atPath: destination.path) else {
            return .todo("not installed")
        }
        guard let installed = try? Data(contentsOf: destination),
              let shipped = try? Data(contentsOf: source)
        else {
            return .todo("cannot read the installed command")
        }
        return installed == shipped ? .done("installed") : .todo("an older version is installed")
    }

    public func run() throws {
        guard let source else { throw SetupError.noCommandFile }
        let manager = FileManager.default
        try manager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if manager.fileExists(atPath: destination.path)
            || (try? manager.destinationOfSymbolicLink(atPath: destination.path)) != .none {
            try manager.removeItem(at: destination)
        }
        try manager.copyItem(at: source, to: destination)
    }

    private var source: URL? {
        if let shipped = Bundle.main.url(forResource: "koment", withExtension: "md") {
            return shipped
        }
        let checkout = repository.root?.appendingPathComponent("Resources/koment.md")
        guard let checkout, FileManager.default.fileExists(atPath: checkout.path) else {
            return .none
        }
        return checkout
    }

    private var destination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/commands/koment.md")
    }
}
