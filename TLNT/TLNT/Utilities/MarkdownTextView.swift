//
//  MarkdownTextView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI

/// A SwiftUI Text view that renders inline markdown formatting
/// (bold, italic, strikethrough) for display-only purposes.
struct MarkdownTextView: View {
    let content: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(content)
        }
    }
}
