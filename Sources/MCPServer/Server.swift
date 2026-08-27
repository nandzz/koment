import KomentCore
import Foundation

private let protocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

public final class Server {
    private let transport = Transport()
    private let signal = ChangeSignal()
    private let shell = Shell()
    private let paths = Paths()
    private var opened: CommentStore?

    public init() {}

    public func serve() {
        while let request = transport.read() {
            handle(request)
        }
    }

    private func handle(_ request: Request) {
        switch request.method {
        case "initialize":
            transport.reply(to: request, result: greeting(request))
        case "notifications/initialized", "notifications/cancelled":
            return
        case "ping":
            transport.reply(to: request, result: [:])
        case "tools/list":
            transport.reply(to: request, result: ["tools": Catalogue().tools])
        case "tools/call":
            call(request)
        default:
            guard !request.isNotification else { return }
            transport.fail(request, code: -32601, message: "unknown method \(request.method)")
        }
    }

    func greeting(_ request: Request) -> [String: Any] {
        let asked = request.params["protocolVersion"] as? String
        let version = protocolVersions.contains(asked ?? "") ? (asked ?? "") : protocolVersions[0]
        return [
            "protocolVersion": version,
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": "koment", "version": "1.0.0"]
        ]
    }

    private func call(_ request: Request) {
        let name = request.params["name"] as? String ?? ""
        let arguments = request.params["arguments"] as? [String: Any] ?? [:]
        do {
            let payload = try answer(name: name, arguments: arguments, store: try store())
            transport.reply(to: request, result: [
                "content": [["type": "text", "text": payload]]
            ])
        } catch let error as ToolError {
            transport.reply(to: request, result: [
                "isError": true,
                "content": [["type": "text", "text": error.description]]
            ])
        } catch {
            transport.fail(request, code: -32603, message: "\(error)")
        }
    }

    private func store() throws -> CommentStore {
        if let opened { return opened }
        let store = CommentStore(database: try Database(url: paths.databaseURL))
        opened = store
        return store
    }

    func answer(
        name: String,
        arguments: [String: Any],
        store: CommentStore
    ) throws -> String {
        switch name {
        case "list_comments":
            let statuses = try requested(arguments["status"] as? String)
            let comments = try store.comments(
                in: statuses,
                project: scope(arguments["project"] as? String),
                limit: arguments["limit"] as? Int ?? 50
            )
            return encoded(comments)

        case "get_comment":
            let id = try identifier(arguments)
            guard let comment = try store.comment(id: id) else {
                throw ToolError.noSuchComment(id)
            }
            return encoded(comment)

        case "resolve_comment":
            let id = try identifier(arguments)
            let summary = arguments["summary"] as? String ?? ""
            guard try store.resolve(id: id, resolution: summary) else {
                throw ToolError.noSuchComment(id)
            }
            signal.post()
            return "resolved \(id)"

        case "mark_drifted":
            let id = try identifier(arguments)
            let reason = arguments["reason"] as? String ?? ""
            guard try store.markDrifted(id: id, reason: reason) else {
                throw ToolError.noSuchComment(id)
            }
            signal.post()
            return "marked \(id) as drifted"

        case "list_projects":
            let projects = try store.projects().map {
                ["root": $0.root, "name": $0.name, "open": $0.openCount] as [String: Any]
            }
            return encoded(projects)

        default:
            throw ToolError.noSuchTool(name)
        }
    }

    func requested(_ status: String?) throws -> [CommentStatus] {
        guard let status else { return [.open] }
        guard status != "all" else { return [] }
        guard let parsed = CommentStatus(rawValue: status) else {
            throw ToolError.badArgument("status must be open, resolved, drifted or all")
        }
        return [parsed]
    }

    func identifier(_ arguments: [String: Any]) throws -> String {
        guard let id = arguments["id"] as? String, !id.isEmpty else {
            throw ToolError.badArgument("id is required")
        }
        return id
    }

    func scope(_ project: String?) -> String? {
        if let project {
            return project == "all" ? .none : (project as NSString).expandingTildeInPath
        }
        let directory = FileManager.default.currentDirectoryPath
        let root = shell.trimmed(["git", "rev-parse", "--show-toplevel"], in: directory)
        return root.isEmpty ? .none : root
    }

    private func encoded<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func encoded(_ value: [[String: Any]]) -> String {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .withoutEscapingSlashes]
            )
        else {
            return "[]"
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

enum ToolError: Error, CustomStringConvertible {
    case noSuchTool(String)
    case noSuchComment(String)
    case badArgument(String)

    var description: String {
        switch self {
        case .noSuchTool(let name): return "no tool named \(name)"
        case .noSuchComment(let id): return "no comment with id \(id)"
        case .badArgument(let reason): return reason
        }
    }
}
