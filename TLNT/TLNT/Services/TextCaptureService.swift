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
    private let tabStore: TabStore
    private let spotlightIndexer: SpotlightIndexer

    init(noteStore: NoteStore, tabStore: TabStore, spotlightIndexer: SpotlightIndexer) {
        self.noteStore = noteStore
        self.tabStore = tabStore
        self.spotlightIndexer = spotlightIndexer
    }

    // MARK: - Permission

    /// Checks if accessibility permission is granted (without prompting)
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }

    // MARK: - Capture

    /// Captures currently selected text
    func captureSelectedText(completion: @escaping (Bool) -> Void) {
        TLNTLogger.debug("captureSelectedText() called", category: TLNTLogger.text)
        TLNTLogger.debug("Accessibility permission: \(hasAccessibilityPermission)", category: TLNTLogger.text)

        // Try Accessibility API first (works if permission is granted)
        if hasAccessibilityPermission {
            TLNTLogger.debug("Trying Accessibility API...", category: TLNTLogger.text)
            if let text = getSelectedTextViaAccessibility(), !text.isEmpty {
                TLNTLogger.success("Got text via Accessibility: \(text.prefix(50))...", category: TLNTLogger.text)
                saveText(text)
                completion(true)
                return
            }
            TLNTLogger.debug("Accessibility API returned nil or empty", category: TLNTLogger.text)
        } else {
            TLNTLogger.warning("No accessibility permission, skipping Accessibility API", category: TLNTLogger.text)
        }

        // Fallback: clipboard method
        // Delay slightly to let the user release hotkey modifier keys (⌘⇧)
        // Otherwise the simulated ⌘C may be interpreted as ⌘⇧C
        TLNTLogger.debug("Falling back to clipboard method (with 200ms delay for modifier release)...", category: TLNTLogger.text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.captureViaClipboard(completion: completion)
        }
    }

    // MARK: - Accessibility API Method

    private func getSelectedTextViaAccessibility() -> String? {
        TLNTLogger.debug("getSelectedTextViaAccessibility() called", category: TLNTLogger.text)

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            TLNTLogger.debug("Failed to get focused element, result: \(focusResult.rawValue)", category: TLNTLogger.text)
            return nil
        }

        TLNTLogger.debug("Got focused element, requesting selected text...", category: TLNTLogger.text)

        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success, let text = selectedText as? String else {
            TLNTLogger.debug("Failed to get selected text, result: \(textResult.rawValue)", category: TLNTLogger.text)
            return nil
        }

        TLNTLogger.debug("Got selected text: '\(text.prefix(100))'", category: TLNTLogger.text)
        return text
    }

    // MARK: - Clipboard Fallback Method

    private func captureViaClipboard(completion: @escaping (Bool) -> Void) {
        TLNTLogger.debug("captureViaClipboard() called", category: TLNTLogger.text)

        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let oldContents = pasteboard.string(forType: .string)
        let oldChangeCount = pasteboard.changeCount
        TLNTLogger.debug("Old clipboard changeCount: \(oldChangeCount), contents length: \(oldContents?.count ?? 0)", category: TLNTLogger.text)

        // Simulate ⌘C
        TLNTLogger.debug("Simulating ⌘C...", category: TLNTLogger.text)
        simulateCopy()

        // Wait for clipboard to update (250ms to give apps time to respond)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            let newChangeCount = pasteboard.changeCount
            TLNTLogger.debug("Clipboard check - old changeCount: \(oldChangeCount), new changeCount: \(newChangeCount)", category: TLNTLogger.text)

            // Check if clipboard changed
            if newChangeCount != oldChangeCount,
               let text = pasteboard.string(forType: .string),
               !text.isEmpty,
               text != oldContents {
                TLNTLogger.success("Clipboard captured text: '\(text.prefix(100))'", category: TLNTLogger.text)
                self?.saveText(text)

                // Restore old clipboard if it existed
                if let old = oldContents {
                    pasteboard.clearContents()
                    pasteboard.setString(old, forType: .string)
                    TLNTLogger.debug("Restored previous clipboard contents", category: TLNTLogger.text)
                }

                completion(true)
            } else {
                TLNTLogger.warning("Clipboard did not change - no text was copied", category: TLNTLogger.text)
                TLNTLogger.debug("changeCount match: \(newChangeCount == oldChangeCount), text: \(pasteboard.string(forType: .string)?.prefix(50) ?? "nil")", category: TLNTLogger.text)
                completion(false)
            }
        }
    }

    private func simulateCopy() {
        TLNTLogger.debug("simulateCopy() called", category: TLNTLogger.text)

        // Use combinedSessionState to avoid inheriting physical modifier key state
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key code 8 = 'c'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        // Explicitly set ONLY command flag (no shift, no option)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // Post at session level (more reliable than HID level when modifier keys are held)
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        TLNTLogger.debug("⌘C events posted", category: TLNTLogger.text)
    }

    // MARK: - Save

    private func saveText(_ text: String) {
        // Save to active tab (nil for home tab)
        let tabId: UUID? = tabStore.activeTab?.isHome == true ? nil : tabStore.activeTabId

        let note = Note(
            type: .text,
            content: text,
            tabId: tabId
        )

        noteStore.add(note)
        spotlightIndexer.indexNote(note)
    }
}
