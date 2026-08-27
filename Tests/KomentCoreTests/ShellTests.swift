import KomentCore
import Foundation
import Testing

@Suite("Shell")
struct ShellTests {
    let shell = Shell()
    let space = Workspace()

    @Test("a command that works reports success and its output")
    func success() {
        let outcome = shell.execute(["echo", "hello"])
        #expect(outcome.succeeded)
        #expect(outcome.status == 0)
        #expect(outcome.output == "hello\n")
        #expect(outcome.error.isEmpty)
    }

    @Test("a command that fails reports its status")
    func failure() {
        let outcome = shell.execute(["false"])
        #expect(!outcome.succeeded)
        #expect(outcome.status == 1)
    }

    @Test("what a command writes to standard error is kept apart")
    func standardError() {
        let outcome = shell.execute(["sh", "-c", "echo out; echo problem 1>&2"])
        #expect(outcome.output == "out\n")
        #expect(outcome.error == "problem\n")
    }

    @Test("a command that does not exist fails rather than throwing")
    func missingCommand() {
        let outcome = shell.execute(["koment-no-such-command"])
        #expect(!outcome.succeeded)
    }

    @Test("a command runs in the directory it is given")
    func directory() {
        let outcome = shell.execute(["pwd"], in: space.directory.path)
        let reported = URL(
            fileURLWithPath: outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        #expect(reported.resolvingSymlinksInPath().path
            == space.directory.resolvingSymlinksInPath().path)
    }

    @Test("output of a failed command is dropped rather than returned half-read")
    func runDropsFailure() {
        #expect(shell.run(["sh", "-c", "echo half; exit 3"]).isEmpty)
        #expect(shell.run(["echo", "whole"]) == "whole\n")
    }

    @Test("the trimmed form loses the trailing newline a command leaves behind")
    func trimmed() {
        #expect(shell.trimmed(["echo", "  padded  "]) == "padded")
        #expect(shell.trimmed(["false"]).isEmpty)
    }

    @Test("an argument holding a space stays one argument")
    func argumentWithSpace() {
        #expect(shell.trimmed(["echo", "-n", "one two"]) == "one two")
    }
}
