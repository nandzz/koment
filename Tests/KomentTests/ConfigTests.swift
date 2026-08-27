@testable import Koment
import Foundation
import Testing

private let complete = """
{
  "doubleTapCopy": false,
  "embeddedTerminal": false,
  "hotkeyKey": "k",
  "hotkeyModifiers": ["control", "shift"],
  "roots": ["~/Desktop/Workspace", "/opt/src"],
  "terminalApp": "Warp"
}
"""

private let minimal = """
{
  "hotkeyKey": "c",
  "hotkeyModifiers": ["control", "option", "command"],
  "roots": ["~/Desktop/Workspace"]
}
"""

@Suite("Config")
struct ConfigTests {
    private func decode(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    @Test("a full file is read as it is written")
    func full() throws {
        let config = try decode(complete)
        #expect(config.roots == ["~/Desktop/Workspace", "/opt/src"])
        #expect(config.hotkeyKey == "k")
        #expect(config.hotkeyModifiers == ["control", "shift"])
        #expect(config.doubleTapCopy == false)
        #expect(config.terminalApp == "Warp")
        #expect(config.embeddedTerminal == false)
    }

    @Test("a file written before the newer keys existed still reads, with the defaults")
    func defaultsForMissingKeys() throws {
        let config = try decode(minimal)
        #expect(config.doubleTapCopy)
        #expect(config.terminalApp == "Terminal")
        #expect(config.embeddedTerminal)
    }

    @Test("a file with no roots is refused rather than read as empty")
    func missingRequiredKey() {
        #expect(throws: (any Error).self) {
            try decode("{\"hotkeyKey\": \"c\", \"hotkeyModifiers\": []}")
        }
    }

    @Test("a file that is not JSON is refused")
    func notJSON() {
        #expect(throws: (any Error).self) {
            try decode("not json at all")
        }
    }

    @Test("a root written with a tilde is expanded before anything searches it")
    func expandedRoots() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let config = Config(
            roots: ["~/Desktop/Workspace", "/opt/src"],
            hotkeyKey: "c",
            hotkeyModifiers: [],
            doubleTapCopy: true,
            terminalApp: "Terminal",
            embeddedTerminal: true
        )
        #expect(config.expandedRoots == [home + "/Desktop/Workspace", "/opt/src"])
    }

    @Test("no roots means nothing to expand")
    func expandedRootsEmpty() {
        let config = Config(
            roots: [],
            hotkeyKey: "c",
            hotkeyModifiers: [],
            doubleTapCopy: true,
            terminalApp: "Terminal",
            embeddedTerminal: true
        )
        #expect(config.expandedRoots.isEmpty)
    }

    @Test("a config survives being written and read back")
    func roundTrip() throws {
        let original = try decode(complete)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Config.self, from: data)

        #expect(restored.roots == original.roots)
        #expect(restored.hotkeyKey == original.hotkeyKey)
        #expect(restored.hotkeyModifiers == original.hotkeyModifiers)
        #expect(restored.doubleTapCopy == original.doubleTapCopy)
        #expect(restored.terminalApp == original.terminalApp)
        #expect(restored.embeddedTerminal == original.embeddedTerminal)
    }
}
