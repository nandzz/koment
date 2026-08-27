import KomentCore
import CoreGraphics
import Foundation

struct CaptureReport {
    var trusted: Bool
    var appName: String
    var focusedRole: String?
    var axSelectedLength: Int
    var clipboardLength: Int
    var documentPath: String?
    var windowTitle: String?
    var bundleIdentifier: String?
    var sourceURL: String?
    var screenFrame: CGRect?
    var axLine: Int?
    var method: String

    var rows: [String] {
        [
            "app: \(appName)",
            "trusted: \(trusted)",
            "focusedRole: \(focusedRole ?? "none")",
            "axSelectedLength: \(axSelectedLength)",
            "clipboardLength: \(clipboardLength)",
            "documentPath: \(documentPath ?? "none")",
            "windowTitle: \(windowTitle ?? "none")",
            "bundleIdentifier: \(bundleIdentifier ?? "none")",
            "sourceURL: \(sourceURL ?? "none")",
            "screenFrame: \(frameText)",
            "axLine: \(axLine.map(String.init) ?? "none")",
            "method: \(method)"
        ]
    }

    private var frameText: String {
        guard let screenFrame else { return "none" }
        return "\(Int(screenFrame.minX)),\(Int(screenFrame.minY)) \(Int(screenFrame.width))x\(Int(screenFrame.height))"
    }

    var advice: String {
        if !trusted {
            return "Koment has no Accessibility permission. Open System Settings, Privacy & Security, Accessibility, and switch it on."
        }
        if axSelectedLength == 0 && clipboardLength == 0 {
            return "\(appName) returned no selected text and did not answer a copy. Select the lines again, then press the shortcut without clicking anywhere else. To write a note about the window itself, choose Comment on this window."
        }
        return "The selection was empty. To write a note about the window itself, choose Comment on this window."
    }
}

struct Diagnostics {
    private var fileURL: URL {
        Paths().diagnosticsURL
    }

    var url: URL { fileURL }

    func append(_ rows: [String]) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let text = (["[\(stamp)]"] + rows.map { "  " + $0 }).joined(separator: "\n") + "\n"
        guard let data = text.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            try? data.write(to: fileURL, options: .atomic)
            return
        }
        handle.seekToEndOfFile()
        try? handle.write(contentsOf: data)
        try? handle.close()
    }
}
