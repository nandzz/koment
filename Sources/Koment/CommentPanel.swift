import AppKit
import SwiftUI

final class NoteTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36, !event.modifierFlags.contains(.shift) {
            onSubmit?()
            return
        }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}

struct NoteField: NSViewRepresentable {
    @Binding var text: String
    var focusOnAppear = false
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let note = NoteTextView()
        note.font = NSFont.systemFont(ofSize: 13)
        note.isRichText = false
        note.isEditable = true
        note.isSelectable = true
        note.allowsUndo = true
        note.isVerticallyResizable = true
        note.isHorizontallyResizable = false
        note.autoresizingMask = [.width]
        note.drawsBackground = false
        note.textContainerInset = NSSize(width: 6, height: 8)
        note.delegate = context.coordinator
        note.string = text

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = note

        if focusOnAppear {
            DispatchQueue.main.async {
                note.window?.makeFirstResponder(note)
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let note = scroll.documentView as? NoteTextView else { return }
        if note.string != text {
            note.string = text
        }
        note.onSubmit = onSubmit
        note.onCancel = onCancel
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            text.wrappedValue = view.string
        }
    }
}

struct CommentPanelView: View {
    let capture: Capture
    let location: Location?
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @State private var note = ""
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.gap) {
            header
            path
            snippet
            editor
            footer
        }
        .padding(.horizontal, theme.cardInset)
        .padding(.top, theme.titlebarInset)
        .padding(.bottom, theme.panelBottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(revealed ? 1 : 0)
        .onAppear {
            withAnimation(theme.morph) { revealed = true }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.wideGap) {
            Text(titleText)
                .font(theme.monoStrong)
                .foregroundStyle(location == .none ? theme.warn : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text(metaText)
                .font(theme.monoTiny)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var path: some View {
        Text(pathText)
            .font(theme.monoSmall)
            .foregroundStyle(location == .none ? theme.warn : Color.secondary)
            .lineLimit(1)
            .truncationMode(.head)
            .textSelection(.enabled)
            .help(pathText)
    }

    private var snippet: some View {
        Text(capture.snippetText)
            .font(theme.mono)
            .foregroundStyle(.secondary)
            .lineLimit(theme.snippetLines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.smallGap)
            .background(.quaternary.opacity(theme.softFill), in: .rect(cornerRadius: theme.boxRadius))
    }

    private var editor: some View {
        NoteField(
            text: $note,
            focusOnAppear: true,
            onSubmit: submit,
            onCancel: onCancel
        )
        .frame(minHeight: theme.noteMinimumHeight, maxHeight: .infinity)
        .padding(theme.tightGap)
        .background(.quaternary.opacity(theme.softFill), in: .rect(cornerRadius: theme.boxRadius))
    }

    private var footer: some View {
        HStack(spacing: theme.gap) {
            Text("return  save     shift-return  new line     esc  cancel")
                .font(theme.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Button("Cancel", action: onCancel)
                .buttonStyle(.glass)
            Button("Save", action: submit)
                .buttonStyle(.glassProminent)
                .disabled(trimmedNote.isEmpty)
        }
        .controlSize(.small)
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleText: String {
        if let location { return "\(location.fileName):\(location.lineSpan)" }
        return capture.isWindowNote ? "Comment on this window" : "No file resolved"
    }

    private var metaText: String {
        let confidence = location?.confidence ?? "unresolved"
        return "\(confidence)  ·  \(capture.appName)  ·  \(capture.method)"
    }

    private var pathText: String {
        if let location { return location.absolutePath }
        guard capture.isWindowNote else {
            return "saved without a file — find it in the history window"
        }
        return capture.documentPath
            ?? capture.sourceURL
            ?? capture.bundleIdentifier
            ?? capture.appName
    }

    private func submit() {
        let note = trimmedNote
        guard !note.isEmpty else {
            onCancel()
            return
        }
        onSave(note)
    }
}

extension Capture {
    var snippetText: String {
        if isWindowNote {
            return windowTitle ?? "no text was selected — this note is about the window"
        }
        let body = lines.prefix(3)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        guard lines.count > 3 else { return body }
        return body + "   (+\(lines.count - 3) more lines)"
    }
}

final class CommentPanelController {
    private let theme = Theme()
    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    func show(capture: Capture, location: Location?, onSave: @escaping (String) -> Void) {
        close()
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: theme.panelWidth, height: theme.panelMinimumHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Comment for Claude"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: theme.panelMinimumWidth, height: theme.panelMinimumHeight)

        let view = CommentPanelView(
            capture: capture,
            location: location,
            onSave: { [weak self] note in
                onSave(note)
                self?.close()
            },
            onCancel: { [weak self] in self?.close() }
        )
        let hosting = NSHostingView(rootView: AnyView(view.environment(\.theme, theme)))
        hosting.frame = NSRect(x: 0, y: 0, width: theme.panelWidth, height: theme.panelMinimumHeight)
        hosting.layoutSubtreeIfNeeded()
        let height = max(theme.panelMinimumHeight, hosting.fittingSize.height)

        hosting.sizingOptions = []

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        panel.contentView = background

        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)

        panel.setContentSize(NSSize(width: theme.panelWidth, height: height))
        place(panel, near: capture.screenFrame, over: capture.isWindowNote)

        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(.none)
    }

    private func place(_ panel: NSPanel, near anchor: CGRect?, over: Bool) {
        let size = panel.frame.size
        guard let anchor, let screen = screen(holding: anchor) else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let centred = over || anchor.height > visible.height / 2
        let gap = theme.panelGap

        var origin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: centred ? anchor.midY - size.height / 2 : anchor.minY - gap - size.height
        )
        if !centred, origin.y < visible.minY + gap {
            origin.y = anchor.maxY + gap
        }
        origin.x = min(max(origin.x, visible.minX + gap), visible.maxX - size.width - gap)
        origin.y = min(max(origin.y, visible.minY + gap), visible.maxY - size.height - gap)
        panel.setFrameOrigin(origin)
    }

    private func screen(holding anchor: CGRect) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main
    }

    private func close() {
        panel?.orderOut(.none)
        panel = .none
        previousApp?.activate(options: [])
        previousApp = .none
    }
}
