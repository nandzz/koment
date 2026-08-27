@testable import Koment
import Foundation
import Testing

@Suite("FileOpener")
struct FileOpenerTests {
    let opener = FileOpener()

    @Test("every editor the app knows has its own address scheme")
    func schemes() {
        #expect(opener.scheme(for: "Code") == "vscode")
        #expect(opener.scheme(for: "Visual Studio Code") == "vscode")
        #expect(opener.scheme(for: "Code - Insiders") == "vscode-insiders")
        #expect(opener.scheme(for: "Cursor") == "cursor")
        #expect(opener.scheme(for: "Windsurf") == "windsurf")
        #expect(opener.scheme(for: "Zed") == "zed")
        #expect(opener.scheme(for: "Zed Preview") == "zed")
    }

    @Test("the editor name is read whatever way it is capitalised")
    func schemesIgnoreCase() {
        #expect(opener.scheme(for: "code") == "vscode")
        #expect(opener.scheme(for: "CURSOR") == "cursor")
    }

    @Test("an app the opener does not know has no scheme of its own")
    func unknownScheme() {
        #expect(opener.scheme(for: "Xcode") == .none)
        #expect(opener.scheme(for: "Slack") == .none)
        #expect(opener.scheme(for: "") == .none)
    }

    @Test("an editor address carries the file and the line")
    func editorURL() throws {
        let url = try #require(
            opener.editorURL(path: "/Users/you/app/Bar.swift", line: 42, scheme: "vscode")
        )
        #expect(url.absoluteString == "vscode://file/Users/you/app/Bar.swift:42")
    }

    @Test("a space in a path does not break the address")
    func editorURLWithSpace() throws {
        let url = try #require(
            opener.editorURL(path: "/Users/you/my app/Bar.swift", line: 7, scheme: "cursor")
        )
        #expect(url.absoluteString == "cursor://file/Users/you/my%20app/Bar.swift:7")
    }

    @Test("no scheme means no address to open")
    func editorURLWithoutScheme() {
        #expect(opener.editorURL(path: "/a/b.swift", line: 1, scheme: .none)?.scheme == .none)
    }

    @Test("a comment with no file cannot be opened")
    func openWithoutFile() {
        #expect(!opener.open(sample(projectRoot: "", file: "", path: "")))
    }

    @Test("a comment whose file has gone cannot be opened")
    func openMissingFile() {
        #expect(!opener.open(sample(path: "/nowhere/at/all/Bar.swift")))
    }
}
