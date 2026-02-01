//
//  HotkeyManager.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation
import HotKey

class HotkeyManager {
    private var sendScreenshotHotkey: HotKey?
    private var captureTextHotkey: HotKey?
    private var openWindowHotkey: HotKey?

    // Callbacks
    var onSendScreenshot: (() -> Void)?
    var onCaptureText: (() -> Void)?
    var onOpenWindow: (() -> Void)?

    func setup() {
        // ⌘⌥S - Send next screenshot
        sendScreenshotHotkey = HotKey(key: .s, modifiers: [.command, .option])
        sendScreenshotHotkey?.keyDownHandler = { [weak self] in
            self?.onSendScreenshot?()
        }

        // ⌘⌥K - Capture selected text
        captureTextHotkey = HotKey(key: .k, modifiers: [.command, .option])
        captureTextHotkey?.keyDownHandler = { [weak self] in
            self?.onCaptureText?()
        }

        // ⌘⌥L - Open TLNT window
        openWindowHotkey = HotKey(key: .l, modifiers: [.command, .option])
        openWindowHotkey?.keyDownHandler = { [weak self] in
            self?.onOpenWindow?()
        }
    }

    deinit {
        sendScreenshotHotkey = nil
        captureTextHotkey = nil
        openWindowHotkey = nil
    }
}
