import KomentCore
import Foundation

extension InlineComment {
    var statusText: String {
        status.rawValue
    }

    var projectName: String {
        projectRoot.isEmpty ? "—" : (projectRoot as NSString).lastPathComponent
    }

    var projectFolder: String {
        guard !projectRoot.isEmpty else { return "no project" }
        let parent = (projectRoot as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent.abbreviatedPath
    }

    var fileName: String {
        file.isEmpty ? "unanchored" : (file as NSString).lastPathComponent
    }

    var fileLabel: String {
        lineSpan.isEmpty ? fileName : "\(fileName):\(lineSpan)"
    }

    var folderText: String {
        let path = displayPath
        guard !path.isEmpty else {
            return windowTitle.isEmpty ? "no file" : windowTitle
        }
        let folder = (path as NSString).deletingLastPathComponent
        guard !projectRoot.isEmpty, folder.hasPrefix(projectRoot) else {
            return folder.abbreviatedPath
        }
        let inside = String(folder.dropFirst(projectRoot.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return inside.isEmpty ? "repository root" : inside
    }

    var originText: String {
        let path = displayPath
        guard path.isEmpty else {
            return lineSpan.isEmpty ? path : "\(path):\(lineSpan)"
        }
        guard sourceURL.isEmpty else { return sourceURL }
        return windowTitle
    }

    var whenText: String {
        guard let date = createdDate else { return createdAt }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'today' HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'yesterday' HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "d MMM HH:mm"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }
        return formatter.string(from: date)
    }

    var metaText: String {
        var parts = [
            status.rawValue,
            anchor.confidence,
            windowTitle.isEmpty
                ? "captured in \(capturedIn)"
                : "captured in \(capturedIn) — \(windowTitle)",
            "created \(createdAt.stampText)"
        ]
        if let resolvedAt {
            parts.append("closed \(resolvedAt.stampText)")
        }
        if let resolution, !resolution.isEmpty {
            parts.append(resolution)
        }
        return parts.joined(separator: "  ·  ")
    }

    var snippetSummary: String {
        anchor.selectedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: "  ⏎  ")
    }

    var searchHaystack: String {
        [note, displayPath, projectName, capturedIn, windowTitle, sourceURL]
            .joined(separator: " ")
    }

    var noteExcerpt: String {
        note.count > 80 ? note.prefix(80) + "…" : note
    }
}

extension String {
    var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard hasPrefix(home) else { return self }
        return "~" + String(dropFirst(home.count))
    }

    var stampText: String {
        guard let date = ISO8601DateFormatter().date(from: self) else { return self }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        return formatter.string(from: date)
    }
}
