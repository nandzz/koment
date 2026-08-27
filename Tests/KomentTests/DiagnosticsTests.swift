@testable import Koment
import CoreGraphics
import Foundation
import Testing

@Suite("CaptureReport")
struct CaptureReportTests {
    private func report(
        trusted: Bool = true,
        axSelectedLength: Int = 12,
        clipboardLength: Int = 12,
        focusedRole: String? = "AXTextArea",
        documentPath: String? = "/Users/you/app/Bar.swift",
        windowTitle: String? = "Bar.swift",
        screenFrame: CGRect? = .none,
        axLine: Int? = 42
    ) -> CaptureReport {
        CaptureReport(
            trusted: trusted,
            appName: "Xcode",
            focusedRole: focusedRole,
            axSelectedLength: axSelectedLength,
            clipboardLength: clipboardLength,
            documentPath: documentPath,
            windowTitle: windowTitle,
            bundleIdentifier: "com.apple.dt.Xcode",
            sourceURL: .none,
            screenFrame: screenFrame,
            axLine: axLine,
            method: "ax-selected-text"
        )
    }

    @Test("the log records what the capture saw, one fact per line")
    func rows() {
        let rows = report().rows
        #expect(rows.contains("app: Xcode"))
        #expect(rows.contains("trusted: true"))
        #expect(rows.contains("focusedRole: AXTextArea"))
        #expect(rows.contains("axSelectedLength: 12"))
        #expect(rows.contains("documentPath: /Users/you/app/Bar.swift"))
        #expect(rows.contains("axLine: 42"))
        #expect(rows.contains("method: ax-selected-text"))
    }

    @Test("what the capture did not see is written as none rather than left out")
    func rowsWithNothing() {
        let rows = report(focusedRole: .none, documentPath: .none, windowTitle: .none, axLine: .none)
            .rows
        #expect(rows.contains("focusedRole: none"))
        #expect(rows.contains("documentPath: none"))
        #expect(rows.contains("windowTitle: none"))
        #expect(rows.contains("sourceURL: none"))
        #expect(rows.contains("axLine: none"))
        #expect(rows.contains("screenFrame: none"))
    }

    @Test("the frame of the selection is written as a position and a size")
    func frame() {
        let frame = CGRect(x: 100.4, y: 200.6, width: 300.2, height: 40.9)
        #expect(report(screenFrame: frame).rows.contains("screenFrame: 100,200 300x40"))
    }

    @Test("the log always says the same number of things")
    func rowCount() {
        #expect(report().rows.count == 12)
    }

    @Test("with no permission the advice is to grant it")
    func adviceWithoutPermission() {
        let advice = report(trusted: false).advice
        #expect(advice.contains("Accessibility"))
        #expect(advice.contains("System Settings"))
    }

    @Test("an app that answered nothing at all is named in the advice")
    func adviceWhenNothingAnswered() {
        let advice = report(axSelectedLength: 0, clipboardLength: 0).advice
        #expect(advice.hasPrefix("Xcode returned no selected text"))
        #expect(advice.contains("Comment on this window"))
    }

    @Test("an app that answered with an empty selection gets the shorter advice")
    func adviceWhenSelectionEmpty() {
        let advice = report(axSelectedLength: 0, clipboardLength: 12).advice
        #expect(advice.hasPrefix("The selection was empty."))
        #expect(advice.contains("Comment on this window"))
    }

    @Test("no permission is said before anything else, because nothing works without it")
    func adviceOrder() {
        let advice = report(trusted: false, axSelectedLength: 0, clipboardLength: 0).advice
        #expect(advice.contains("no Accessibility permission"))
    }
}

@Suite("Diagnostics")
struct DiagnosticsTests {
    @Test("the log is the file the app owns, not one in a project")
    func url() {
        let url = Diagnostics().url
        #expect(url.lastPathComponent == "diagnostics.log")
        #expect(url.path.contains("com.nandzz.koment"))
    }
}
