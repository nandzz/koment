@testable import Koment
import KomentCore
import Foundation
import Testing

@Suite("ClaudeRunner")
struct ClaudeRunnerTests {
    let space: Workspace
    let runner: ClaudeRunner

    init() {
        space = Workspace()
        runner = ClaudeRunner(terminalApp: "Terminal", fallbackRoot: space.root)
    }

    private var stranded: ClaudeRunner {
        ClaudeRunner(terminalApp: "Terminal", fallbackRoot: "")
    }

    @Test("comments of one project make one group")
    func oneProject() {
        let groups = runner.groups(for: [
            sample(id: "a", projectRoot: "/one"),
            sample(id: "b", projectRoot: "/one")
        ])
        #expect(groups.count == 1)
        #expect(groups[0].root == "/one")
        #expect(groups[0].comments.map(\.id) == ["a", "b"])
        #expect(groups[0].anchored)
    }

    @Test("comments of three projects make three groups, in the order they were selected")
    func threeProjects() {
        let groups = runner.groups(for: [
            sample(id: "a", projectRoot: "/two"),
            sample(id: "b", projectRoot: "/one"),
            sample(id: "c", projectRoot: "/two")
        ])
        #expect(groups.map(\.root) == ["/two", "/one"])
        #expect(groups[0].comments.map(\.id) == ["a", "c"])
        #expect(groups[1].comments.map(\.id) == ["b"])
    }

    @Test("no comments make no groups")
    func noComments() {
        #expect(runner.groups(for: []).isEmpty)
    }

    @Test("comments with no project run together from the first configured root")
    func unanchoredGroup() {
        let groups = runner.groups(for: [
            sample(id: "a", projectRoot: "/one"),
            sample(id: "b", projectRoot: ""),
            sample(id: "c", projectRoot: "")
        ])
        #expect(groups.count == 2)
        #expect(groups[1].root == space.root)
        #expect(!groups[1].anchored)
        #expect(groups[1].comments.map(\.id) == ["b", "c"])
    }

    @Test("the unanchored group comes after every project")
    func unanchoredGroupIsLast() {
        let groups = runner.groups(for: [
            sample(id: "a", projectRoot: ""),
            sample(id: "b", projectRoot: "/one")
        ])
        #expect(groups.map(\.anchored) == [true, false])
    }

    @Test("nothing is left out when there is a folder to start in")
    func nothingSkipped() {
        let comments = [sample(id: "a", projectRoot: ""), sample(id: "b", projectRoot: "/one")]
        #expect(runner.skipped(from: comments).isEmpty)
    }

    @Test("with no folder to start in, the comments with no project are left out")
    func skippedWithoutRoot() {
        let comments = [sample(id: "a", projectRoot: ""), sample(id: "b", projectRoot: "/one")]
        #expect(stranded.skipped(from: comments).map(\.id) == ["a"])
        #expect(stranded.groups(for: comments).map(\.root) == ["/one"])
    }

    @Test("a root that names a file rather than a folder is no root at all")
    func rootIsAFile() {
        let path = space.file("not-a-folder.txt", "x")
        let runner = ClaudeRunner(terminalApp: "Terminal", fallbackRoot: path)
        #expect(runner.skipped(from: [sample(id: "a", projectRoot: "")]).map(\.id) == ["a"])
    }

    @Test("a root that is not there is no root at all")
    func rootIsMissing() {
        let runner = ClaudeRunner(terminalApp: "Terminal", fallbackRoot: "/nowhere/at/all")
        #expect(runner.skipped(from: [sample(id: "a", projectRoot: "")]).map(\.id) == ["a"])
    }

    @Test("a group is named after its project")
    func groupName() {
        let group = RunGroup(root: "/Users/you/Workspace/app", comments: [], anchored: true)
        #expect(group.name == "app")
    }

    @Test("a group with no project says so")
    func unanchoredGroupName() {
        let group = RunGroup(root: "/Users/you/Workspace", comments: [], anchored: false)
        #expect(group.name == "no project")
    }

    @Test("the script starts a login shell in the project and hands the ids to the command")
    func script() {
        let group = RunGroup(
            root: "/Users/you/Workspace/app",
            comments: [sample(id: "9C1F"), sample(id: "A4B2")],
            anchored: true
        )
        let script = runner.script(for: group, claude: "/Users/you/.local/bin/claude")

        #expect(script.hasPrefix("#!/bin/zsh\n"))
        #expect(script.contains("cd \"/Users/you/Workspace/app\" || exit 1"))
        #expect(script.contains("exec \"/Users/you/.local/bin/claude\" \"/koment 9C1F A4B2\""))
        #expect(script.hasSuffix("\n"))
    }

    @Test("a project whose name would break the script is quoted safely")
    func scriptEscapesTheRoot() {
        let group = RunGroup(
            root: "/Users/you/my \"odd\" $project",
            comments: [sample(id: "a")],
            anchored: true
        )
        let script = runner.script(for: group, claude: "/bin/claude")
        #expect(script.contains("cd \"/Users/you/my \\\"odd\\\" \\$project\""))
    }

    @Test("the characters a shell would read are all escaped")
    func escaped() {
        #expect(runner.escaped("plain") == "plain")
        #expect(runner.escaped("a\"b") == "a\\\"b")
        #expect(runner.escaped("a$b") == "a\\$b")
        #expect(runner.escaped("a`b") == "a\\`b")
        #expect(runner.escaped("a\\b") == "a\\\\b")
        #expect(runner.escaped("~/Desktop/Workspace/app") == "~/Desktop/Workspace/app")
    }

    @Test("the script file is named after the project and the first comment")
    func filename() {
        let group = RunGroup(
            root: "/Users/you/Workspace/app",
            comments: [sample(id: "9C1F2345")],
            anchored: true
        )
        let name = runner.filename(for: group)
        #expect(name.hasPrefix("app-"))
        #expect(name.hasSuffix("-9C1F.command"))
    }

    @Test("a project name a file system would refuse is turned into one it accepts")
    func filenameSanitised() {
        let group = RunGroup(
            root: "/Users/you/Workspace/my odd project!",
            comments: [sample(id: "abcd")],
            anchored: true
        )
        #expect(runner.filename(for: group).hasPrefix("my-odd-project-"))
    }

    @Test("the unanchored group has a name of its own")
    func filenameUnanchored() {
        let group = RunGroup(root: "/Users/you", comments: [sample(id: "abcd")], anchored: false)
        #expect(runner.filename(for: group).hasPrefix("no-project-"))
    }

    @Test("a group with no comments still gets a file name")
    func filenameWithoutComments() {
        let group = RunGroup(root: "/Users/you/app", comments: [], anchored: true)
        #expect(runner.filename(for: group).hasSuffix("-0000.command"))
    }

    @Test("a project named only in punctuation falls back to a name that works")
    func filenameFromPunctuation() {
        let group = RunGroup(root: "/Users/you/...", comments: [sample(id: "abcd")], anchored: true)
        #expect(runner.filename(for: group).hasPrefix("project-"))
    }

    @Test("nothing selected prepares nothing and reports no failure")
    func prepareNothing() {
        let preparation = runner.prepare([])
        #expect(preparation.launches.isEmpty)
        #expect(preparation.skipped.isEmpty)
        #expect(preparation.failure == .none)
    }

    @Test("comments that cannot run report the reason rather than failing silently")
    func prepareStranded() {
        let preparation = stranded.prepare([sample(id: "a", projectRoot: "")])
        #expect(preparation.launches.isEmpty)
        #expect(preparation.skipped.map(\.id) == ["a"])
        #expect(preparation.failure == .none)
    }

    @Test("an outcome carries what ran, what was left and what went wrong")
    func outcome() {
        let outcome = RunOutcome(sessions: 2, skipped: [sample(id: "a")], failure: "it broke")
        #expect(outcome.sessions == 2)
        #expect(outcome.skipped.map(\.id) == ["a"])
        #expect(outcome.failure == "it broke")
    }
}
