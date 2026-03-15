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

            // Floating formatting toolbar
            if showToolbar {
                formattingToolbar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var formattingToolbar: some View {
        HStack(spacing: 12) {
            FormatButton(label: "B", font: .bold) {
                wrapSelection(prefix: "**", suffix: "**")
            }
            FormatButton(label: "I", font: .regular) {
                wrapSelection(prefix: "_", suffix: "_")
            }
            FormatButton(label: "H", font: .regular) {
                prependToLine(prefix: "## ")
            }
            FormatButton(label: "List", font: .regular, systemImage: "list.bullet") {
                prependToLine(prefix: "- ")
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

    private func wrapSelection(prefix: String, suffix: String) {
        // For now, append formatting markers — the NSTextView handles display
        // This is a simplified approach; full rich text would need NSTextView coordination
        text += prefix + suffix
    }

    private func prependToLine(prefix: String) {
        if text.isEmpty || text.hasSuffix("\n") {
            text += prefix
        } else {
            text += "\n" + prefix
        }
    }
}

struct FormatButton: View {
    let label: String
    let font: Font.Weight
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Text(label)
                    .font(.system(size: 13, weight: font, design: .serif))
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
        .frame(width: 28, height: 24)
        .background(Color(red: 0.92, green: 0.88, blue: 0.80).opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - NSViewRepresentable for NSTextView

struct RichTextNSView: NSViewRepresentable {
    @Binding var text: String
    @Binding var showToolbar: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.font = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
        textView.backgroundColor = .clear
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 4)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        loadContent(into: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if !context.coordinator.isUserEditing && textView.string != text {
            loadContent(into: textView)
        }
    }

    private func loadContent(into textView: NSTextView) {
        let inkColor = NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
        let serifFont = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)

        if text.isEmpty {
            textView.string = ""
            textView.font = serifFont
            textView.textColor = inkColor
            return
        }

        if let attrStr = try? NSAttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let mutable = NSMutableAttributedString(attributedString: attrStr)
            let range = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.font, value: serifFont, range: range)
            mutable.addAttribute(.foregroundColor, value: inkColor, range: range)
            textView.textStorage?.setAttributedString(mutable)
        } else {
            textView.string = text
            textView.font = serifFont
            textView.textColor = inkColor
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextNSView
        var isUserEditing = false

        init(_ parent: RichTextNSView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUserEditing = true
            parent.text = textView.string
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
    }
}
