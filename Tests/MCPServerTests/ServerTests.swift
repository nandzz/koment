@testable import MCPServer
import KomentCore
import Foundation
import Testing

@Suite("Server")
struct ServerTests {
    let space: Workspace
    let store: CommentStore
    let server = Server()

    init() throws {
        space = Workspace()
        store = CommentStore(database: try Database(url: space.databaseURL))
    }

    private func call(_ name: String, _ arguments: [String: Any] = [:]) throws -> String {
        try server.answer(name: name, arguments: arguments, store: store)
    }

    private func request(_ params: [String: Any]) -> Request {
        Request(id: 1, method: "initialize", params: params)
    }

    @Test("a request with no id is a notification, one with an id is not")
    func notifications() {
        #expect(Request(id: .none, method: "notifications/initialized", params: [:]).isNotification)
        #expect(!Request(id: 1, method: "ping", params: [:]).isNotification)
        #expect(!Request(id: "abc", method: "ping", params: [:]).isNotification)
    }

    @Test("the greeting agrees to a protocol version the server knows")
    func greetingAgrees() {
        let greeting = server.greeting(request(["protocolVersion": "2024-11-05"]))
        #expect(greeting["protocolVersion"] as? String == "2024-11-05")
    }

    @Test("the greeting falls back to the newest version it knows")
    func greetingFallsBack() {
        #expect(server.greeting(request(["protocolVersion": "1999-01-01"]))["protocolVersion"]
            as? String == "2025-06-18")
        #expect(server.greeting(request([:]))["protocolVersion"] as? String == "2025-06-18")
    }

    @Test("the greeting names the server and offers tools that never change")
    func greetingNamesTheServer() throws {
        let greeting = server.greeting(request([:]))
        let info = try #require(greeting["serverInfo"] as? [String: Any])
        #expect(info["name"] as? String == "koment")
        #expect(info["version"] as? String == "1.0.0")

        let capabilities = try #require(greeting["capabilities"] as? [String: Any])
        let tools = try #require(capabilities["tools"] as? [String: Any])
        #expect(tools["listChanged"] as? Bool == false)
    }

    @Test("no status asked for means the work that is left")
    func statusDefault() throws {
        #expect(try server.requested(.none) == [.open])
    }

    @Test("all means every status")
    func statusAll() throws {
        #expect(try server.requested("all").isEmpty)
    }

    @Test("each status can be asked for by name")
    func statusByName() throws {
        #expect(try server.requested("open") == [.open])
        #expect(try server.requested("resolved") == [.resolved])
        #expect(try server.requested("drifted") == [.drifted])
    }

    @Test("a status nobody defined is refused rather than ignored")
    func statusUnknown() {
        #expect(throws: ToolError.self) {
            try server.requested("closed")
        }
    }

    @Test("an id is required and cannot be empty")
    func identifier() throws {
        #expect(try server.identifier(["id": "9C1F"]) == "9C1F")
        #expect(throws: ToolError.self) {
            try server.identifier([:])
        }
        #expect(throws: ToolError.self) {
            try server.identifier(["id": ""])
        }
        #expect(throws: ToolError.self) {
            try server.identifier(["id": 42])
        }
    }

    @Test("the project all means no project filter")
    func scopeAll() {
        #expect(server.scope("all") == .none)
    }

    @Test("a project written with a tilde is expanded")
    func scopeTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(server.scope("~/Workspace/app") == home + "/Workspace/app")
    }

    @Test("an absolute project is used as it stands")
    func scopeAbsolute() {
        #expect(server.scope("/Users/you/Workspace/app") == "/Users/you/Workspace/app")
    }

    @Test("listing returns the open comments as JSON")
    func listComments() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .resolved))

        let listed = try objects(from: try call("list_comments", ["project": "all"]))
        #expect(listed.count == 1)
        #expect(listed[0]["id"] as? String == "a")
    }

    @Test("listing carries the path, the span and the anchor Claude needs to re-find the code")
    func listedFields() throws {
        try store.insert(sample(id: "a"))
        let listed = try objects(from: try call("list_comments", ["project": "all"]))
        let entry = try #require(listed.first)

        #expect(entry["path"] as? String == "/Users/you/Workspace/app/Sources/Foo/Bar.swift")
        #expect(entry["line"] as? Int == 42)
        #expect(entry["endLine"] as? Int == 44)
        let anchor = try #require(entry["anchor"] as? [String: Any])
        #expect(anchor["selectedText"] as? String == ".padding(16)")
        #expect(anchor["confidence"] as? String == "ax-exact")
    }

    @Test("listing can ask for a status by name")
    func listByStatus() throws {
        try store.insert(sample(id: "a", status: .open))
        try store.insert(sample(id: "b", status: .drifted))

        let drifted = try objects(from: try call(
            "list_comments", ["project": "all", "status": "drifted"]
        ))
        #expect(drifted.map { $0["id"] as? String } == ["b"])

        let every = try objects(from: try call(
            "list_comments", ["project": "all", "status": "all"]
        ))
        #expect(every.count == 2)
    }

    @Test("listing scopes itself to one project when it is given one")
    func listByProject() throws {
        try store.insert(sample(id: "a", projectRoot: "/one"))
        try store.insert(sample(id: "b", projectRoot: "/two"))

        let listed = try objects(from: try call("list_comments", ["project": "/one"]))
        #expect(listed.map { $0["id"] as? String } == ["a"])
    }

    @Test("listing takes the newest when a limit is given")
    func listWithLimit() throws {
        try store.insert(sample(id: "old", createdAt: "2026-08-01T10:00:00Z"))
        try store.insert(sample(id: "new", createdAt: "2026-08-27T10:00:00Z"))

        let listed = try objects(from: try call(
            "list_comments", ["project": "all", "limit": 1]
        ))
        #expect(listed.map { $0["id"] as? String } == ["new"])
    }

    @Test("listing a status the server does not know is refused")
    func listBadStatus() {
        #expect(throws: ToolError.self) {
            try call("list_comments", ["status": "closed"])
        }
    }

    @Test("one comment can be read in full")
    func getComment() throws {
        try store.insert(sample(id: "9C1F"))
        let comment = try object(from: try call("get_comment", ["id": "9C1F"]))
        #expect(comment["id"] as? String == "9C1F")
        #expect(comment["note"] as? String == "this must use the Tasty spacing token")
    }

    @Test("reading a comment that is not there is refused with its id")
    func getMissingComment() throws {
        let error = #expect(throws: ToolError.self) {
            try call("get_comment", ["id": "nope"])
        }
        #expect(error?.description == "no comment with id nope")
    }

    @Test("resolving closes the comment and says so")
    func resolveComment() throws {
        try store.insert(sample(id: "a"))
        #expect(try call("resolve_comment", ["id": "a", "summary": "used the token"])
            == "resolved a")

        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .resolved)
        #expect(stored.resolution == "used the token")
    }

    @Test("resolving without a summary still closes the comment, with nothing recorded")
    func resolveWithoutSummary() throws {
        try store.insert(sample(id: "a"))
        _ = try call("resolve_comment", ["id": "a"])
        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .resolved)
        #expect(stored.resolution?.isEmpty == true)
    }

    @Test("resolving a comment that is not there is refused")
    func resolveMissing() {
        #expect(throws: ToolError.self) {
            try call("resolve_comment", ["id": "nope", "summary": "x"])
        }
    }

    @Test("marking drifted records the reason and leaves the comment for a human")
    func markDrifted() throws {
        try store.insert(sample(id: "a"))
        #expect(try call("mark_drifted", ["id": "a", "reason": "the lines are gone"])
            == "marked a as drifted")

        let stored = try #require(try store.comment(id: "a"))
        #expect(stored.status == .drifted)
        #expect(stored.resolution == "the lines are gone")
    }

    @Test("marking a comment that is not there is refused")
    func driftMissing() {
        #expect(throws: ToolError.self) {
            try call("mark_drifted", ["id": "nope", "reason": "x"])
        }
    }

    @Test("the project list says where the comments are and how many are open")
    func listProjects() throws {
        try store.insert(sample(id: "a", status: .open, projectRoot: "/Users/you/one"))
        try store.insert(sample(id: "b", status: .resolved, projectRoot: "/Users/you/one"))
        try store.insert(sample(id: "c", status: .open, projectRoot: "/Users/you/two"))

        let projects = try objects(from: try call("list_projects"))
        #expect(projects.count == 2)
        #expect(projects[0]["root"] as? String == "/Users/you/one")
        #expect(projects[0]["name"] as? String == "one")
        #expect(projects[0]["open"] as? Int == 1)
        #expect(projects[1]["name"] as? String == "two")
    }

    @Test("no comments means an empty list rather than an error")
    func emptyResults() throws {
        #expect(try objects(from: try call("list_comments", ["project": "all"])).isEmpty)
        #expect(try objects(from: try call("list_projects")).isEmpty)
    }

    @Test("a tool the server does not have is refused by name")
    func unknownTool() throws {
        let error = #expect(throws: ToolError.self) {
            try call("delete_everything")
        }
        #expect(error?.description == "no tool named delete_everything")
    }

    @Test("a tool failure says something a person can read")
    func toolErrorDescriptions() {
        #expect(ToolError.noSuchTool("x").description == "no tool named x")
        #expect(ToolError.noSuchComment("9C1F").description == "no comment with id 9C1F")
        #expect(ToolError.badArgument("id is required").description == "id is required")
    }
}
