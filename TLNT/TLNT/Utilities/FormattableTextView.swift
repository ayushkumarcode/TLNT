//
//  FormattableTextView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import AppKit

/// Custom NSTextView subclass that handles ⌘B (bold), ⌘I (italic),
/// ⌘⇧X (strikethrough) explicitly — NSFontManager's responder chain
/// doesn't work reliably in SwiftUI-hosted views.
class FormattableTextView: NSTextView {

    /// The base font used for this text view (set by the creator).
    var baseFont: NSFont = NSFont.systemFont(ofSize: 13)

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // ⌘B → toggle bold
        if flags == .command && key == "b" {
            MarkdownConverter.toggleBold(in: self, baseFont: baseFont)
            notifyChange()
            return
        }

        // ⌘I → toggle italic
        if flags == .command && key == "i" {
            MarkdownConverter.toggleItalic(in: self, baseFont: baseFont)
            notifyChange()
            return
        }

        // ⌘⇧X → toggle strikethrough
        if flags == [.command, .shift] && key == "x" {
            MarkdownConverter.toggleStrikethrough(in: self)
            notifyChange()
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Intrinsic Size (enables auto-height when not in a scroll view)

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let container = textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: container)
        let height = layoutManager.usedRect(for: container).height + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(20, height))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    private func notifyChange() {
        invalidateIntrinsicContentSize()
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }
}
