//
//  NoteItemView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import SwiftUI
import AppKit
import AVKit

struct NoteItemView: View {
    let note: Note
    let onDelete: () -> Void
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
                    TextNoteView(text: note.content, onDoubleClick: {
                        editText = note.content
                        isEditing = true
                    })
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
            isEditing ? RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2) : nil
        )
        .contextMenu {
            if note.type == .text {
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

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
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

// MARK: - Text Note View

struct TextNoteView: View {
    let text: String
    var onDoubleClick: (() -> Void)? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .onTapGesture(count: 2) {
                onDoubleClick?()
            }
    }
}

// MARK: - Editable Text Bubble with click-outside-to-save

struct EditableTextBubble: NSViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
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

        // Update parent reference and ensure monitoring is active
        context.coordinator.parent = self
        if context.coordinator.eventMonitor == nil {
            context.coordinator.startMonitoring(textView: textView)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditableTextBubble
        var eventMonitor: Any?
        var isUserEditing = false
        weak var currentTextView: NSTextView?

        init(_ parent: EditableTextBubble) {
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

// MARK: - Image Note View

struct ImageNoteView: View {
    let path: String

    var body: some View {
        Group {
            if let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipped()
            } else {
                missingFileView
            }
        }
        .onTapGesture(count: 2) {
            openFile()
        }
    }

    private var missingFileView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("File not found")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }

    private func openFile() {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Video Note View

struct VideoNoteView: View {
    let path: String
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
            } else if FileManager.default.fileExists(atPath: path) {
                Color.black
                    .frame(height: 150)
            } else {
                missingFileView
            }

            if FileManager.default.fileExists(atPath: path) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            generateThumbnail()
        }
        .onTapGesture(count: 2) {
            openFile()
        }
    }

    private var missingFileView: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("File not found")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }

    private func generateThumbnail() {
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0, preferredTimescale: 600)

        DispatchQueue.global(qos: .userInitiated).async {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.thumbnail = nsImage
                }
            }
        }
    }

    private func openFile() {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}
