import AppKit
import KomentCore
import SwiftUI

final class AccessibilityPermission: SetupStep {
    private let capture: SelectionCapture

    init(capture: SelectionCapture) {
        self.capture = capture
    }

    var title: String {
        "Allow Accessibility"
    }

    var detail: String {
        "Lets the app read the text you selected in any editor, and watch for the double-tap "
            + "of ⌘C. Without it there is nothing to attach a note to."
    }

    var command: String? {
        .none
    }

    var watchesExternalChange: Bool {
        true
    }

    func state() -> SetupState {
        capture.isTrusted ? .done("allowed") : .todo("not allowed")
    }

    func run() throws {
        capture.requestTrust()
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct SetupRow: Identifiable {
    let id: String
    let step: SetupStep
    let state: SetupState
}

struct SetupFailure: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

@Observable
final class SetupModel {
    let steps: [SetupStep]
    var failure: SetupFailure?
    private(set) var states: [String: SetupState] = [:]

    init(steps: [SetupStep]) {
        self.steps = steps
        refresh(watchedOnly: false)
    }

    var isComplete: Bool {
        steps.allSatisfy { $0.state().isDone }
    }

    var rows: [SetupRow] {
        steps.map { step in
            SetupRow(id: step.title, step: step, state: states[step.title] ?? step.state())
        }
    }

    func refresh(watchedOnly: Bool) {
        for step in steps where !watchedOnly || step.watchesExternalChange {
            states[step.title] = step.state()
        }
    }

    func run(_ step: SetupStep) {
        do {
            try step.run()
        } catch {
            failure = SetupFailure(title: "\(step.title) did not finish", detail: "\(error)")
        }
        refresh(watchedOnly: false)
    }
}

struct SetupView: View {
    @Bindable var model: SetupModel

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.wideGap) {
                Text("Three things to switch on")
                    .font(theme.heading)
                Text(
                    "Nothing here runs until you press its button. Your comments live in a "
                    + "database the app owns; none of them is written into your projects."
                )
                .font(theme.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                ForEach(model.rows) { row in
                    SetupStepView(
                        step: row.step,
                        state: row.state,
                        onRun: { model.run(row.step) }
                    )
                }
            }
            .padding(theme.gutter)
            .padding(.top, theme.titlebarInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.refresh(watchedOnly: true)
            }
        }
        .alert(
            model.failure?.title ?? "",
            isPresented: failureShown,
            presenting: model.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.detail)
        }
    }

    private var failureShown: Binding<Bool> {
        Binding(
            get: { model.failure != .none },
            set: { shown in
                guard !shown else { return }
                model.failure = .none
            }
        )
    }
}

struct SetupStepView: View {
    let step: SetupStep
    let state: SetupState
    let onRun: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.smallGap) {
            HStack(alignment: .firstTextBaseline, spacing: theme.gap) {
                Text(step.title)
                    .font(theme.title)
                Text(state.text)
                    .font(theme.label)
                    .foregroundStyle(state.isDone ? theme.good : theme.warn)
                Spacer(minLength: 0)
                if state.isDone {
                    Button("Set up again", action: onRun)
                        .buttonStyle(.glass)
                        .controlSize(.small)
                } else {
                    Button("Set up", action: onRun)
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                }
            }
            Text(step.detail)
                .font(theme.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let command = step.command {
                Text(command)
                    .font(theme.monoSmall)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(theme.gap)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(theme.softFill), in: .rect(cornerRadius: theme.boxRadius))
            }
        }
        .padding(theme.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: theme.cardRadius))
    }
}

final class SetupWindowController: NSWindowController, NSWindowDelegate {
    private let model: SetupModel

    init(steps: [SetupStep]) {
        let theme = Theme()
        model = SetupModel(steps: steps)
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: theme.readingWidth,
                height: theme.readingHeight
            ),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Koment setup"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(
            width: theme.readingMinimumWidth,
            height: theme.readingMinimumHeight
        )
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: AnyView(SetupView(model: model).environment(\.theme, theme))
        )
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    var isComplete: Bool {
        model.isComplete
    }

    func show() {
        model.refresh(watchedOnly: false)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(.none)
        window?.makeKeyAndOrderFront(.none)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refresh(watchedOnly: false)
    }
}
