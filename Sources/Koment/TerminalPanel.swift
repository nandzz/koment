import AppKit
import SwiftTerm
import SwiftUI

enum SessionState {
    case running
    case ended(Int32?)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

@Observable
final class TerminalSession: Identifiable {
    let id = UUID().uuidString
    let name: String
    let root: String
    let script: URL
    let comments: Int
    @ObservationIgnored let view: LocalProcessTerminalView
    var state: SessionState = .running

    init(name: String, root: String, script: URL, comments: Int, view: LocalProcessTerminalView) {
        self.name = name
        self.root = root
        self.script = script
        self.comments = comments
        self.view = view
    }

    var summary: String {
        switch state {
        case .running:
            return comments == 1 ? "1 comment · running" : "\(comments) comments · running"
        case .ended(.none):
            return "the session stopped before it could report an exit code"
        case .ended(.some(let code)):
            return code == 0 ? "finished" : "finished with code \(code)"
        }
    }
}

@Observable
final class TerminalModel: LocalProcessTerminalViewDelegate {
    private(set) var sessions: [TerminalSession] = []
    var selectedID: String?

    var count: Int {
        sessions.count
    }

    var runningCount: Int {
        sessions.filter { $0.state.isRunning }.count
    }

    var selected: TerminalSession? {
        sessions.first { $0.id == selectedID }
    }

    var statusText: String {
        selected?.summary ?? "No session running."
    }

    func start(_ launch: RunLaunch) {
        let terminal = makeTerminal()
        let session = TerminalSession(
            name: launch.group.name,
            root: launch.group.root,
            script: launch.script,
            comments: launch.group.comments.count,
            view: terminal
        )
        sessions.append(session)
        selectedID = session.id
        run(session)
    }

    func select(_ id: String) {
        guard selectedID != id else { return }
        selectedID = id
    }

    func close(_ id: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let session = sessions.remove(at: index)
        if session.state.isRunning {
            session.view.terminate()
        }
        session.view.removeFromSuperview()
        if selectedID == id {
            selectedID = sessions[safe: index]?.id ?? sessions.last?.id
        }
    }

    func closeSelected() {
        guard let selectedID else { return }
        close(selectedID)
    }

    func restartSelected() {
        guard let session = selected, !session.state.isRunning else { return }
        session.view.feed(text: "\r\n")
        run(session)
        focus()
    }

    func closeAll() {
        for session in sessions where session.state.isRunning {
            session.view.terminate()
        }
        for session in sessions {
            session.view.removeFromSuperview()
        }
        sessions = []
        selectedID = .none
    }

    func terminateAll() {
        for session in sessions where session.state.isRunning {
            session.view.terminate()
        }
    }

    func focus() {
        guard let terminal = selected?.view else { return }
        terminal.window?.makeFirstResponder(terminal)
    }

    func refreshColours(for appearance: NSAppearance) {
        appearance.performAsCurrentDrawingAppearance {
            for session in sessions {
                session.view.configureNativeColors()
            }
        }
    }

    private func makeTerminal() -> LocalProcessTerminalView {
        var options = TerminalOptions.default
        options.scrollback = 5_000
        let terminal = LocalProcessTerminalView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 360),
            font: monospaceFont,
            options: options
        )
        terminal.processDelegate = self
        terminal.configureNativeColors()
        terminal.optionAsMetaKey = true
        return terminal
    }

    private var monospaceFont: NSFont {
        NSFont(name: "SF Mono", size: 12)
            ?? NSFont(name: "Menlo", size: 12)
            ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    private func run(_ session: TerminalSession) {
        session.state = .running
        session.view.startProcess(
            executable: "/bin/zsh",
            args: ["-l", session.script.path],
            environment: environment(),
            currentDirectory: session.root
        )
    }

    private func environment() -> [String] {
        var values = ProcessInfo.processInfo.environment
        values["TERM"] = "xterm-256color"
        values["COLORTERM"] = "truecolor"
        values["TERM_PROGRAM"] = "Koment"
        if values["LANG"] == .none {
            values["LANG"] = "en_US.UTF-8"
        }
        return values.map { "\($0.key)=\($0.value)" }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard let session = sessions.first(where: { $0.view === source }) else { return }
        session.state = .ended(exitCode)
        session.view.feed(text: "\r\n\u{1b}[2m\(endNote(exitCode))\u{1b}[0m\r\n")
    }

    private func endNote(_ exitCode: Int32?) -> String {
        guard let exitCode else { return "— the session stopped —" }
        return exitCode == 0
            ? "— the session finished. Press Restart to run it again. —"
            : "— the session finished with code \(exitCode). Press Restart to run it again. —"
    }
}

final class TerminalStageView: NSView {
    var onAppearanceChange: ((NSAppearance) -> Void)?

    override func layout() {
        super.layout()
        for view in subviews {
            view.frame = bounds
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?(effectiveAppearance)
    }
}

struct TerminalStage: NSViewRepresentable {
    let terminal: LocalProcessTerminalView?
    let onAppearanceChange: (NSAppearance) -> Void

    func makeNSView(context: Context) -> TerminalStageView {
        let stage = TerminalStageView()
        stage.wantsLayer = true
        return stage
    }

    func updateNSView(_ stage: TerminalStageView, context: Context) {
        stage.onAppearanceChange = onAppearanceChange
        for view in stage.subviews where view !== terminal {
            view.removeFromSuperview()
        }
        guard let terminal, terminal.superview !== stage else { return }
        terminal.frame = stage.bounds
        stage.addSubview(terminal)
        stage.layoutSubtreeIfNeeded()
        terminal.window?.makeFirstResponder(terminal)
    }
}

struct TerminalTabView: View {
    let session: TerminalSession
    let selected: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.smallGap) {
            Circle()
                .fill(dotColour)
                .frame(width: theme.dotSize, height: theme.dotSize)
            Text(session.name)
                .font(theme.label)
                .foregroundStyle(selected ? SwiftUI.Color.primary : SwiftUI.Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.closeGlyph, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Close this session")
        }
        .padding(.horizontal, theme.smallGap)
        .padding(.vertical, theme.tightGap)
        .frame(maxWidth: theme.tabMaximumWidth)
        .glassEffect(
            selected
                ? .regular.tint(theme.accent.opacity(theme.chipTint)).interactive()
                : .regular.interactive(),
            in: .rect(cornerRadius: theme.tabRadius)
        )
        .glassEffectID(session.id, in: namespace)
        .onTapGesture(perform: onSelect)
        .help("\(session.root)\n\(session.summary)")
    }

    private var dotColour: SwiftUI.Color {
        switch session.state {
        case .running: return theme.good
        case .ended(.some(0)): return .secondary
        case .ended: return theme.bad
        }
    }
}

struct TerminalPanelView: View {
    let model: TerminalModel
    let onHide: () -> Void

    @Environment(\.theme) private var theme
    @Namespace private var glass

    var body: some View {
        VStack(spacing: 0) {
            bar
            TerminalStage(
                terminal: model.selected?.view,
                onAppearanceChange: { model.refreshColours(for: $0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.quaternary.opacity(theme.softFill), in: .rect(cornerRadius: theme.boxRadius))
    }

    private var bar: some View {
        HStack(spacing: theme.gap) {
            GlassEffectContainer(spacing: theme.tightGap) {
                HStack(spacing: theme.tightGap) {
                    ForEach(model.sessions) { session in
                        TerminalTabView(
                            session: session,
                            selected: session.id == model.selectedID,
                            namespace: glass,
                            onSelect: { model.select(session.id) },
                            onClose: { model.close(session.id) }
                        )
                    }
                }
            }
            .animation(theme.snap, value: model.selectedID)

            Text(model.statusText)
                .font(theme.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            Button("Restart") { model.restartSelected() }
                .buttonStyle(.glass)
                .disabled(model.selected.map { $0.state.isRunning } ?? true)
            Button("Close") { model.closeSelected() }
                .buttonStyle(.glass)
                .disabled(model.selectedID == .none)
            Button(action: onHide) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.glass)
            .help("Hide the terminal")
        }
        .controlSize(.small)
        .padding(.horizontal, theme.gap)
        .padding(.vertical, theme.smallGap)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : .none
    }
}
