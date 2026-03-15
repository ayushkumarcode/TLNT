//
//  RichTextEditorView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI
import AppKit

// MARK: - Rich Text Editor with Formatting Toolbar

struct RichTextEditorView: View {
    @Binding var text: String
    @State private var showToolbar = false

    var body: some View {
        ZStack(alignment: .top) {
            RichTextNSView(text: $text, showToolbar: $showToolbar)

            if showToolbar {
                formattingToolbar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var formattingToolbar: some View {
        HStack(spacing: 12) {
            FormatButton(label: "B", font: .bold, shortcut: "⌘B") {
                NotificationCenter.default.post(name: .richTextToggleBold, object: nil)
            }
            FormatButton(label: "I", font: .regular, shortcut: "⌘I") {
                NotificationCenter.default.post(name: .richTextToggleItalic, object: nil)
            }
            FormatButton(label: "S", font: .regular, shortcut: "⌘⇧X", strikethrough: true) {
                NotificationCenter.default.post(name: .richTextToggleStrikethrough, object: nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.96, green: 0.93, blue: 0.87))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .padding(.top, 4)
    }
}

extension Notification.Name {
    static let richTextToggleBold = Notification.Name("richTextToggleBold")
    static let richTextToggleItalic = Notification.Name("richTextToggleItalic")
    static let richTextToggleStrikethrough = Notification.Name("richTextToggleStrikethrough")
}

struct FormatButton: View {
    let label: String
    let font: Font.Weight
    var shortcut: String? = nil
    var strikethrough: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: font, design: .serif))
                .strikethrough(strikethrough)
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
        .frame(width: 28, height: 24)
        .background(Color(red: 0.92, green: 0.88, blue: 0.80).opacity(0.5))
        .cornerRadius(4)
        .help(shortcut ?? "")
    }
}

// MARK: - NSViewRepresentable for NSTextView

struct RichTextNSView: NSViewRepresentable {
    @Binding var text: String
    @Binding var showToolbar: Bool

    private static let serifFont = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)
    private static let inkColor = NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = FormattableTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = Self.serifFont
        textView.textColor = Self.inkColor
        textView.backgroundColor = .clear
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        // Load markdown content
        let attrStr = MarkdownConverter.attributedString(from: text, font: Self.serifFont, color: Self.inkColor)
        textView.textStorage?.setAttributedString(attrStr)

        // Listen for toolbar button notifications
        context.coordinator.setupToolbarNotifications(textView: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? FormattableTextView else { return }

        if !context.coordinator.isUserEditing {
            let currentMarkdown = MarkdownConverter.markdown(from: textView.attributedString())
            if currentMarkdown != text {
                let attrStr = MarkdownConverter.attributedString(from: text, font: Self.serifFont, color: Self.inkColor)
                textView.textStorage?.setAttributedString(attrStr)
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextNSView
        var isUserEditing = false
        weak var currentTextView: FormattableTextView?

        init(_ parent: RichTextNSView) {
            self.parent = parent
        }

        func setupToolbarNotifications(textView: FormattableTextView) {
            currentTextView = textView

            NotificationCenter.default.addObserver(forName: .richTextToggleBold, object: nil, queue: .main) { [weak self] _ in
                guard let tv = self?.currentTextView else { return }
                MarkdownConverter.toggleBold(in: tv, baseFont: RichTextNSView.serifFont)
                self?.syncText(from: tv)
            }
            NotificationCenter.default.addObserver(forName: .richTextToggleItalic, object: nil, queue: .main) { [weak self] _ in
                guard let tv = self?.currentTextView else { return }
                MarkdownConverter.toggleItalic(in: tv, baseFont: RichTextNSView.serifFont)
                self?.syncText(from: tv)
            }
            NotificationCenter.default.addObserver(forName: .richTextToggleStrikethrough, object: nil, queue: .main) { [weak self] _ in
                guard let tv = self?.currentTextView else { return }
                MarkdownConverter.toggleStrikethrough(in: tv)
                self?.syncText(from: tv)
            }
        }

        private func syncText(from textView: NSTextView) {
            isUserEditing = true
            parent.text = MarkdownConverter.markdown(from: textView.attributedString())
            isUserEditing = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUserEditing = true
            parent.text = MarkdownConverter.markdown(from: textView.attributedString())
            isUserEditing = false
        }

        func textDidBeginEditing(_ notification: Notification) {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.parent.showToolbar = true
                }
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.parent.showToolbar = false
                }
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
