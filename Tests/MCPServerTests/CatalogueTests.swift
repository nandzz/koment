@testable import MCPServer
import Foundation
import Testing

@Suite("Catalogue")
struct CatalogueTests {
    let tools = Catalogue().tools

    private func schema(of name: String) throws -> [String: Any] {
        let tool = try #require(tools.first { $0["name"] as? String == name })
        return try #require(tool["inputSchema"] as? [String: Any])
    }

    private func required(of name: String) throws -> [String] {
        let schema = try schema(of: name)
        return try #require(schema["required"] as? [String])
    }

    private func properties(of name: String) throws -> [String: Any] {
        let schema = try schema(of: name)
        return try #require(schema["properties"] as? [String: Any])
    }

    @Test("the server offers exactly the five tools the command relies on")
    func names() {
        let names = tools.compactMap { $0["name"] as? String }
        #expect(names == [
            "list_comments", "get_comment", "resolve_comment", "mark_drifted", "list_projects"
        ])
    }

    @Test("every tool describes itself, because the description is how Claude picks one")
    func descriptions() {
        for entry in tools {
            let description = entry["description"] as? String ?? ""
            #expect(!description.isEmpty)
        }
    }

    @Test("every tool declares an object schema with properties and a required list")
    func schemaShape() throws {
        for entry in tools {
            let name = entry["name"] as? String ?? "?"
            let schema = try #require(entry["inputSchema"] as? [String: Any])
            #expect(schema["type"] as? String == "object", "\(name) is not an object schema")
            #expect(schema["properties"] is [String: Any], "\(name) describes no properties")
            #expect(schema["required"] is [String], "\(name) has no required list")
        }
    }

    @Test("nothing is required that the schema does not describe")
    func requiredIsDescribed() throws {
        for entry in tools {
            let name = try #require(entry["name"] as? String)
            let described = try properties(of: name)
            for key in try required(of: name) {
                #expect(described.keys.contains(key), "\(key) is required but not described")
            }
        }
    }

    @Test("every property has a type and a description")
    func propertiesAreDescribed() throws {
        for entry in tools {
            let name = try #require(entry["name"] as? String)
            for (key, raw) in try properties(of: name) {
                let property = try #require(raw as? [String: Any])
                #expect(property["type"] as? String != .none, "\(key) has no type")
                #expect(property["description"] as? String != .none, "\(key) has no description")
            }
        }
    }

    @Test("listing takes no arguments, so Claude can call it with nothing to go on")
    func listingNeedsNothing() throws {
        #expect(try required(of: "list_comments").isEmpty)
        #expect(try required(of: "list_projects").isEmpty)
    }

    @Test("the status argument names every status a comment can hold, plus all")
    func statusEnum() throws {
        let status = try #require(try properties(of: "list_comments")["status"] as? [String: Any])
        #expect(status["enum"] as? [String] == ["open", "resolved", "drifted", "all"])
    }

    @Test("listing can be narrowed by status, project and count")
    func listingArguments() throws {
        let described = try properties(of: "list_comments")
        #expect(Set(described.keys) == ["status", "project", "limit"])
    }

    @Test("reading one comment needs the id")
    func readingNeedsID() throws {
        #expect(try required(of: "get_comment") == ["id"])
    }

    @Test("closing a comment cannot be done without saying what happened")
    func closingNeedsWords() throws {
        #expect(try required(of: "resolve_comment") == ["id", "summary"])
        #expect(try required(of: "mark_drifted") == ["id", "reason"])
    }

    @Test("list_projects takes no arguments at all")
    func projectsSchema() throws {
        #expect(try properties(of: "list_projects").isEmpty)
    }
}
