//
//  TextCaptureService.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Cocoa
import ApplicationServices

class TextCaptureService {
    private let noteStore: NoteStore
    private let spotlightIndexer: SpotlightIndexer

    init(noteStore: NoteStore, spotlightIndexer: SpotlightIndexer) {
        self.noteStore = noteStore
        self.spotlightIndexer = spotlightIndexer
    }

    // MARK: - Permission

    /// Requests accessibility permission, returns true if already granted
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Checks if accessibility permission is granted
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }

    // MARK: - Capture

    /// Captures currently selected text
    func captureSelectedText(completion: @escaping (Bool) -> Void) {
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            completion(false)
            return
        }

        // Try Accessibility API first
        if let text = getSelectedTextViaAccessibility(), !text.isEmpty {
            saveText(text)
            completion(true)
            return
        }

        // Fallback: clipboard method
        captureViaClipboard(completion: completion)
    }

    // MARK: - Accessibility API Method

    private func getSelectedTextViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success, let text = selectedText as? String else {
            return nil
        }

        return text
    }

    // MARK: - Clipboard Fallback Method

    private func captureViaClipboard(completion: @escaping (Bool) -> Void) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let oldContents = pasteboard.string(forType: .string)
        let oldChangeCount = pasteboard.changeCount

        // Simulate ⌘C
        simulateCopy()

        // Wait for clipboard to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            // Check if clipboard changed
            if pasteboard.changeCount != oldChangeCount,
               let text = pasteboard.string(forType: .string),
               !text.isEmpty,
               text != oldContents {
                self?.saveText(text)

                // Restore old clipboard if it existed
                if let old = oldContents {
                    pasteboard.clearContents()
                    pasteboard.setString(old, forType: .string)
                }

                completion(true)
            } else {
                completion(false)
            }
        }
    }

    private func simulateCopy() {
        // Create a ⌘C key event
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code 8 = 'c'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Save

    private func saveText(_ text: String) {
        let note = Note(
            type: .text,
            content: text
        )

        noteStore.add(note)
        spotlightIndexer.indexNote(note)
    }
}
