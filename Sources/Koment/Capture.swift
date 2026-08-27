import CoreGraphics
import Foundation

struct Capture {
    var selectedText: String
    var appName: String
    var documentPath: String? = .none
    var windowTitle: String? = .none
    var bundleIdentifier: String? = .none
    var sourceURL: String? = .none
    var screenFrame: CGRect? = .none
    var axLine: Int? = .none
    var contextBefore: [String] = []
    var contextAfter: [String] = []
    var method: String

    var lines: [String] {
        var result = selectedText.components(separatedBy: .newlines)
        while let last = result.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            result.removeLast()
        }
        return result
    }

    var isWindowNote: Bool {
        method == "window"
    }

    var needle: String {
        lines.first(where: { $0.trimmingCharacters(in: .whitespaces).count > 2 })?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}

struct Location: Equatable {
    var repoRoot: String
    var relativePath: String
    var absolutePath: String
    var line: Int
    var endLine: Int
    var confidence: String

    var lineSpan: String {
        line == endLine ? "\(line)" : "\(line)-\(endLine)"
    }

    var fileName: String {
        (absolutePath as NSString).lastPathComponent
    }
}
