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

    init() {
        TLNTLogger.debug("HotkeyManager.init() called", category: TLNTLogger.hotkey)
    }

    func setup() {
        TLNTLogger.info("Setting up hotkeys...", category: TLNTLogger.hotkey)

        // ⌘⇧S - Send next screenshot (Command + Shift + S)
        TLNTLogger.debug("Registering ⌘⇧S for screenshot...", category: TLNTLogger.hotkey)
        sendScreenshotHotkey = HotKey(key: .s, modifiers: [.command, .shift])
        sendScreenshotHotkey?.keyDownHandler = { [weak self] in
            TLNTLogger.info("⌘⇧S pressed - screenshot hotkey", category: TLNTLogger.hotkey)
            self?.onSendScreenshot?()
        }
        TLNTLogger.success("⌘⇧S registered", category: TLNTLogger.hotkey)

        // ⌘⇧K - Capture selected text (Command + Shift + K)
        TLNTLogger.debug("Registering ⌘⇧K for text capture...", category: TLNTLogger.hotkey)
        captureTextHotkey = HotKey(key: .k, modifiers: [.command, .shift])
        captureTextHotkey?.keyDownHandler = { [weak self] in
            TLNTLogger.info("⌘⇧K pressed - text capture hotkey", category: TLNTLogger.hotkey)
            self?.onCaptureText?()
        }
        TLNTLogger.success("⌘⇧K registered", category: TLNTLogger.hotkey)

        // ⌘⇧L - Open TLNT window (Command + Shift + L)
        TLNTLogger.debug("Registering ⌘⇧L for open window...", category: TLNTLogger.hotkey)
        openWindowHotkey = HotKey(key: .l, modifiers: [.command, .shift])
        openWindowHotkey?.keyDownHandler = { [weak self] in
            TLNTLogger.info("⌘⇧L pressed - open window hotkey", category: TLNTLogger.hotkey)
            self?.onOpenWindow?()
        }
        TLNTLogger.success("⌘⇧L registered", category: TLNTLogger.hotkey)

        TLNTLogger.success("All hotkeys registered successfully", category: TLNTLogger.hotkey)
    }

    deinit {
        TLNTLogger.debug("HotkeyManager.deinit() called", category: TLNTLogger.hotkey)
        sendScreenshotHotkey = nil
        captureTextHotkey = nil
        openWindowHotkey = nil
        TLNTLogger.debug("All hotkeys released", category: TLNTLogger.hotkey)
    }
}
