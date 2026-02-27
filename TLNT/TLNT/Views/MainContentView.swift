//
//  MainContentView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainContentView: View {
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var tabStore: TabStore
    @State private var searchText = ""
    @State private var isComposing = false
    @State private var composeText = ""
    @State private var isAddingTab = false
    @State private var newTabName = ""
    @State private var editingTab: Tab? = nil
    @State private var editingTabName = ""
    @FocusState private var isComposeFocused: Bool

    // Selection state
    @State private var selectedNoteIds: Set<UUID> = []
    @State private var isMarqueeSelecting = false
    @State private var marqueeStart: CGPoint = .zero
    @State private var marqueeEnd: CGPoint = .zero

    // Drag and drop state
    @State private var draggedNote: Note?
    @State private var isTargetedForDrop = false

    private var homeTabId: UUID? {
        tabStore.tabs.first { $0.isHome }?.id
    }

    private var filteredNotes: [Note] {
        let tabNotes = noteStore.notes(forTabId: tabStore.activeTabId, homeTabId: homeTabId)
        let sorted = tabNotes.sorted { $0.createdAt > $1.createdAt }

        if searchText.isEmpty {
            return sorted
        }

        return sorted.filter { note in
            switch note.type {
            case .text:
                return note.content.localizedCaseInsensitiveContains(searchText)
            case .screenshot, .recording:
                return note.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            Divider()

            // Search bar with compose button
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 20)

                // Compose button - creates inline editable bubble
                Button(action: { isComposing = true }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add a note")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if filteredNotes.isEmpty && searchText.isEmpty && !isComposing {
                emptyState
            } else if filteredNotes.isEmpty && !isComposing {
                noResultsState
            } else {
                notesGrid
            }

            // Batch action bar - appears when notes are selected
            if !selectedNoteIds.isEmpty {
                batchActionBar
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Batch Action Bar

    private var batchActionBar: some View {
        HStack(spacing: 16) {
            Text("\(selectedNoteIds.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: copySelectedNotes) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button(action: deleteSelectedNotes) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)

            Button(action: { selectedNoteIds.removeAll() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear selection")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }

    private func copySelectedNotes() {
        let selectedNotes = noteStore.notes.filter { selectedNoteIds.contains($0.id) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Collect text content and file URLs
        var textContent: [String] = []
        var fileURLs: [NSURL] = []

        for note in selectedNotes {
            switch note.type {
            case .text:
                textContent.append(note.content)
            case .screenshot, .recording:
                let url = URL(fileURLWithPath: note.content)
                fileURLs.append(url as NSURL)
            }
        }

        // Write to pasteboard
        if !textContent.isEmpty {
            pasteboard.setString(textContent.joined(separator: "\n\n"), forType: .string)
        }
        if !fileURLs.isEmpty {
            pasteboard.writeObjects(fileURLs)
        }

        selectedNoteIds.removeAll()
    }

    private func deleteSelectedNotes() {
        withAnimation {
            for noteId in selectedNoteIds {
                if let note = noteStore.note(withId: noteId) {
                    noteStore.delete(note)
                }
            }
            selectedNoteIds.removeAll()
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabStore.tabs) { tab in
                    tabButton(for: tab)
                }

                // Add tab button
                Button(action: { isAddingTab = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isAddingTab) {
                    addTabPopover
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func tabButton(for tab: Tab) -> some View {
        let isActive = tab.id == tabStore.activeTabId
        let targetTabId: UUID? = tab.isHome ? nil : tab.id

        return Button(action: { tabStore.setActiveTab(tab) }) {
            HStack(spacing: 6) {
                if tab.isHome {
                    Image(systemName: "house.fill")
                        .font(.system(size: 11))
                }
                Text(tab.name)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isActive ? .accentColor : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .dropDestination(for: Note.self) { notes, _ in
            // Move dropped notes to this tab
            for note in notes {
                noteStore.moveNote(note, toTabId: targetTabId)
            }
            return true
        } isTargeted: { isTargeted in
            // Visual feedback could be added here
        }
        .contextMenu {
            if !tab.isHome {
                Button("Rename") {
                    editingTab = tab
                    editingTabName = tab.name
                }
                Divider()
                Button("Delete Tab and Contents", role: .destructive) {
                    // Delete all notes in this tab first
                    noteStore.deleteNotesForTab(tab.id)
                    // Then delete the tab
                    tabStore.delete(tab)
                }
            }
        }
        .popover(isPresented: Binding(
            get: { editingTab?.id == tab.id },
            set: { if !$0 { editingTab = nil } }
        )) {
            renameTabPopover(for: tab)
        }
    }

    private var addTabPopover: some View {
        VStack(spacing: 12) {
            Text("New Tab")
                .font(.headline)

            TextField("Tab name", text: $newTabName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit {
                    addTab()
                }

            HStack {
                Button("Cancel") {
                    newTabName = ""
                    isAddingTab = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addTab()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTabName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    private func renameTabPopover(for tab: Tab) -> some View {
        VStack(spacing: 12) {
            Text("Rename Tab")
                .font(.headline)

            TextField("Tab name", text: $editingTabName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit {
                    renameTab(tab)
                }

            HStack {
                Button("Cancel") {
                    editingTab = nil
                    editingTabName = ""
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    renameTab(tab)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editingTabName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    private func addTab() {
        let name = newTabName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let tab = tabStore.add(name: name)
        tabStore.setActiveTab(tab)
        newTabName = ""
        isAddingTab = false
    }

    private func renameTab(_ tab: Tab) {
        let name = editingTabName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        tabStore.rename(tab, to: name)
        editingTab = nil
        editingTabName = ""
    }

    // MARK: - Compose Bubble

    private var composeBubble: some View {
        ComposeBubbleView(
            text: $composeText,
            isComposing: $isComposing,
            onSave: { saveComposedNote() },
            onCancel: {
                composeText = ""
                isComposing = false
            }
        )
        .frame(minHeight: 36, maxHeight: 150)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
        )
    }

    private func saveComposedNote() {
        let text = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Determine the tab ID - use active tab, or nil for home tab
        let tabId: UUID? = tabStore.activeTab?.isHome == true ? nil : tabStore.activeTabId

        let note = Note(type: .text, content: text, tabId: tabId)
        noteStore.add(note)
        composeText = ""
        isComposing = false
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No notes yet")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HotkeyHint(keys: "⌘⇧S", description: "Send screenshot")
                HotkeyHint(keys: "⌘⇧K", description: "Capture text")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No results for \"\(searchText)\"")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Notes Grid

    private var marqueeRect: CGRect {
        CGRect(
            x: min(marqueeStart.x, marqueeEnd.x),
            y: min(marqueeStart.y, marqueeEnd.y),
            width: abs(marqueeEnd.x - marqueeStart.x),
            height: abs(marqueeEnd.y - marqueeStart.y)
        )
    }

    private var notesGrid: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Compose bubble above the grid when composing
                        if isComposing {
                            composeBubble
                        }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 350), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(filteredNotes) { note in
                            SelectableNoteItemView(
                                note: note,
                                isSelected: selectedNoteIds.contains(note.id),
                                selectedCount: selectedNoteIds.count,
                                onSelect: { toggleSelection(note) },
                                onDelete: {
                                    withAnimation {
                                        noteStore.delete(note)
                                        selectedNoteIds.remove(note.id)
                                    }
                                },
                                onDeleteSelected: {
                                    deleteSelectedNotes()
                                },
                                onUpdate: { newContent in
                                    noteStore.update(note, content: newContent)
                                }
                            )
                            .draggable(note)
                            .background(
                                GeometryReader { noteGeometry in
                                    Color.clear
                                        .preference(
                                            key: NoteFramePreferenceKey.self,
                                            value: [note.id: noteGeometry.frame(in: .named("gridSpace"))]
                                        )
                                }
                            )
                            .dropDestination(for: Note.self) { droppedNotes, _ in
                                // Reorder: move dropped note before this note
                                if let droppedNote = droppedNotes.first, droppedNote.id != note.id {
                                    noteStore.reorderNote(droppedNote, before: note)
                                    return true
                                }
                                return false
                            }
                        }
                    }
                    }
                    .padding(16)
                }
                .coordinateSpace(name: "gridSpace")
                .background(Color(NSColor.windowBackgroundColor))
                .onTapGesture {
                    // Click on empty space clears selection
                    if !selectedNoteIds.isEmpty {
                        selectedNoteIds.removeAll()
                    } else {
                        dismissCompose()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if !isMarqueeSelecting {
                                isMarqueeSelecting = true
                                marqueeStart = value.startLocation
                            }
                            marqueeEnd = value.location
                        }
                        .onEnded { _ in
                            isMarqueeSelecting = false
                        }
                )
                .onPreferenceChange(NoteFramePreferenceKey.self) { frames in
                    if isMarqueeSelecting {
                        updateSelectionFromMarquee(frames: frames)
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    // Import dropped image files
                    let tabId: UUID? = tabStore.activeTab?.isHome == true ? nil : tabStore.activeTabId
                    var imported = false
                    for url in urls {
                        if noteStore.importImage(from: url, tabId: tabId) != nil {
                            imported = true
                        }
                    }
                    return imported
                } isTargeted: { isTargeted in
                    isTargetedForDrop = isTargeted
                }

                // Marquee selection rectangle overlay
                if isMarqueeSelecting {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.15))
                        .overlay(
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                        .frame(width: marqueeRect.width, height: marqueeRect.height)
                        .position(
                            x: marqueeRect.midX,
                            y: marqueeRect.midY
                        )
                        .allowsHitTesting(false)
                }

                // Drop target overlay
                if isTargetedForDrop {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                        .background(Color.accentColor.opacity(0.1))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func toggleSelection(_ note: Note) {
        if selectedNoteIds.contains(note.id) {
            selectedNoteIds.remove(note.id)
        } else {
            selectedNoteIds.insert(note.id)
        }
    }

    private func updateSelectionFromMarquee(frames: [UUID: CGRect]) {
        var newSelection: Set<UUID> = []
        for (noteId, frame) in frames {
            if marqueeRect.intersects(frame) {
                newSelection.insert(noteId)
            }
        }
        selectedNoteIds = newSelection
    }

    private func dismissCompose() {
        if isComposing {
            if !composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                saveComposedNote()
            } else {
                isComposing = false
                composeText = ""
            }
        }
        // Remove focus from any text field
        isComposeFocused = false
    }
}

// MARK: - Hotkey Hint

struct HotkeyHint: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Compose Bubble View (NSViewRepresentable for click-outside-to-save)

struct ComposeBubbleView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isComposing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Build NSTextView manually to avoid scrollableTextView()'s word-wrap defaults
        let textContainer = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        // Set initial text
        textView.string = text

        // Make first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        // Monitor for clicks outside
        context.coordinator.startMonitoring(textView: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Only update text if it changed externally
        if textView.string != text && !context.coordinator.isUserEditing {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposeBubbleView
        var eventMonitor: Any?
        var isUserEditing = false
        weak var currentTextView: NSTextView?

        init(_ parent: ComposeBubbleView) {
            self.parent = parent
        }

        deinit {
            stopMonitoring()
        }

        func startMonitoring(textView: NSTextView) {
            currentTextView = textView

            // Monitor local mouse events to detect clicks outside
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, let textView = self.currentTextView else { return event }

                // Check if click is outside the text view
                if let window = textView.window {
                    let clickLocation = event.locationInWindow
                    let textViewFrame = textView.convert(textView.bounds, to: nil)

                    if !textViewFrame.contains(clickLocation) {
                        // Click outside - save and dismiss
                        DispatchQueue.main.async {
                            self.saveAndDismiss()
                        }
                    }
                }

                return event
            }
        }

        func stopMonitoring() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }

        func saveAndDismiss() {
            stopMonitoring()
            let trimmed = parent.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                parent.onSave()
            } else {
                parent.onCancel()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUserEditing = true
            parent.text = textView.string
            isUserEditing = false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape pressed - cancel
                stopMonitoring()
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

// MARK: - Note Frame Preference Key

struct NoteFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Selectable Note Item View

struct SelectableNoteItemView: View {
    let note: Note
    let isSelected: Bool
    let selectedCount: Int
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDeleteSelected: () -> Void
    let onUpdate: (String) -> Void
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        Group {
            switch note.type {
            case .text:
                if isEditing {
                    editableTextView
                } else {
                    // Use a simple Text view that doesn't consume gestures
                    Text(note.content)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            case .screenshot:
                ImageNoteView(path: note.content)
            case .recording:
                VideoNoteView(path: note.content)
            }
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 3)
                } else if isEditing {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-click to edit text notes
            if note.type == .text && !isEditing {
                editText = note.content
                isEditing = true
            }
        }
        .onTapGesture(count: 1) {
            // Single-click to select (only when not editing)
            if !isEditing {
                onSelect()
            }
        }
        .contextMenu {
            if note.type == .text && !isEditing {
                Button {
                    editText = note.content
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()
            }

            if note.type != .text {
                Button {
                    showInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Divider()
            }

            Button {
                copyNote()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Divider()

            // Show batch delete if multiple items are selected
            if selectedCount > 1 && isSelected {
                Button(role: .destructive) {
                    onDeleteSelected()
                } label: {
                    Label("Delete \(selectedCount) Selected", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var editableTextView: some View {
        EditableTextBubble(
            text: $editText,
            isEditing: $isEditing,
            onSave: { saveEdit() },
            onCancel: {
                isEditing = false
                editText = ""
            }
        )
        .frame(minHeight: 60)
        .padding(12)
    }

    private func saveEdit() {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onUpdate(text)
        isEditing = false
        editText = ""
    }

    private func showInFinder() {
        let url = URL(fileURLWithPath: note.content)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    private func copyNote() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch note.type {
        case .text:
            pasteboard.setString(note.content, forType: .string)
        case .screenshot, .recording:
            let url = URL(fileURLWithPath: note.content)
            pasteboard.writeObjects([url as NSURL])
        }
    }
}
