import AppKit
import SwiftUI

struct HelpSection {
    let title: String
    let lines: [String]
}

enum HelpBook {
    static func sections(chord: String, terminalApp: String) -> [HelpSection] {
        [
            HelpSection(
                title: "What the app does",
                lines: [
                    "You select code in any editor and write a note about it. The note goes into a "
                        + "database the app owns, never into your project. Claude Code reads the "
                        + "notes through an MCP server and applies them in the right repository.",
                    "The app never talks to your editor, so it works in Xcode, VS Code, Cursor, "
                        + "and anything else that shows text."
                ]
            ),
            HelpSection(
                title: "1 — Write a comment",
                lines: [
                    "· Save the file, then select the lines you want to speak about.",
                    "· Press ⌘C twice quickly, or press \(chord).",
                    "· Type the note in the panel that opens.",
                    "· With nothing selected the app says so, and offers Comment on this window — "
                        + "a note about the page or the conversation in front of you, saved "
                        + "without a line.",
                    "· return saves the note. shift-return adds a line. esc cancels."
                ]
            ),
            HelpSection(
                title: "2 — How the app finds the file",
                lines: [
                    "The app cannot ask an editor which line is selected. It reads the selected "
                        + "text and resolves the location itself, most exact first. The Status "
                        + "column of the Dashboard shows which step succeeded:",
                    "· ax-exact — the editor gave the file and the line.",
                    "· document-search — the editor gave the file; the text gave the line.",
                    "· document-only — the editor gave the file; no line matched.",
                    "· title-search — the window title gave the file name.",
                    "· repo-search — a search of your roots found the text.",
                    "· unresolved — no file was found. The comment is saved without a project.",
                    "Keep roots in config.json short. A wide root makes the search slow."
                ]
            ),
            HelpSection(
                title: "3 — Run the comments",
                lines: [
                    "· Open the Dashboard from the menu bar.",
                    "· Select one comment or several, then press Run in Claude, or ⌘R.",
                    "· A tab opens in the terminal panel at the bottom of the window, one tab per "
                        + "project. Claude starts in the project directory and receives the "
                        + "comments you selected.",
                    "· Type in the panel exactly as you type in a terminal.",
                    "· A tab stays after the session ends. Press Restart to run it again, or "
                        + "Close to remove it.",
                    "· Press Terminal in the toolbar to show or hide the panel. Drag the divider "
                        + "to change its height.",
                    "· The sessions keep running when you close the Dashboard window, and stop "
                        + "when you quit the app."
                ]
            ),
            HelpSection(
                title: "4 — What closes a comment",
                lines: [
                    "The /koment command closes each comment it applies, and the Dashboard "
                        + "shows the change at once. You can also press Resolve in the Dashboard "
                        + "to close a comment yourself, and Reopen to bring it back."
                ]
            ),
            HelpSection(
                title: "Run the comments yourself",
                lines: [
                    "You do not need the Dashboard. In any Claude Code session:",
                    "· /koment — the open comments of the current repository.",
                    "· /koment here — the same as /koment.",
                    "· /koment all — the open comments of every project."
                ]
            ),
            HelpSection(
                title: "Keys in the Dashboard",
                lines: [
                    "· ⌘R runs the selected comments in Claude.",
                    "· return opens the file at the line.",
                    "· delete removes the selected comments.",
                    "· Right-click a row for every action, including Copy file path."
                ]
            ),
            HelpSection(
                title: "Configuration",
                lines: [
                    "The file is config.json, in the application support folder. Choose Reload "
                        + "configuration from the menu after you change it.",
                    "· roots — the folders the file search looks in.",
                    "· hotkeyKey and hotkeyModifiers — the shortcut, \(chord) today.",
                    "· doubleTapCopy — set it to false to leave ⌘C alone.",
                    "· embeddedTerminal — set it to false to run Claude in \(terminalApp) "
                        + "instead of the panel.",
                    "· terminalApp — the app that opens when embeddedTerminal is false."
                ]
            ),
            HelpSection(
                title: "When something does not work",
                lines: [
                    "· No selection captured — open Setup… and allow Accessibility.",
                    "· The comment has no project — add the folder to roots in config.json.",
                    "· Claude does not start — open Setup… and check the Claude Code connection.",
                    "· Open diagnostics log in the menu shows what the last capture read."
                ]
            )
        ]
    }
}

struct HelpView: View {
    let chord: String
    let terminalApp: String

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.wideGap) {
                ForEach(HelpBook.sections(chord: chord, terminalApp: terminalApp), id: \.title) { section in
                    HelpSectionView(section: section)
                }
            }
            .padding(theme.gutter)
            .padding(.top, theme.titlebarInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HelpSectionView: View {
    let section: HelpSection

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.smallGap) {
            Text(section.title)
                .font(theme.title)
            ForEach(section.lines, id: \.self) { line in
                Text(line)
                    .font(theme.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(theme.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: theme.cardRadius))
    }
}

final class HelpWindowController: NSWindowController {
    init(chord: String, terminalApp: String) {
        let theme = Theme()
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: theme.readingWidth,
                height: theme.readingHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "How Koment works"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(
            width: theme.readingMinimumWidth,
            height: theme.readingMinimumHeight
        )
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = NSHostingView(
            rootView: AnyView(
                HelpView(chord: chord, terminalApp: terminalApp).environment(\.theme, theme)
            )
        )
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(.none)
        window?.makeKeyAndOrderFront(.none)
    }
}
