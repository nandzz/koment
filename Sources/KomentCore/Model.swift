import Foundation

public enum CommentStatus: String, Codable {
    case open
    case resolved
    case drifted
}

public struct CommentAnchor: Codable {
    public var selectedText: String
    public var before: [String]
    public var after: [String]
    public var blob: String?
    public var confidence: String

    public init(
        selectedText: String,
        before: [String],
        after: [String],
        blob: String?,
        confidence: String
    ) {
        self.selectedText = selectedText
        self.before = before
        self.after = after
        self.blob = blob
        self.confidence = confidence
    }
}

public struct InlineComment: Codable, Identifiable {
    public var id: String
    public var createdAt: String
    public var status: CommentStatus
    public var note: String
    public var projectRoot: String
    public var file: String
    public var path: String
    public var line: Int
    public var endLine: Int
    public var anchor: CommentAnchor
    public var capturedIn: String
    public var method: String
    public var windowTitle: String
    public var bundleIdentifier: String
    public var sourceURL: String
    public var resolvedAt: String?
    public var resolution: String?

    public init(
        id: String,
        createdAt: String,
        status: CommentStatus,
        note: String,
        projectRoot: String,
        file: String,
        path: String,
        line: Int,
        endLine: Int,
        anchor: CommentAnchor,
        capturedIn: String,
        method: String,
        windowTitle: String = "",
        bundleIdentifier: String = "",
        sourceURL: String = "",
        resolvedAt: String? = .none,
        resolution: String? = .none
    ) {
        self.id = id
        self.createdAt = createdAt
        self.status = status
        self.note = note
        self.projectRoot = projectRoot
        self.file = file
        self.path = path
        self.line = line
        self.endLine = endLine
        self.anchor = anchor
        self.capturedIn = capturedIn
        self.method = method
        self.windowTitle = windowTitle
        self.bundleIdentifier = bundleIdentifier
        self.sourceURL = sourceURL
        self.resolvedAt = resolvedAt
        self.resolution = resolution
    }

    public var isOpen: Bool {
        status == .open
    }

    public var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }

    public var lineSpan: String {
        guard line > 0 else { return "" }
        return line == endLine ? "\(line)" : "\(line)-\(endLine)"
    }

    public var displayPath: String {
        if !path.isEmpty { return path }
        if !file.isEmpty, !projectRoot.isEmpty {
            return URL(fileURLWithPath: projectRoot).appendingPathComponent(file).path
        }
        return file
    }
}

public struct Project {
    public let root: String
    public let openCount: Int

    public var name: String {
        root.isEmpty ? "unanchored" : (root as NSString).lastPathComponent
    }
}
