import AppKit
import KomentCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let shell = Shell()
    private let selectionCapture = SelectionCapture()
    private let hotkeyManager = HotkeyManager()
    private let panelController = CommentPanelController()
    private let diagnostics = Diagnostics()
    private let signal = ChangeSignal()
    private let paths = Paths()
    private var config = ConfigLoader().load()
    private var statusItem: NSStatusItem?
    private var copyTap: CopyTapMonitor?
    private var triggerItems: [NSMenuItem] = []
    private var store: CommentStore?
    private var dashboard: DashboardWindowController?
    private var setupController: SetupWindowController?
    private var helpController: HelpWindowController?

    private var resolver: Resolver {
        Resolver(shell: shell, roots: config.expandedRoots)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let store = openStore() else {
            NSApp.terminate(.none)
            return
        }
        self.store = store
        dashboard = DashboardWindowController(store: store)
        applyConfiguration()

        buildStatusItem()
        if !hotkeyManager.register(config: config, action: { [weak self] in self?.newComment() }) {
            present(title: "Shortcut not registered", message: "Another app may hold \(hotkeyManager.describe(config)).")
        }

        copyTap = CopyTapMonitor { [weak self] in self?.newComment() }
        startCopyTap()

        signal.observe { [weak self] in self?.dashboard?.reload() }
        showSetupIfNeeded()
    }

    private func openStore() -> CommentStore? {
        do {
            try paths.prepare()
            return CommentStore(database: try Database(url: paths.databaseURL))
        } catch {
            present(title: "Could not open the comment database", message: "\(error)")
            return .none
        }
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusItemImage()
        item.menu = buildMenu()
        statusItem = item
    }

    private func statusItemImage() -> NSImage? {
        let fallback = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Comments")
        guard let image = NSImage(named: "komment-icon") else { return fallback }
        let height: CGFloat = 18
        let width = image.size.height > 0 ? height * image.size.width / image.size.height : height
        image.size = NSSize(width: width, height: height)
        image.isTemplate = true
        image.accessibilityDescription = "Comments"
        return image
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        triggerItems = (0..<2).map { _ in
            let item = NSMenuItem(title: "", action: .none, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return item
        }
        refreshTriggerLines()
        menu.addItem(.separator())

        menu.addItem(withTitle: "Dashboard…", action: #selector(showDashboard), keyEquivalent: "d")
        menu.addItem(withTitle: "Setup…", action: #selector(showSetup), keyEquivalent: "")
        menu.addItem(withTitle: "How it works…", action: #selector(showHelp), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Reveal database in Finder", action: #selector(revealDatabase), keyEquivalent: "")
        menu.addItem(withTitle: "Open diagnostics log", action: #selector(openDiagnostics), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Reload configuration", action: #selector(reloadConfiguration), keyEquivalent: "")
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items where item.action != .none {
            item.target = self
        }
        return menu
    }

    private func refreshTriggerLines() {
        let chord = hotkeyManager.describe(config)
        let lines: [String]
        if !config.doubleTapCopy {
            lines = ["Select code, then press \(chord)", ""]
        } else if copyTap?.isRunning == true {
            lines = ["Select code, then double-tap ⌘C", "or press \(chord)"]
        } else {
            lines = ["Select code, then press \(chord)", "double-tap ⌘C needs Accessibility permission"]
        }
        for (item, line) in zip(triggerItems, lines) {
            item.title = line
            item.isHidden = line.isEmpty
        }
    }

    private func startCopyTap() {
        guard config.doubleTapCopy else {
            copyTap?.stop()
            return
        }
        _ = copyTap?.start()
    }

    func menuWillOpen(_ menu: NSMenu) {
        startCopyTap()
        refreshTriggerLines()
    }

    private func newComment() {
        if !selectionCapture.isTrusted {
            selectionCapture.requestTrust()
        }
        let outcome = selectionCapture.capture()
        guard let capture = outcome.capture else {
            diagnostics.append(outcome.report.rows + ["outcome: no selection captured"])
            offerWindowComment(report: outcome.report)
            return
        }
        let location = resolver.resolve(capture)
        let resolved = location.map { "\($0.absolutePath):\($0.lineSpan) (\($0.confidence))" } ?? "unresolved"
        diagnostics.append(outcome.report.rows + ["resolved: \(resolved)"])
        panelController.show(capture: capture, location: location) { [weak self] note in
            self?.save(note: note, capture: capture, location: location)
        }
    }

    private func offerWindowComment(report: CaptureReport) {
        let alert = NSAlert()
        alert.messageText = "No selection captured"
        alert.informativeText = report.advice
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if report.trusted {
            alert.addButton(withTitle: "Comment on this window")
        }
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }

        let capture = windowCapture(from: report)
        diagnostics.append(report.rows + ["outcome: comment on the window"])
        panelController.show(capture: capture, location: .none) { [weak self] note in
            self?.save(note: note, capture: capture, location: .none)
        }
    }

    private func windowCapture(from report: CaptureReport) -> Capture {
        Capture(
            selectedText: "",
            appName: report.appName,
            documentPath: report.documentPath,
            windowTitle: report.windowTitle,
            bundleIdentifier: report.bundleIdentifier,
            sourceURL: report.sourceURL,
            screenFrame: report.screenFrame,
            method: "window"
        )
    }

    private func save(note: String, capture: Capture, location: Location?) {
        guard let store else { return }
        do {
            try store.insert(comment(note: note, capture: capture, location: location))
            signal.post()
            dashboard?.reload()
        } catch {
            present(title: "Could not save the comment", message: "\(error)")
        }
    }

    private func comment(note: String, capture: Capture, location: Location?) -> InlineComment {
        let anchor = location.map { resolver.anchor(for: capture, at: $0) }
            ?? CommentAnchor(
                selectedText: capture.selectedText,
                before: [],
                after: [],
                blob: .none,
                confidence: "unresolved"
            )
        return InlineComment(
            id: UUID().uuidString,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            status: .open,
            note: note,
            projectRoot: location?.repoRoot ?? "",
            file: location?.relativePath ?? "",
            path: location?.absolutePath ?? capture.documentPath ?? "",
            line: location?.line ?? 0,
            endLine: location?.endLine ?? 0,
            anchor: anchor,
            capturedIn: capture.appName,
            method: capture.method,
            windowTitle: capture.windowTitle ?? "",
            bundleIdentifier: capture.bundleIdentifier ?? "",
            sourceURL: capture.sourceURL ?? ""
        )
    }

    private func setup() -> SetupWindowController {
        if let setupController { return setupController }
        let controller = SetupWindowController(steps: [
            ClaudeCodeConnection(),
            AccessibilityPermission(capture: selectionCapture),
            CommandInstallation()
        ])
        setupController = controller
        return controller
    }

    private func showSetupIfNeeded() {
        let controller = setup()
        guard !controller.isComplete else { return }
        controller.show()
    }

    @objc private func showSetup() {
        setup().show()
    }

    @objc private func showDashboard() {
        dashboard?.show()
    }

    @objc private func showHelp() {
        help().show()
    }

    private func help() -> HelpWindowController {
        if let helpController { return helpController }
        let controller = HelpWindowController(
            chord: hotkeyManager.describe(config),
            terminalApp: config.terminalApp
        )
        helpController = controller
        return controller
    }

    @objc private func revealDatabase() {
        NSWorkspace.shared.selectFile(
            paths.databaseURL.path,
            inFileViewerRootedAtPath: paths.supportDirectory.path
        )
    }

    @objc private func openDiagnostics() {
        let url = diagnostics.url
        if !FileManager.default.fileExists(atPath: url.path) {
            diagnostics.append(["outcome: log created, no capture yet"])
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(.none)
    }

    func applicationWillTerminate(_ notification: Notification) {
        dashboard?.terminateSessions()
    }

    @objc private func reloadConfiguration() {
        config = ConfigLoader().load()
        startCopyTap()
        statusItem?.menu = buildMenu()
        helpController?.close()
        helpController = .none
        applyConfiguration()
        dashboard?.reload()
    }

    private func applyConfiguration() {
        dashboard?.terminalApp = config.terminalApp
        dashboard?.fallbackRoot = config.expandedRoots.first ?? ""
        dashboard?.embeddedTerminal = config.embeddedTerminal
    }

    private func present(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
