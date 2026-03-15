//
//  FormattableTextView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import AppKit

/// Custom NSTextView subclass that adds ⌘⇧X for strikethrough.
/// ⌘B (bold) and ⌘I (italic) are built-in when isRichText=true.
class FormattableTextView: NSTextView {

    override func keyDown(with event: NSEvent) {
        // ⌘⇧X → toggle strikethrough
        if event.modifierFlags.contains([.command, .shift]),
           event.charactersIgnoringModifiers?.lowercased() == "x" {
            MarkdownConverter.toggleStrikethrough(in: self)
            // Notify delegate of change
            NotificationCenter.default.post(name: NSText.didChangeNotification, object: self)
            return
        }
        super.keyDown(with: event)
    }
}
