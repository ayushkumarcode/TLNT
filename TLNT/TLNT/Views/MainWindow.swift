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
    private var scrollToId: UUID?

    init(noteStore: NoteStore, tabStore: TabStore) {
        self.noteStore = noteStore
        self.tabStore = tabStore
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
        // The scroll will be handled by the SwiftUI view
    }

    private func createWindow() {
        let contentView = MainContentView(noteStore: noteStore, tabStore: tabStore)

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
