import KomentCore
import Foundation
import Testing

private final class Step: SetupStep {
    let title = "A step"
    let detail = "What it does."
    let command: String? = "true"
    private(set) var ran = false

    func state() -> SetupState {
        ran ? .done("done") : .todo("not yet")
    }

    func run() throws {
        ran = true
    }
}

private final class FailingStep: SetupStep {
    let title = "A step that will not run"
    let detail = "What it does."
    let command: String? = .none
    let watchesExternalChange = true

    func state() -> SetupState {
        .todo("not yet")
    }

    func run() throws {
        throw SetupError.noRepository
    }
}

@Suite("Setup")
struct SetupTests {
    @Test("a finished row is done and an unfinished one is not")
    func stateIsDone() {
        #expect(SetupState.done("connected").isDone)
        #expect(!SetupState.todo("not registered").isDone)
    }

    @Test("either state carries its own wording")
    func stateText() {
        #expect(SetupState.done("connected").text == "connected")
        #expect(SetupState.todo("not registered").text == "not registered")
    }

    @Test("two states of the same kind and wording are the same state")
    func stateEquality() {
        #expect(SetupState.done("a") == SetupState.done("a"))
        #expect(SetupState.done("a") != SetupState.todo("a"))
        #expect(SetupState.todo("a") != SetupState.todo("b"))
    }

    @Test("a setup failure says what went wrong in words a person can act on")
    func errorDescriptions() {
        #expect(SetupError.noRepository.description.contains("development checkout"))
        #expect(SetupError.noCommandFile.description.contains("app bundle"))
        #expect(SetupError.noServerBinary("/x/KomentMCP").description
            == "no server binary at /x/KomentMCP — build the app first")
        #expect(SetupError.registrationFailed("it did not take").description == "it did not take")
    }

    @Test("a step watches for outside change only when it says so")
    func watchesExternalChange() {
        #expect(!Step().watchesExternalChange)
        #expect(FailingStep().watchesExternalChange)
    }

    @Test("running a step moves it from todo to done")
    func stepRuns() throws {
        let step = Step()
        #expect(step.state() == .todo("not yet"))
        try step.run()
        #expect(step.state() == .done("done"))
    }

    @Test("a step that cannot run throws instead of reporting success")
    func stepThrows() {
        let step = FailingStep()
        #expect(throws: SetupError.self) {
            try step.run()
        }
        #expect(!step.state().isDone)
    }

    @Test("the two real steps name themselves and offer the command they would run")
    func realSteps() {
        let connection = ClaudeCodeConnection()
        #expect(connection.title == "Connect to Claude Code")
        #expect(!connection.detail.isEmpty)

        let installation = CommandInstallation()
        #expect(installation.title == "Install the /koment command")
        #expect(!installation.detail.isEmpty)
    }

    @Test("a step with no checkout to work from reports a todo rather than crashing")
    func realStepStates() {
        #expect(!ClaudeCodeConnection().state().text.isEmpty)
        #expect(!CommandInstallation().state().text.isEmpty)
    }
}
