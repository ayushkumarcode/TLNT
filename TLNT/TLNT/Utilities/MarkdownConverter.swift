//
//  MarkdownConverter.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import AppKit
import Foundation

/// Converts between NSAttributedString (WYSIWYG) and Markdown (storage).
/// Existing plain text notes are valid markdown with no formatting, so no data loss.
enum MarkdownConverter {

    // MARK: - Markdown → NSAttributedString

    static func attributedString(from markdown: String, font: NSFont, color: NSColor) -> NSAttributedString {
        guard !markdown.isEmpty else {
            return NSAttributedString(string: "", attributes: [.font: font, .foregroundColor: color])
        }

        let mutable = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            let parsed = parseLine(line, baseFont: font, color: color)
            mutable.append(parsed)
            if lineIndex < lines.count - 1 {
                mutable.append(NSAttributedString(string: "\n", attributes: [.font: font, .foregroundColor: color]))
            }
        }

        return mutable
    }

    private static func parseLine(_ line: String, baseFont: NSFont, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            // Bold+Italic: ***text***
            if remaining.hasPrefix("***"), let endRange = remaining.dropFirst(3).range(of: "***") {
                let content = remaining[remaining.index(remaining.startIndex, offsetBy: 3)..<endRange.lowerBound]
                let boldItalicFont = NSFontManager.shared.convert(NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask), toHaveTrait: .italicFontMask)
                result.append(NSAttributedString(string: String(content), attributes: [.font: boldItalicFont, .foregroundColor: color]))
                remaining = remaining[endRange.upperBound...]
                continue
            }

            // Bold: **text**
            if remaining.hasPrefix("**"), let endRange = remaining.dropFirst(2).range(of: "**") {
                let content = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<endRange.lowerBound]
                let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                result.append(NSAttributedString(string: String(content), attributes: [.font: boldFont, .foregroundColor: color]))
                remaining = remaining[endRange.upperBound...]
                continue
            }

            // Strikethrough: ~~text~~
            if remaining.hasPrefix("~~"), let endRange = remaining.dropFirst(2).range(of: "~~") {
                let content = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<endRange.lowerBound]
                result.append(NSAttributedString(string: String(content), attributes: [
                    .font: baseFont, .foregroundColor: color,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]))
                remaining = remaining[endRange.upperBound...]
                continue
            }

            // Italic: *text* or _text_
            if (remaining.hasPrefix("*") && !remaining.hasPrefix("**")) || remaining.hasPrefix("_") {
                let marker = remaining.first!
                let markerStr = String(marker)
                if let endRange = remaining.dropFirst(1).range(of: markerStr) {
                    let content = remaining[remaining.index(after: remaining.startIndex)..<endRange.lowerBound]
                    if !content.isEmpty {
                        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                        result.append(NSAttributedString(string: String(content), attributes: [.font: italicFont, .foregroundColor: color]))
                        remaining = remaining[endRange.upperBound...]
                        continue
                    }
                }
            }

            // Plain character
            result.append(NSAttributedString(string: String(remaining.first!), attributes: [.font: baseFont, .foregroundColor: color]))
            remaining = remaining.dropFirst()
        }

        return result
    }

    // MARK: - NSAttributedString → Markdown

    static func markdown(from attributedString: NSAttributedString) -> String {
        var result = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)
        guard fullRange.length > 0 else { return "" }

        attributedString.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            let text = (attributedString.string as NSString).substring(with: range)

            let isBold = isFontBold(attrs)
            let isItalic = isFontItalic(attrs)
            let isStrikethrough = isTextStrikethrough(attrs)

            var wrapped = text

            if isStrikethrough {
                wrapped = "~~\(wrapped)~~"
            }
            if isBold && isItalic {
                wrapped = "***\(wrapped)***"
            } else if isBold {
                wrapped = "**\(wrapped)**"
            } else if isItalic {
                wrapped = "*\(wrapped)*"
            }

            result += wrapped
        }

        return result
    }

    // MARK: - Font Trait Detection

    private static func isFontBold(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attrs[.font] as? NSFont else { return false }
        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
    }

    private static func isFontItalic(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attrs[.font] as? NSFont else { return false }
        return NSFontManager.shared.traits(of: font).contains(.italicFontMask)
    }

    private static func isTextStrikethrough(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let style = attrs[.strikethroughStyle] as? Int else { return false }
        return style != 0
    }

    // MARK: - Toggle Formatting on NSTextView

    static func toggleBold(in textView: NSTextView, baseFont: NSFont) {
        let range = textView.selectedRange()
        guard range.length > 0, let textStorage = textView.textStorage else { return }

        let currentAttrs = textStorage.attributes(at: range.location, effectiveRange: nil)
        let currentFont = currentAttrs[.font] as? NSFont ?? baseFont
        let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)

        let newFont: NSFont
        if isBold {
            newFont = NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
        } else {
            newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
        }

        textStorage.addAttribute(.font, value: newFont, range: range)
    }

    static func toggleItalic(in textView: NSTextView, baseFont: NSFont) {
        let range = textView.selectedRange()
        guard range.length > 0, let textStorage = textView.textStorage else { return }

        let currentAttrs = textStorage.attributes(at: range.location, effectiveRange: nil)
        let currentFont = currentAttrs[.font] as? NSFont ?? baseFont
        let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)

        let newFont: NSFont
        if isItalic {
            newFont = NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
        } else {
            newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
        }

        textStorage.addAttribute(.font, value: newFont, range: range)
    }

    static func toggleStrikethrough(in textView: NSTextView) {
        let range = textView.selectedRange()
        guard range.length > 0, let textStorage = textView.textStorage else { return }

        let currentAttrs = textStorage.attributes(at: range.location, effectiveRange: nil)
        let isStrikethrough = (currentAttrs[.strikethroughStyle] as? Int ?? 0) != 0

        if isStrikethrough {
            textStorage.removeAttribute(.strikethroughStyle, range: range)
        } else {
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
}
