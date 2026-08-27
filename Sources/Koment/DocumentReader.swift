import AppKit

struct DocumentReader {
    private let richFormats = ["rtf", "rtfd", "doc", "docx", "odt", "html", "htm", "webarchive"]

    func lines(of path: String) -> [String] {
        let text = richFormats.contains((path as NSString).pathExtension.lowercased())
            ? richText(path)
            : try? String(contentsOfFile: path, encoding: .utf8)
        guard let text, !text.isEmpty else { return [] }
        return text.components(separatedBy: .newlines)
    }

    private func richText(_ path: String) -> String? {
        try? NSAttributedString(
            url: URL(fileURLWithPath: path),
            options: [:],
            documentAttributes: .none
        ).string
    }
}
