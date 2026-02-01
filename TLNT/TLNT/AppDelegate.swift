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
        TLNTLogger.info("=== TLNT App Starting ===", category: TLNTLogger.app)
        TLNTLogger.debug("applicationDidFinishLaunching called", category: TLNTLogger.app)

        // Initialize storage
        TLNTLogger.debug("Initializing NoteStore...", category: TLNTLogger.storage)
        noteStore = NoteStore()
        TLNTLogger.success("NoteStore initialized with \(noteStore.notes.count) notes", category: TLNTLogger.storage)

        TLNTLogger.debug("Initializing HashStore...", category: TLNTLogger.storage)
        hashStore = HashStore()
        TLNTLogger.success("HashStore initialized", category: TLNTLogger.storage)

        TLNTLogger.debug("Initializing SpotlightIndexer...", category: TLNTLogger.spotlight)
        spotlightIndexer = SpotlightIndexer()
        TLNTLogger.success("SpotlightIndexer initialized", category: TLNTLogger.spotlight)

        // Initialize services
        TLNTLogger.debug("Initializing ScreenshotWatcher...", category: TLNTLogger.screenshot)
        screenshotWatcher = ScreenshotWatcher(noteStore: noteStore, hashStore: hashStore, spotlightIndexer: spotlightIndexer)
        TLNTLogger.success("ScreenshotWatcher initialized", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Initializing TextCaptureService...", category: TLNTLogger.text)
        textCaptureService = TextCaptureService(noteStore: noteStore, spotlightIndexer: spotlightIndexer)
        TLNTLogger.success("TextCaptureService initialized", category: TLNTLogger.text)

        // Setup UI
        TLNTLogger.debug("Setting up menu bar...", category: TLNTLogger.ui)
        setupMenuBar()
        TLNTLogger.success("Menu bar setup complete", category: TLNTLogger.ui)

        // Setup hotkeys
        TLNTLogger.debug("Setting up hotkeys...", category: TLNTLogger.hotkey)
        setupHotkeys()
        TLNTLogger.success("Hotkeys setup complete", category: TLNTLogger.hotkey)

        // Show onboarding if first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            TLNTLogger.info("First launch detected, showing onboarding", category: TLNTLogger.app)
            showOnboarding()
        } else {
            TLNTLogger.info("Onboarding already completed", category: TLNTLogger.app)
        }

        TLNTLogger.success("=== TLNT App Started Successfully ===", category: TLNTLogger.app)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        TLNTLogger.debug("applicationShouldTerminateAfterLastWindowClosed called, returning false", category: TLNTLogger.app)
        return false // Keep running as menu bar app
    }

    func applicationWillTerminate(_ notification: Notification) {
        TLNTLogger.info("=== TLNT App Terminating ===", category: TLNTLogger.app)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        TLNTLogger.debug("Creating status item...", category: TLNTLogger.ui)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "TLNT")
            TLNTLogger.debug("Status item button configured with icon", category: TLNTLogger.ui)
        } else {
            TLNTLogger.warning("Failed to get status item button", category: TLNTLogger.ui)
        }

        let menu = NSMenu()
        TLNTLogger.debug("Creating menu items...", category: TLNTLogger.ui)

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
        TLNTLogger.debug("Menu attached to status item", category: TLNTLogger.ui)
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        TLNTLogger.debug("Creating HotkeyManager...", category: TLNTLogger.hotkey)
        hotkeyManager = HotkeyManager()

        hotkeyManager.onSendScreenshot = { [weak self] in
            TLNTLogger.info("Screenshot hotkey triggered", category: TLNTLogger.hotkey)
            self?.sendScreenshot()
        }

        hotkeyManager.onCaptureText = { [weak self] in
            TLNTLogger.info("Text capture hotkey triggered", category: TLNTLogger.hotkey)
            self?.captureText()
        }

        hotkeyManager.onOpenWindow = { [weak self] in
            TLNTLogger.info("Open window hotkey triggered", category: TLNTLogger.hotkey)
            self?.openTLNT()
        }

        TLNTLogger.debug("Calling hotkeyManager.setup()...", category: TLNTLogger.hotkey)
        hotkeyManager.setup()
        TLNTLogger.success("HotkeyManager setup complete", category: TLNTLogger.hotkey)
    }

    // MARK: - Actions

    @objc private func openTLNT() {
        TLNTLogger.info("openTLNT called", category: TLNTLogger.ui)

        if mainWindowController == nil {
            TLNTLogger.debug("Creating new MainWindowController...", category: TLNTLogger.ui)
            mainWindowController = MainWindowController(noteStore: noteStore)
            TLNTLogger.debug("MainWindowController created", category: TLNTLogger.ui)
        }

        TLNTLogger.debug("Showing main window...", category: TLNTLogger.ui)
        mainWindowController?.show()
        TLNTLogger.success("Main window shown", category: TLNTLogger.ui)
    }

    @objc private func sendScreenshot() {
        TLNTLogger.info("=== sendScreenshot START ===", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Calling screenshotWatcher.sendNext()...", category: TLNTLogger.screenshot)
        let result = screenshotWatcher.sendNext()
        TLNTLogger.debug("screenshotWatcher.sendNext() returned: \(result)", category: TLNTLogger.screenshot)

        if result {
            TLNTLogger.success("Screenshot added successfully", category: TLNTLogger.screenshot)
            showToast("Screenshot added")
        } else {
            TLNTLogger.info("No new screenshots to add", category: TLNTLogger.screenshot)
            showToast("No new screenshots")
        }

        TLNTLogger.info("=== sendScreenshot END ===", category: TLNTLogger.screenshot)
    }

    @objc private func captureText() {
        TLNTLogger.info("=== captureText START ===", category: TLNTLogger.text)

        TLNTLogger.debug("Calling textCaptureService.captureSelectedText()...", category: TLNTLogger.text)
        textCaptureService.captureSelectedText { [weak self] success in
            TLNTLogger.debug("captureSelectedText callback received, success: \(success)", category: TLNTLogger.text)

            if success {
                TLNTLogger.success("Text captured successfully", category: TLNTLogger.text)
                self?.showToast("Text captured")
            } else {
                TLNTLogger.warning("Text capture failed or no text selected", category: TLNTLogger.text)
            }
        }

        TLNTLogger.info("=== captureText END ===", category: TLNTLogger.text)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        TLNTLogger.debug("showToast called with message: '\(message)'", category: TLNTLogger.ui)

        DispatchQueue.main.async {
            TLNTLogger.debug("Creating ToastWindow on main thread...", category: TLNTLogger.ui)
            let toast = ToastWindow(message: message)
            TLNTLogger.debug("Calling toast.showAndDismiss()...", category: TLNTLogger.ui)
            toast.showAndDismiss()
            TLNTLogger.debug("Toast displayed", category: TLNTLogger.ui)
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        TLNTLogger.debug("showOnboarding called", category: TLNTLogger.ui)

        let onboardingWindow = OnboardingWindowController {
            TLNTLogger.info("Onboarding completed", category: TLNTLogger.ui)
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        TLNTLogger.debug("Showing onboarding window...", category: TLNTLogger.ui)
        onboardingWindow.show()
    }

    // MARK: - Spotlight Continuation

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        TLNTLogger.info("Spotlight continuation received", category: TLNTLogger.spotlight)
        TLNTLogger.debug("Activity type: \(userActivity.activityType)", category: TLNTLogger.spotlight)

        if userActivity.activityType == CSSearchableItemActionType,
           let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
           let uuid = UUID(uuidString: identifier) {
            TLNTLogger.info("Opening note from Spotlight: \(uuid)", category: TLNTLogger.spotlight)
            openTLNT()
            mainWindowController?.scrollToNote(id: uuid)
        }
        return true
    }
}
