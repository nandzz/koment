import AppKit
import KomentCore
import SwiftUI

struct DashboardView: View {
    @Bindable var model: DashboardModel

    @Environment(\.theme) private var theme
    @Namespace private var glass
    @FocusState private var searchFocused: Bool
    @State private var gripStart: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                toolbar
                table
                CommentDetailView(model: model, openShortcut: openShortcut, deleteShortcut: deleteShortcut)
                    .padding(.horizontal, theme.gutter)
                if model.terminalShown {
                    grip(in: proxy.size.height)
                    TerminalPanelView(model: model.terminal) { model.toggleTerminal() }
                        .frame(height: model.terminalHeight)
                        .padding(.horizontal, theme.gutter)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, theme.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(theme.morph, value: model.terminalShown)
        .onChange(of: model.query) { model.reload() }
        .onChange(of: model.sortOrder) { model.applySort() }
        .sheet(item: $model.editing) { comment in
            NoteEditorSheet(comment: comment) { note in
                model.save(note: note, for: comment)
            }
        }
        .alert(
            model.prompt?.title ?? "",
            isPresented: promptShown,
            presenting: model.prompt
        ) { prompt in
            switch prompt {
            case .message:
                Button("OK", role: .cancel) {}
            case .confirm(_, _, let button, let action):
                Button(button, role: .destructive) { model.perform(action) }
                Button("Cancel", role: .cancel) {}
            }
        } message: { prompt in
            Text(prompt.detail)
        }
    }

    private var promptShown: Binding<Bool> {
        Binding(
            get: { model.prompt != .none },
            set: { shown in
                guard !shown else { return }
                model.prompt = .none
            }
        )
    }

    private var openShortcut: KeyboardShortcut? {
        searchFocused ? .none : KeyboardShortcut(.return, modifiers: [])
    }

    private var deleteShortcut: KeyboardShortcut? {
        searchFocused ? .none : KeyboardShortcut(.delete, modifiers: [])
    }

    private var toolbar: some View {
        HStack(spacing: theme.gap) {
            filterChips
            searchField
            Text(model.summaryText)
                .font(theme.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { model.toggleTerminal() } label: {
                Label(model.terminalTitle, systemImage: "apple.terminal")
            }
            .buttonStyle(.glass)
            .help("Show or hide the terminal panel")
            Button("Delete shown…") { model.confirmDeleteShown() }
                .buttonStyle(.glass)
                .disabled(model.rows.isEmpty)
            Button { model.reload() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .help("Reload")
            Button { model.runSelection() } label: {
                Label(model.runTitle, systemImage: "play.fill")
                    .symbolEffect(.bounce, options: .nonRepeating, value: model.selection.count)
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!model.hasSelection)
        }
        .controlSize(.small)
        .padding(.horizontal, theme.gutter)
        .padding(.top, theme.titlebarInset)
        .padding(.bottom, theme.gap)
    }

    private var filterChips: some View {
        GlassEffectContainer(spacing: theme.tightGap) {
            HStack(spacing: theme.tightGap) {
                ForEach(CommentFilter.allCases, id: \.self) { option in
                    Button { model.select(option) } label: {
                        Text(option.title)
                            .font(theme.label)
                            .padding(.horizontal, theme.gap)
                            .padding(.vertical, theme.smallGap)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.filter == option ? Color.primary : Color.secondary)
                    .glassEffect(
                        model.filter == option
                            ? .regular.tint(theme.accent.opacity(theme.chipTint)).interactive()
                            : .regular.interactive(),
                        in: .capsule
                    )
                    .glassEffectID(option, in: glass)
                }
            }
        }
        .animation(theme.snap, value: model.filter)
    }

    private var searchField: some View {
        HStack(spacing: theme.smallGap) {
            Image(systemName: "magnifyingglass")
                .font(theme.caption)
                .foregroundStyle(.secondary)
            TextField("Note, file, project, app or window", text: $model.query)
                .textFieldStyle(.plain)
                .font(theme.caption)
                .focused($searchFocused)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, theme.gap)
        .padding(.vertical, theme.smallGap)
        .glassEffect(.regular, in: .capsule)
        .frame(width: theme.searchWidth)
    }

    private var table: some View {
        Table(model.rows, selection: $model.selection, sortOrder: $model.sortOrder) {
            TableColumn("When", value: \.createdAt) { comment in
                CommentCellView(primary: comment.whenText, secondary: "")
            }
            .width(min: theme.whenColumn.minimum, ideal: theme.whenColumn.ideal, max: theme.whenColumn.maximum)

            TableColumn("Status", value: \.statusText) { comment in
                CommentCellView(
                    primary: comment.statusText,
                    secondary: comment.anchor.confidence,
                    tint: theme.tint(comment.status)
                )
            }
            .width(min: theme.statusColumn.minimum, ideal: theme.statusColumn.ideal, max: theme.statusColumn.maximum)

            TableColumn("Project", value: \.projectName) { comment in
                CommentCellView(primary: comment.projectName, secondary: comment.projectFolder)
                    .help(comment.projectRoot)
            }
            .width(min: theme.projectColumn.minimum, ideal: theme.projectColumn.ideal, max: theme.projectColumn.maximum)

            TableColumn("App", value: \.capturedIn) { comment in
                CommentCellView(primary: comment.capturedIn, secondary: comment.method)
            }
            .width(min: theme.appColumn.minimum, ideal: theme.appColumn.ideal, max: theme.appColumn.maximum)

            TableColumn("File", value: \.fileLabel) { comment in
                CommentCellView(primary: comment.fileLabel, secondary: comment.folderText)
                    .help(comment.originText)
            }
            .width(min: theme.fileColumn.minimum, ideal: theme.fileColumn.ideal, max: theme.fileColumn.maximum)

            TableColumn("Note", value: \.note) { comment in
                CommentCellView(primary: comment.note, secondary: "")
                    .help(comment.note)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(maxHeight: .infinity)
        .overlay {
            if model.rows.isEmpty {
                Text(model.emptyText)
                    .font(theme.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: theme.emptyWidth)
            }
        }
        .contextMenu(forSelectionType: InlineComment.ID.self) { ids in
            rowMenu(ids)
        } primaryAction: { ids in
            model.selection = ids
            model.open(ids)
        }
    }

    @ViewBuilder
    private func rowMenu(_ ids: Set<InlineComment.ID>) -> some View {
        if ids.isEmpty {
            Button("Delete all shown…") { model.confirmDeleteShown() }
                .disabled(model.rows.isEmpty)
        } else {
            Group {
                Button(model.runTitle(for: ids)) { act(ids) { model.runSelection() } }
                Divider()
                Button("Open file") { act(ids) { model.openSelection() } }
                Button("Reveal in Finder") { act(ids) { model.reveal() } }
            }
            Group {
                Divider()
                Button("Edit note…") { act(ids) { model.edit() } }
                Button(model.resolveTitle(for: ids)) { act(ids) { model.toggleResolution() } }
            }
            Group {
                Divider()
                Button("Copy file path") { act(ids) { model.copyPath() } }
                Button("Copy note") { act(ids) { model.copyNote() } }
            }
            Group {
                Divider()
                Button("Delete comment…") { act(ids) { model.confirmDeleteSelection() } }
                Button("Delete all shown…") { model.confirmDeleteShown() }
            }
        }
    }

    private func act(_ ids: Set<InlineComment.ID>, work: () -> Void) {
        model.selection = ids
        work()
    }

    private func grip(in available: CGFloat) -> some View {
        Capsule()
            .fill(.tertiary)
            .frame(width: theme.gripWidth, height: theme.gripThickness)
            .frame(maxWidth: .infinity)
            .frame(height: theme.gripHeight)
            .contentShape(.rect)
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = gripStart ?? model.terminalHeight
                        gripStart = start
                        model.setTerminalHeight(
                            start - value.translation.height,
                            limit: available - theme.commentsMinimumHeight
                        )
                    }
                    .onEnded { _ in gripStart = .none }
            )
    }
}

struct CommentCellView: View {
    let primary: String
    var secondary = ""
    var tint: Color?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.hairGap) {
            Text(primary)
                .font(theme.monoSmall)
                .foregroundStyle(tint ?? Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            if !secondary.isEmpty {
                Text(secondary)
                    .font(theme.monoTiny)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CommentDetailView: View {
    let model: DashboardModel
    let openShortcut: KeyboardShortcut?
    let deleteShortcut: KeyboardShortcut?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.tightGap) {
            if let comment = model.selected.first {
                Text(comment.note)
                    .font(theme.strongBody)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text(comment.originText)
                    .font(theme.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .textSelection(.enabled)
                Text(comment.metaText)
                    .font(theme.monoSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(comment.snippetSummary)
                    .font(theme.monoSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            } else {
                Text(model.rows.isEmpty ? "" : "Select a comment to read it in full.")
                    .font(theme.strongBody)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: theme.detailHeight)
        .padding(theme.cardInset)
        .glassEffect(.regular, in: .rect(cornerRadius: theme.cardRadius))
    }

    private var actions: some View {
        HStack(spacing: theme.smallGap) {
            Button("Open file") { model.openSelection() }
                .keyboardShortcut(openShortcut)
                .disabled(!model.hasFile)
            Button("Edit note…") { model.edit() }
                .disabled(!model.hasSelection)
            Button(model.resolveTitle) { model.toggleResolution() }
                .disabled(!model.hasSelection)
            Button("Delete…") { model.confirmDeleteSelection() }
                .keyboardShortcut(deleteShortcut)
                .disabled(!model.hasSelection)
            Spacer(minLength: 0)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
    }
}

struct NoteEditorSheet: View {
    let comment: InlineComment
    let onSave: (String) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(comment: InlineComment, onSave: @escaping (String) -> Void) {
        self.comment = comment
        self.onSave = onSave
        _note = State(initialValue: comment.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.smallGap) {
            Text("Edit note")
                .font(theme.title)
            Text(comment.originText)
                .font(theme.monoSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .textSelection(.enabled)
            NoteField(text: $note, focusOnAppear: true, onSubmit: submit, onCancel: { dismiss() })
                .frame(height: theme.sheetNoteHeight)
                .padding(theme.tightGap)
                .background(.quaternary.opacity(theme.softFill), in: .rect(cornerRadius: theme.boxRadius))
            HStack(spacing: theme.gap) {
                Text("return  save     shift-return  new line     esc  cancel")
                    .font(theme.caption)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glass)
                Button("Save", action: submit)
                    .buttonStyle(.glassProminent)
                    .disabled(trimmed.isEmpty)
            }
            .controlSize(.small)
        }
        .padding(theme.gutter)
        .frame(width: theme.sheetWidth)
    }

    private var trimmed: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        let note = trimmed
        guard !note.isEmpty else {
            dismiss()
            return
        }
        onSave(note)
        dismiss()
    }
}
