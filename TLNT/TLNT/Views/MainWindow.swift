//
//  MainWindow.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Cocoa
import SwiftUI

class MainWindowController {
    private var window: NSWindow?
    private let noteStore: NoteStore
    private let tabStore: TabStore
    private let appModeStore: AppModeStore
    private let journalStore: JournalStore
    private let zoomStore: ZoomStore
    private var scrollToId: UUID?

    init(noteStore: NoteStore, tabStore: TabStore, appModeStore: AppModeStore, journalStore: JournalStore, zoomStore: ZoomStore) {
        self.noteStore = noteStore
        self.tabStore = tabStore
        self.appModeStore = appModeStore
        self.journalStore = journalStore
        self.zoomStore = zoomStore
    }

    func show() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func scrollToNote(id: UUID) {
        scrollToId = id
        show()
    }

    private func createWindow() {
        let contentView = RootContentView(noteStore: noteStore, tabStore: tabStore, appModeStore: appModeStore, journalStore: journalStore, zoomStore: zoomStore)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window?.title = "TLNT"
        window?.contentView = NSHostingView(rootView: contentView)
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.minSize = NSSize(width: 500, height: 400)

        // Click outside to dismiss
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.window?.close()
        }
    }
}
