//
//  RichTextEditorView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI
import AppKit

struct RichTextEditorView: NSViewRepresentable {
    @Binding var text: String

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

        // Load markdown content as attributed string
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
        if text.isEmpty {
            textView.string = ""
            textView.font = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)
            textView.textColor = NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
            return
        }

        // Try to parse markdown
        if let attrStr = try? NSAttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let mutable = NSMutableAttributedString(attributedString: attrStr)
            // Apply our serif font and color throughout
            let range = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.font, value: NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15), range: range)
            mutable.addAttribute(.foregroundColor, value: NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0), range: range)
            textView.textStorage?.setAttributedString(mutable)
        } else {
            textView.string = text
            textView.font = NSFont(name: "Georgia", size: 15) ?? NSFont.systemFont(ofSize: 15)
            textView.textColor = NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditorView
        var isUserEditing = false

        init(_ parent: RichTextEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUserEditing = true
            parent.text = textView.string
            isUserEditing = false
        }
    }
}
