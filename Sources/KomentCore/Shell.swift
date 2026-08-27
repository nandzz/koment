import Foundation

public struct Outcome {
    public let status: Int32
    public let output: String
    public let error: String

    public var succeeded: Bool {
        status == 0
    }
}

public struct Shell {
    public init() {}

    public func execute(_ arguments: [String], in directory: String? = .none) -> Outcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        if let directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
        } catch {
            return Outcome(status: -1, output: "", error: error.localizedDescription)
        }
        let produced = output.fileHandleForReading.readDataToEndOfFile()
        let complained = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Outcome(
            status: process.terminationStatus,
            output: String(data: produced, encoding: .utf8) ?? "",
            error: String(data: complained, encoding: .utf8) ?? ""
        )
    }

    public func run(_ arguments: [String], in directory: String? = .none) -> String {
        let outcome = execute(arguments, in: directory)
        return outcome.succeeded ? outcome.output : ""
    }

    public func trimmed(_ arguments: [String], in directory: String? = .none) -> String {
        run(arguments, in: directory).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
