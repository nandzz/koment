import AppKit
import KomentCore
import SwiftUI

final class DashboardWindowController: NSObject, NSWindowDelegate {
    let store: CommentStore

    var terminalApp: String {
        get { model.terminalApp }
        set { model.terminalApp = newValue }
    }

    var fallbackRoot: String {
        get { model.fallbackRoot }
        set { model.fallbackRoot = newValue }
    }

    var embeddedTerminal: Bool {
        get { model.embeddedTerminal }
        set { model.embeddedTerminal = newValue }
    }

    var runningSessions: Int {
        model.terminal.runningCount
    }

    private let theme: Theme
    private let model: DashboardModel
    private var window: NSWindow?

    init(store: CommentStore) {
        let theme = Theme()
        self.store = store
        self.theme = theme
        model = DashboardModel(store: store, theme: theme)
        super.init()
    }

    func show() {
        if let window {
            model.isShowing = true
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(.none)
            model.reload()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: theme.windowWidth,
                height: theme.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Dashboard"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(
            width: theme.windowMinimumWidth,
            height: theme.windowMinimumHeight
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: AnyView(DashboardView(model: model).environment(\.theme, theme))
        )
        window.center()

        self.window = window
        model.isShowing = true

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(.none)
        model.reload()
    }

    func reload() {
        model.reload()
    }

    func terminateSessions() {
        model.terminal.terminateAll()
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame: NSRect) -> NSRect {
        window.screen?.visibleFrame ?? defaultFrame
    }

    func windowWillClose(_ notification: Notification) {
        model.windowClosed()
    }
}
