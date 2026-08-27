@testable import Koment
import KomentCore
import Foundation
import Testing

@Suite("CommentPresentation")
struct CommentPresentationTests {
    private var home: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    @Test("the status column shows the word the database holds")
    func statusText() {
        #expect(sample(status: .drifted).statusText == "drifted")
    }

    @Test("the project column is the folder name")
    func projectName() {
        #expect(sample(projectRoot: "/Users/you/Workspace/app").projectName == "app")
    }

    @Test("a comment with no project shows a dash rather than an empty cell")
    func projectNameEmpty() {
        #expect(sample(projectRoot: "").projectName == "—")
    }

    @Test("the folder above the project is shown short, with the home folder as a tilde")
    func projectFolder() {
        #expect(sample(projectRoot: home + "/Workspace/app").projectFolder == "~/Workspace")
    }

    @Test("a project at the root of the disk shows the root")
    func projectFolderAtRoot() {
        #expect(sample(projectRoot: "/app").projectFolder == "/")
    }

    @Test("a comment with no project says so where the folder would be")
    func projectFolderEmpty() {
        #expect(sample(projectRoot: "").projectFolder == "no project")
    }

    @Test("the file column is the file name")
    func fileName() {
        #expect(sample(file: "Sources/Foo/Bar.swift").fileName == "Bar.swift")
    }

    @Test("a comment with no file says it is unanchored")
    func fileNameEmpty() {
        #expect(sample(file: "").fileName == "unanchored")
    }

    @Test("the file label carries the line span when there is one")
    func fileLabel() {
        #expect(sample(file: "a/Bar.swift", line: 42, endLine: 44).fileLabel == "Bar.swift:42-44")
        #expect(sample(file: "a/Bar.swift", line: 42, endLine: 42).fileLabel == "Bar.swift:42")
    }

    @Test("a comment with no line shows the file name alone")
    func fileLabelWithoutSpan() {
        #expect(sample(file: "a/Bar.swift", line: 0, endLine: 0).fileLabel == "Bar.swift")
    }

    @Test("a file inside the project shows its folder relative to the project")
    func folderText() {
        let comment = sample(
            projectRoot: "/Users/you/Workspace/app",
            path: "/Users/you/Workspace/app/Sources/Foo/Bar.swift"
        )
        #expect(comment.folderText == "Sources/Foo")
    }

    @Test("a file at the top of the project says so")
    func folderTextAtRoot() {
        let comment = sample(
            projectRoot: "/Users/you/Workspace/app",
            path: "/Users/you/Workspace/app/Package.swift"
        )
        #expect(comment.folderText == "repository root")
    }

    @Test("a file outside its project shows the whole folder, shortened")
    func folderTextOutside() {
        let comment = sample(projectRoot: "/Users/you/other", path: home + "/elsewhere/Bar.swift")
        #expect(comment.folderText == "~/elsewhere")
    }

    @Test("a comment with no file shows the window it came from")
    func folderTextFromWindow() {
        let comment = sample(
            projectRoot: "",
            file: "",
            path: "",
            windowTitle: "#checkout (TheFork) - Slack"
        )
        #expect(comment.folderText == "#checkout (TheFork) - Slack")
    }

    @Test("a comment with neither a file nor a window title says there is no file")
    func folderTextWithNothing() {
        #expect(sample(projectRoot: "", file: "", path: "", windowTitle: "").folderText == "no file")
    }

    @Test("where a comment came from is the path and the lines when there is a file")
    func originText() {
        let comment = sample(path: "/a/Bar.swift", line: 42, endLine: 44)
        #expect(comment.originText == "/a/Bar.swift:42-44")
    }

    @Test("a file with no line span shows the path alone")
    func originTextWithoutSpan() {
        #expect(sample(path: "/a/Bar.swift", line: 0, endLine: 0).originText == "/a/Bar.swift")
    }

    @Test("a comment from a web page shows the address")
    func originTextFromURL() {
        let comment = sample(
            projectRoot: "",
            file: "",
            path: "",
            windowTitle: "A ticket",
            sourceURL: "https://notion.so/page"
        )
        #expect(comment.originText == "https://notion.so/page")
    }

    @Test("a comment from a chat shows the window title")
    func originTextFromWindow() {
        let comment = sample(
            projectRoot: "",
            file: "",
            path: "",
            windowTitle: "#checkout - Slack",
            sourceURL: ""
        )
        #expect(comment.originText == "#checkout - Slack")
    }

    @Test("a comment taken today says today")
    func whenToday() {
        #expect(sample(createdAt: stamp(Date())).whenText.hasPrefix("today "))
    }

    @Test("a comment taken yesterday says yesterday")
    func whenYesterday() {
        let yesterday = Date().addingTimeInterval(-86_400)
        #expect(sample(createdAt: stamp(yesterday)).whenText.hasPrefix("yesterday "))
    }

    @Test("a comment from another day this year shows the day and the time, not the year")
    func whenThisYear() throws {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var components = DateComponents()
        components.year = year
        components.month = calendar.component(.month, from: Date()) >= 4 ? 1 : 12
        components.day = 15
        components.hour = 12
        let date = try #require(calendar.date(from: components))

        let text = sample(createdAt: stamp(date)).whenText
        #expect(!text.hasPrefix("today"))
        #expect(!text.hasPrefix("yesterday"))
        #expect(text.contains(":"))
        #expect(!text.contains(String(year)))
    }

    @Test("a comment from another year shows the year")
    func whenAnotherYear() throws {
        let date = try #require(Calendar.current.date(byAdding: .year, value: -2, to: Date()))
        let year = Calendar.current.component(.year, from: date)
        #expect(sample(createdAt: stamp(date)).whenText.contains(String(year)))
    }

    @Test("a stamp that is not a date is shown as it stands")
    func whenUnparsable() {
        #expect(sample(createdAt: "last tuesday").whenText == "last tuesday")
    }

    @Test("the detail line carries the status, the confidence and the app")
    func metaText() {
        let text = sample(status: .open, confidence: "ax-exact", capturedIn: "Xcode").metaText
        #expect(text.contains("open"))
        #expect(text.contains("ax-exact"))
        #expect(text.contains("captured in Xcode"))
        #expect(text.contains("created "))
    }

    @Test("the detail line names the window when there is one")
    func metaTextWithWindow() {
        let text = sample(capturedIn: "Slack", windowTitle: "#checkout - Slack").metaText
        #expect(text.contains("captured in Slack — #checkout - Slack"))
    }

    @Test("the detail line of a closed comment says when it closed and what changed")
    func metaTextClosed() {
        let text = sample(
            status: .resolved,
            resolvedAt: "2026-08-26T09:00:00Z",
            resolution: "used the token"
        ).metaText
        #expect(text.contains("closed "))
        #expect(text.contains("used the token"))
    }

    @Test("a closed comment with nothing recorded does not show an empty resolution")
    func metaTextWithoutResolution() {
        let text = sample(status: .resolved, resolvedAt: "2026-08-26T09:00:00Z", resolution: "")
            .metaText
        #expect(!text.hasSuffix("·  "))
    }

    @Test("the snippet shows at most the first two lines with something on them")
    func snippetSummary() {
        let comment = sample(selectedText: "  first\n\n  second  \n  third")
        #expect(comment.snippetSummary == "first  ⏎  second")
    }

    @Test("a snippet of one line has no join in it")
    func snippetSummarySingle() {
        #expect(sample(selectedText: "  only  ").snippetSummary == "only")
    }

    @Test("an empty snippet stays empty")
    func snippetSummaryEmpty() {
        #expect(sample(selectedText: "\n \n").snippetSummary.isEmpty)
    }

    @Test("the filter searches the note, the file, the project, the app, the window and the address")
    func searchHaystack() {
        let haystack = sample(
            note: "the note",
            projectRoot: "/Users/you/Workspace/app",
            path: "/Users/you/Workspace/app/Bar.swift",
            capturedIn: "Xcode",
            windowTitle: "the window",
            sourceURL: "https://notion.so/page"
        ).searchHaystack

        #expect(haystack.contains("the note"))
        #expect(haystack.contains("Bar.swift"))
        #expect(haystack.contains("app"))
        #expect(haystack.contains("Xcode"))
        #expect(haystack.contains("the window"))
        #expect(haystack.contains("notion.so"))
    }

    @Test("a short note is shown whole")
    func noteExcerptShort() {
        #expect(sample(note: "short").noteExcerpt == "short")
    }

    @Test("a note of exactly eighty characters is shown whole")
    func noteExcerptAtLimit() {
        let note = String(repeating: "a", count: 80)
        #expect(sample(note: note).noteExcerpt == note)
    }

    @Test("a long note is cut with an ellipsis")
    func noteExcerptLong() {
        let excerpt = sample(note: String(repeating: "a", count: 200)).noteExcerpt
        #expect(excerpt.count == 81)
        #expect(excerpt.hasSuffix("…"))
    }
}

@Suite("String presentation")
struct StringPresentationTests {
    @Test("a path inside the home folder is shown with a tilde")
    func abbreviated() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect((home + "/Workspace/app").abbreviatedPath == "~/Workspace/app")
        #expect(home.abbreviatedPath == "~")
    }

    @Test("a path outside the home folder is left alone")
    func abbreviatedOutside() {
        #expect("/usr/local/bin".abbreviatedPath == "/usr/local/bin")
    }

    @Test("a stamp is shown as a day and a time")
    func stampText() {
        let text = "2026-08-26T09:00:00Z".stampText
        #expect(text != "2026-08-26T09:00:00Z")
        #expect(text.contains("2026"))
    }

    @Test("something that is not a stamp is shown as it stands")
    func stampTextUnparsable() {
        #expect("not a date".stampText == "not a date")
        #expect("".stampText.isEmpty)
    }
}
