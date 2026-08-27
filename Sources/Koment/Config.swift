import KomentCore
import Foundation

struct Config: Codable {
    var roots: [String]
    var hotkeyKey: String
    var hotkeyModifiers: [String]
    var doubleTapCopy: Bool
    var terminalApp: String
    var embeddedTerminal: Bool

    var expandedRoots: [String] {
        roots.map { ($0 as NSString).expandingTildeInPath }
    }
}

extension Config {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roots = try container.decode([String].self, forKey: .roots)
        hotkeyKey = try container.decode(String.self, forKey: .hotkeyKey)
        hotkeyModifiers = try container.decode([String].self, forKey: .hotkeyModifiers)
        doubleTapCopy = try container.decodeIfPresent(Bool.self, forKey: .doubleTapCopy) ?? true
        terminalApp = try container.decodeIfPresent(String.self, forKey: .terminalApp) ?? "Terminal"
        embeddedTerminal = try container.decodeIfPresent(Bool.self, forKey: .embeddedTerminal) ?? true
    }
}

struct ConfigLoader {
    private var fileURL: URL {
        Paths().configURL
    }

    private var fallback: Config {
        Config(
            roots: ["~/Desktop/Workspace"],
            hotkeyKey: "c",
            hotkeyModifiers: ["control", "option", "command"],
            doubleTapCopy: true,
            terminalApp: "Terminal",
            embeddedTerminal: true
        )
    }

    func load() -> Config {
        guard
            let data = try? Data(contentsOf: fileURL),
            let config = try? JSONDecoder().decode(Config.self, from: data)
        else {
            writeFallback()
            return fallback
        }
        return config
    }

    private func writeFallback() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(fallback) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
