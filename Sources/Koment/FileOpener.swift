import AppKit
import KomentCore

struct FileOpener {
    private let shell = Shell()

    func open(_ comment: InlineComment) -> Bool {
        let path = comment.displayPath
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return false }

        let line = max(comment.line, 1)
        if comment.capturedIn.caseInsensitiveCompare("Xcode") == .orderedSame {
            return shell.execute(["xed", "--line", "\(line)", path]).succeeded
        }
        if let url = editorURL(path: path, line: line, scheme: scheme(for: comment.capturedIn)),
           NSWorkspace.shared.open(url) {
            return true
        }
        return NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func scheme(for app: String) -> String? {
        switch app.lowercased() {
        case "code", "visual studio code": return "vscode"
        case "code - insiders": return "vscode-insiders"
        case "cursor": return "cursor"
        case "windsurf": return "windsurf"
        case "zed", "zed preview": return "zed"
        default: return .none
        }
    }

    func editorURL(path: String, line: Int, scheme: String?) -> URL? {
        guard
            let scheme,
            let escaped = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else {
            return .none
        }
        return URL(string: "\(scheme)://file\(escaped):\(line)")
    }
}
