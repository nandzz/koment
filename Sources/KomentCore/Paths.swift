import Foundation

public struct Paths {
    private let identifier = "com.nandzz.koment"

    public init() {}

    public var supportDirectory: URL {
        let library = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")
        return library.appendingPathComponent(identifier)
    }

    public var databaseURL: URL {
        supportDirectory.appendingPathComponent("comments.db")
    }

    public var configURL: URL {
        supportDirectory.appendingPathComponent("config.json")
    }

    public var diagnosticsURL: URL {
        supportDirectory.appendingPathComponent("diagnostics.log")
    }

    public var runsDirectory: URL {
        supportDirectory.appendingPathComponent("runs")
    }

    public func prepare() throws {
        try FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
    }
}
