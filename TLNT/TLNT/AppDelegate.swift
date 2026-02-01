//
//  AppDelegate.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Cocoa
import SwiftUI
import HotKey
import CoreSpotlight

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var mainWindowController: MainWindowController?

    // Services
    private var noteStore: NoteStore!
    private var hashStore: HashStore!
    private var screenshotWatcher: ScreenshotWatcher!
    private var textCaptureService: TextCaptureService!
    private var hotkeyManager: HotkeyManager!
    private var spotlightIndexer: SpotlightIndexer!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize storage
        noteStore = NoteStore()
        hashStore = HashStore()
        spotlightIndexer = SpotlightIndexer()

        // Initialize services
        screenshotWatcher = ScreenshotWatcher(noteStore: noteStore, hashStore: hashStore, spotlightIndexer: spotlightIndexer)
        textCaptureService = TextCaptureService(noteStore: noteStore, spotlightIndexer: spotlightIndexer)

        // Setup UI
        setupMenuBar()

        // Setup hotkeys
        setupHotkeys()

        // Show onboarding if first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running as menu bar app
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "TLNT")
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open TLNT", action: #selector(openTLNT), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let sendScreenshotItem = NSMenuItem(title: "Send Next Screenshot", action: #selector(sendScreenshot), keyEquivalent: "")
        sendScreenshotItem.target = self
        menu.addItem(sendScreenshotItem)

        let captureTextItem = NSMenuItem(title: "Capture Selected Text", action: #selector(captureText), keyEquivalent: "")
        captureTextItem.target = self
        menu.addItem(captureTextItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        hotkeyManager = HotkeyManager()

        hotkeyManager.onSendScreenshot = { [weak self] in
            self?.sendScreenshot()
        }

        hotkeyManager.onCaptureText = { [weak self] in
            self?.captureText()
        }

        hotkeyManager.onOpenWindow = { [weak self] in
            self?.openTLNT()
        }

        hotkeyManager.setup()
    }

    // MARK: - Actions

    @objc private func openTLNT() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(noteStore: noteStore)
        }
        mainWindowController?.show()
    }

    @objc private func sendScreenshot() {
        if screenshotWatcher.sendNext() {
            showToast("Screenshot added")
        } else {
            showToast("No new screenshots")
        }
    }

    @objc private func captureText() {
        textCaptureService.captureSelectedText { [weak self] success in
            if success {
                self?.showToast("Text captured")
            }
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        let toast = ToastWindow(message: message)
        toast.showAndDismiss()
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let onboardingWindow = OnboardingWindowController {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        onboardingWindow.show()
    }

    // MARK: - Spotlight Continuation

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType,
           let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
           let uuid = UUID(uuidString: identifier) {
            openTLNT()
            mainWindowController?.scrollToNote(id: uuid)
        }
        return true
    }
}
