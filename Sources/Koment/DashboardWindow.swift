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
            contentRect: NSRect(origin: .zero, size: openingSize()),
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
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.managed)
        window.isReleasedWhenClosed = false
        window.delegate = self

        let hosting = NSHostingView(
            rootView: AnyView(DashboardView(model: model).environment(\.theme, theme))
        )
        hosting.sizingOptions = []
        window.contentView = hosting
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

    private func openingSize() -> NSSize {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
        guard let visible else {
            return NSSize(width: theme.windowWidth, height: theme.windowHeight)
        }
        return NSSize(
            width: min(theme.windowWidth, visible.width - theme.gutter * 2),
            height: min(theme.windowHeight, visible.height - theme.gutter * 2)
        )
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame: NSRect) -> NSRect {
        window.screen?.visibleFrame ?? defaultFrame
    }

    func windowWillClose(_ notification: Notification) {
        model.windowClosed()
    }
}
