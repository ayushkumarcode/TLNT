# TLNT Implementation Plan

## Overview

TLNT (The Last Note Taker) is a macOS menu bar app for instant capture of screenshots, screen recordings, and selected text into a unified local notes space.

---

## Core Spec

| Feature | Implementation |
|---------|----------------|
| Screenshot/Recording capture | Watch folder, hash-deduplicated, reference-based |
| Text capture | Global hotkey + Accessibility API |
| Storage | References in `~/Documents/TLNT/`, metadata in JSON |
| UI | Masonry grid, click outside dismisses |
| Spotlight | Index text notes for system search |

### Hotkeys (Configurable)
- `⌘⌥S` — Send next unsent screenshot/recording to TLNT
- `⌘⌥K` — Capture selected text
- `⌘⌥L` — Open TLNT window

---

## Phase 1: Foundation (Skeleton App)

### 1.1 Create Xcode Project
- macOS App, SwiftUI lifecycle
- App Sandbox: OFF (need file system access, accessibility)
- Hardened Runtime: ON
- Signing: Development team

### 1.2 Menu Bar App Structure
```swift
// TLNTApp.swift
@main
struct TLNTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { } // Empty, we use menu bar
    }
}

// AppDelegate.swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkeys()
        setupFolderWatcher()
    }
}
```

### 1.3 File Structure
```
TLNT/
├── TLNT.xcodeproj
├── TLNT/
│   ├── App/
│   │   ├── TLNTApp.swift
│   │   └── AppDelegate.swift
│   ├── Services/
│   │   ├── HotkeyManager.swift
│   │   ├── ScreenshotWatcher.swift
│   │   ├── TextCaptureService.swift
│   │   └── SpotlightIndexer.swift
│   ├── Storage/
│   │   ├── NoteStore.swift
│   │   └── HashStore.swift
│   ├── Models/
│   │   └── Note.swift
│   ├── Views/
│   │   ├── MainWindow.swift
│   │   ├── NoteGridView.swift
│   │   ├── NoteItemView.swift
│   │   └── ToastView.swift
│   ├── Utilities/
│   │   ├── FileHasher.swift
│   │   └── ScreenshotLocator.swift
│   └── Resources/
│       └── Assets.xcassets
├── Info.plist
└── TLNT.entitlements
```

### 1.4 Verification: Phase 1
- [ ] App launches
- [ ] Menu bar icon appears
- [ ] Clicking icon shows a dropdown menu with "Open TLNT" and "Quit"
- [ ] "Quit" exits the app

---

## Phase 2: Storage Layer

### 2.1 Note Model
```swift
// Models/Note.swift
struct Note: Identifiable, Codable {
    let id: UUID
    let type: NoteType
    let content: String      // Text content OR file path (for images/videos)
    let hash: String?        // SHA256 for media files
    let createdAt: Date

    enum NoteType: String, Codable {
        case text
        case screenshot
        case recording
    }
}
```

### 2.2 Note Store
```swift
// Storage/NoteStore.swift
class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let storageURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("TLNT")

    private var metadataURL: URL { storageURL.appendingPathComponent("notes.json") }

    init() {
        ensureDirectoryExists()
        load()
    }

    func add(_ note: Note) { ... }
    func delete(_ note: Note) { ... }
    func load() { ... }
    func save() { ... }
    func containsHash(_ hash: String) -> Bool { ... }
}
```

### 2.3 Hash Store
```swift
// Storage/HashStore.swift
class HashStore {
    private var hashes: Set<String> = []
    private let fileURL: URL

    func contains(_ hash: String) -> Bool
    func add(_ hash: String)
    func save()
    func load()
}
```

### 2.4 File Hasher Utility
```swift
// Utilities/FileHasher.swift
import CryptoKit

func sha256(fileAt url: URL) -> String? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}
```

### 2.5 Verification: Phase 2
- [ ] `~/Documents/TLNT/` directory is created on first launch
- [ ] `notes.json` is created (empty array initially)
- [ ] Can programmatically add a note and see it persisted in JSON
- [ ] App restart preserves notes
- [ ] Hash lookup returns correct results

---

## Phase 3: Screenshot Watcher

### 3.1 Screenshot Locator
```swift
// Utilities/ScreenshotLocator.swift
class ScreenshotLocator {
    /// Reads screenshot location from macOS preferences
    static func getScreenshotFolder() -> URL {
        // defaults read com.apple.screencapture location
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.screencapture", "location"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        } catch { }

        // Default to Desktop
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// Returns screenshots sorted by modification date (newest first)
    static func getScreenshots(in folder: URL) -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }

        let screenshotPattern = /^Screenshot \d{4}-\d{2}-\d{2} at \d{2}\.\d{2}\.\d{2}\.png$/
        let recordingPattern = /^Screen Recording \d{4}-\d{2}-\d{2} at \d{2}\.\d{2}\.\d{2}\.mov$/

        return files
            .filter { url in
                let name = url.lastPathComponent
                return name.contains(screenshotPattern) || name.contains(recordingPattern)
            }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return date1 > date2 // Newest first
            }
    }
}
```

### 3.2 Screenshot Watcher Service
```swift
// Services/ScreenshotWatcher.swift
class ScreenshotWatcher {
    private let noteStore: NoteStore
    private let hashStore: HashStore

    func getNextUnsent() -> URL? {
        let folder = ScreenshotLocator.getScreenshotFolder()
        let files = ScreenshotLocator.getScreenshots(in: folder)

        for file in files {
            guard let hash = sha256(fileAt: file) else { continue }
            if !hashStore.contains(hash) {
                return file
            }
        }
        return nil
    }

    func sendNext() -> Bool {
        guard let file = getNextUnsent() else { return false }
        guard let hash = sha256(fileAt: file) else { return false }

        let note = Note(
            id: UUID(),
            type: file.pathExtension == "mov" ? .recording : .screenshot,
            content: file.path,
            hash: hash,
            createdAt: Date()
        )

        noteStore.add(note)
        hashStore.add(hash)
        return true
    }
}
```

### 3.3 Verification: Phase 3
- [ ] `ScreenshotLocator.getScreenshotFolder()` returns correct folder (test with custom location)
- [ ] `getScreenshots()` finds only screenshot/recording files, ignores other files
- [ ] Files are sorted newest-first
- [ ] `getNextUnsent()` returns nil when all are sent
- [ ] `getNextUnsent()` skips already-sent files (by hash)
- [ ] `sendNext()` adds note to store and hash to hash store
- [ ] Taking a new screenshot after sending all → `getNextUnsent()` returns the new one

---

## Phase 4: Global Hotkeys

### 4.1 Add HotKey Dependency
Using Swift Package Manager, add:
- https://github.com/soffes/HotKey (simple, minimal)

### 4.2 Hotkey Manager
```swift
// Services/HotkeyManager.swift
import HotKey

class HotkeyManager {
    private var sendScreenshotHotkey: HotKey?
    private var captureTextHotkey: HotKey?
    private var openWindowHotkey: HotKey?

    var onSendScreenshot: (() -> Void)?
    var onCaptureText: (() -> Void)?
    var onOpenWindow: (() -> Void)?

    func setup() {
        // ⌘⌥S - Send screenshot
        sendScreenshotHotkey = HotKey(key: .s, modifiers: [.command, .option])
        sendScreenshotHotkey?.keyDownHandler = { [weak self] in
            self?.onSendScreenshot?()
        }

        // ⌘⌥K - Capture text
        captureTextHotkey = HotKey(key: .k, modifiers: [.command, .option])
        captureTextHotkey?.keyDownHandler = { [weak self] in
            self?.onCaptureText?()
        }

        // ⌘⌥L - Open window
        openWindowHotkey = HotKey(key: .l, modifiers: [.command, .option])
        openWindowHotkey?.keyDownHandler = { [weak self] in
            self?.onOpenWindow?()
        }
    }
}
```

### 4.3 Wire Up in AppDelegate
```swift
// AppDelegate.swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ...
    hotkeyManager.onSendScreenshot = { [weak self] in
        if self?.screenshotWatcher.sendNext() == true {
            self?.showToast("Screenshot added")
        } else {
            self?.showToast("No new screenshots")
        }
    }

    hotkeyManager.onCaptureText = { [weak self] in
        self?.textCaptureService.captureSelectedText()
    }

    hotkeyManager.onOpenWindow = { [weak self] in
        self?.showMainWindow()
    }
}
```

### 4.4 Verification: Phase 4
- [ ] Press ⌘⌥L → main window opens (even if empty)
- [ ] Press ⌘⌥S with no screenshots → toast "No new screenshots"
- [ ] Take a screenshot with ⌘⇧4, then press ⌘⌥S → toast "Screenshot added"
- [ ] Press ⌘⌥S again → should get next unsent or "No new screenshots"
- [ ] Hotkeys work regardless of which app is in foreground

---

## Phase 5: Text Capture

### 5.1 Accessibility Permission
```swift
// Services/TextCaptureService.swift
import ApplicationServices

class TextCaptureService {
    private let noteStore: NoteStore

    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func captureSelectedText() {
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            return
        }

        // Try Accessibility API first
        if let text = getSelectedTextViaAccessibility() {
            saveText(text)
            return
        }

        // Fallback: clipboard method
        captureViaClipboard()
    }

    private func getSelectedTextViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else {
            return nil
        }

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success,
              let text = selectedText as? String,
              !text.isEmpty else {
            return nil
        }

        return text
    }

    private func captureViaClipboard() {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)

        // Simulate ⌘C
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Wait a tiny bit for clipboard to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let text = pasteboard.string(forType: .string), text != oldContents, !text.isEmpty {
                self?.saveText(text)
            }

            // Restore old clipboard
            if let old = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
        }
    }

    private func saveText(_ text: String) {
        let note = Note(
            id: UUID(),
            type: .text,
            content: text,
            hash: nil,
            createdAt: Date()
        )
        noteStore.add(note)
        // Show toast
    }
}
```

### 5.2 Verification: Phase 5
- [ ] First launch prompts for Accessibility permission
- [ ] After granting, select text in Safari, press ⌘⌥K → text captured
- [ ] Select text in VS Code, press ⌘⌥K → text captured
- [ ] Select text in Notes app, press ⌘⌥K → text captured
- [ ] Captured text appears in notes.json
- [ ] Original clipboard is preserved after capture

---

## Phase 6: Toast Notifications

### 6.1 Toast Window
```swift
// Views/ToastView.swift
class ToastWindow: NSWindow {
    init(message: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true

        let view = NSHostingView(rootView: ToastContent(message: message))
        self.contentView = view

        // Position near top-right
        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 220
            let y = screen.frame.maxY - 100
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func showAndDismiss() {
        self.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self.animator().alphaValue = 0
            } completionHandler: {
                self.close()
            }
        }
    }
}

struct ToastContent: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
            )
    }
}
```

### 6.2 Toast Manager in AppDelegate
```swift
func showToast(_ message: String) {
    let toast = ToastWindow(message: message)
    toast.showAndDismiss()
}
```

### 6.3 Verification: Phase 6
- [ ] Toast appears in top-right corner
- [ ] Toast is visible over all apps
- [ ] Toast auto-dismisses after ~1.5 seconds
- [ ] Toast fades out smoothly
- [ ] Multiple toasts in quick succession don't break anything

---

## Phase 7: Main Window UI

### 7.1 Main Window Setup
```swift
// Views/MainWindow.swift
class MainWindowController {
    var window: NSWindow?
    let noteStore: NoteStore

    func show() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let contentView = MainContentView(noteStore: noteStore)

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
```

### 7.2 Main Content View
```swift
// Views/MainContentView.swift
struct MainContentView: View {
    @ObservedObject var noteStore: NoteStore
    @State private var searchText = ""

    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return noteStore.notes.sorted { $0.createdAt > $1.createdAt }
        }
        return noteStore.notes.filter { note in
            if note.type == .text {
                return note.content.localizedCaseInsensitiveContains(searchText)
            }
            return note.content.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Notes grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredNotes) { note in
                        NoteItemView(note: note)
                            .contextMenu {
                                if note.type != .text {
                                    Button("Show in Finder") {
                                        showInFinder(note)
                                    }
                                }
                                Button("Copy") {
                                    copyNote(note)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    noteStore.delete(note)
                                }
                            }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func showInFinder(_ note: Note) {
        NSWorkspace.shared.selectFile(note.content, inFileViewerRootedAtPath: "")
    }

    private func copyNote(_ note: Note) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if note.type == .text {
            pasteboard.setString(note.content, forType: .string)
        } else if let url = URL(string: note.content) {
            pasteboard.writeObjects([url as NSURL])
        }
    }
}
```

### 7.3 Note Item View
```swift
// Views/NoteItemView.swift
struct NoteItemView: View {
    let note: Note

    var body: some View {
        Group {
            switch note.type {
            case .text:
                TextNoteView(text: note.content)
            case .screenshot:
                ImageNoteView(path: note.content)
            case .recording:
                VideoNoteView(path: note.content)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

struct TextNoteView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .lineLimit(10)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ImageNoteView: View {
    let path: String

    var body: some View {
        if let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
        } else {
            VStack {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("File not found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
        }
    }
}

struct VideoNoteView: View {
    let path: String

    var body: some View {
        ZStack {
            if FileManager.default.fileExists(atPath: path) {
                // Thumbnail would go here; for v1, just show icon
                Color.black
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            } else {
                VStack {
                    Image(systemName: "video")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("File not found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
}
```

### 7.4 Verification: Phase 7
- [ ] ⌘⌥L opens main window
- [ ] Window shows all captured notes
- [ ] Screenshots display as thumbnails
- [ ] Text notes show content (truncated if long)
- [ ] Video notes show play icon
- [ ] Search filters notes by content
- [ ] Right-click → Show in Finder works for images/videos
- [ ] Right-click → Copy works
- [ ] Right-click → Delete removes note
- [ ] Click outside window → window closes
- [ ] Missing files show "File not found" instead of crashing

---

## Phase 8: Spotlight Integration

### 8.1 Core Spotlight Indexing
```swift
// Services/SpotlightIndexer.swift
import CoreSpotlight
import UniformTypeIdentifiers

class SpotlightIndexer {
    private let index = CSSearchableIndex.default()

    func indexNote(_ note: Note) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.text)

        switch note.type {
        case .text:
            attributeSet.textContent = note.content
            attributeSet.title = String(note.content.prefix(50))
        case .screenshot:
            attributeSet.title = "TLNT Screenshot"
            attributeSet.contentDescription = note.content
        case .recording:
            attributeSet.title = "TLNT Recording"
            attributeSet.contentDescription = note.content
        }

        attributeSet.contentCreationDate = note.createdAt

        let item = CSSearchableItem(
            uniqueIdentifier: note.id.uuidString,
            domainIdentifier: "com.tlnt.notes",
            attributeSet: attributeSet
        )

        index.indexSearchableItems([item]) { error in
            if let error = error {
                print("Spotlight indexing error: \(error)")
            }
        }
    }

    func removeNote(_ note: Note) {
        index.deleteSearchableItems(withIdentifiers: [note.id.uuidString]) { _ in }
    }

    func reindexAll(notes: [Note]) {
        index.deleteSearchableItems(withDomainIdentifiers: ["com.tlnt.notes"]) { [weak self] _ in
            for note in notes {
                self?.indexNote(note)
            }
        }
    }
}
```

### 8.2 Handle Spotlight Launch
```swift
// AppDelegate.swift
func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
    if userActivity.activityType == CSSearchableItemActionType,
       let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
       let uuid = UUID(uuidString: identifier) {
        // Open TLNT and scroll to this note
        showMainWindow()
        // TODO: Scroll to note with this UUID
    }
    return true
}
```

### 8.3 Wire Up Indexing
```swift
// In NoteStore
func add(_ note: Note) {
    notes.append(note)
    save()
    spotlightIndexer.indexNote(note)
}

func delete(_ note: Note) {
    notes.removeAll { $0.id == note.id }
    save()
    spotlightIndexer.removeNote(note)
}
```

### 8.4 Verification: Phase 8
- [ ] Capture a text note with unique phrase
- [ ] Open Spotlight (⌘Space), search for that phrase
- [ ] TLNT result appears
- [ ] Click result → TLNT opens
- [ ] Delete note → no longer appears in Spotlight

---

## Phase 9: First Launch & Permissions

### 9.1 Onboarding Flow
```swift
// Views/OnboardingView.swift
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var accessibilityGranted = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "note.text")
                .font(.system(size: 48))

            Text("Welcome to TLNT")
                .font(.title)
                .fontWeight(.semibold)

            Text("Grant Accessibility permission to capture selected text from any app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Grant Permission") {
                let trusted = AXIsProcessTrustedWithOptions(
                    [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                )
                accessibilityGranted = trusted
            }
            .buttonStyle(.borderedProminent)

            if accessibilityGranted {
                Label("Permission granted!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hotkeys:")
                    .fontWeight(.medium)
                HStack {
                    Text("⌘⌥S")
                        .font(.system(.body, design: .monospaced))
                    Text("Send screenshot to TLNT")
                }
                HStack {
                    Text("⌘⌥K")
                        .font(.system(.body, design: .monospaced))
                    Text("Capture selected text")
                }
                HStack {
                    Text("⌘⌥L")
                        .font(.system(.body, design: .monospaced))
                    Text("Open TLNT")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Button("Get Started") {
                isPresented = false
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
            .disabled(!accessibilityGranted)
        }
        .padding(32)
        .frame(width: 400)
    }
}
```

### 9.2 Show on First Launch
```swift
// AppDelegate.swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ...

    if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        showOnboarding()
    }
}
```

### 9.3 Verification: Phase 9
- [ ] Fresh install → onboarding appears
- [ ] Can grant accessibility permission from onboarding
- [ ] "Get Started" only enabled after permission granted
- [ ] Subsequent launches skip onboarding

---

## Phase 10: Polish & Edge Cases

### 10.1 Handle Missing Files Gracefully
- [x] Already handled in ImageNoteView and VideoNoteView with "File not found" state

### 10.2 Menu Bar Dropdown
```swift
func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
        button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "TLNT")
    }

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Open TLNT", action: #selector(openTLNT), keyEquivalent: "l"))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    statusItem?.menu = menu
}
```

### 10.3 Launch at Login (Optional)
```swift
// Can add this in Settings later using SMAppService (macOS 13+)
```

### 10.4 Verification: Phase 10
- [ ] Menu bar dropdown works
- [ ] App handles edge cases without crashing:
  - No screenshots exist
  - Screenshot folder doesn't exist
  - Invalid file paths in notes.json
  - Empty notes.json

---

## Verification Checklist: Full App

### Core Functionality
- [ ] App runs as menu bar app
- [ ] ⌘⌥S sends next unsent screenshot (hash-deduplicated)
- [ ] ⌘⌥K captures selected text from any app
- [ ] ⌘⌥L opens main window
- [ ] Toast notifications appear on capture
- [ ] Main window shows all notes in grid
- [ ] Search works
- [ ] Right-click → Show in Finder works
- [ ] Right-click → Delete works
- [ ] Spotlight search finds text notes
- [ ] Click outside window dismisses it

### Edge Cases
- [ ] No screenshots → "No new screenshots" toast
- [ ] No selected text → nothing happens (or toast)
- [ ] File deleted after capture → shows "File not found"
- [ ] App restart → all notes preserved
- [ ] Hash deduplication prevents duplicates

### Permissions
- [ ] First launch requests Accessibility
- [ ] Works after permission granted
- [ ] Graceful handling if permission denied

---

## Improvement Cycle 1: After Initial Build

### Verify
1. Run through full verification checklist above
2. Note any failures or jank

### Potential Improvements
- [ ] Better video thumbnails (generate from first frame)
- [ ] Configurable hotkeys UI
- [ ] Note timestamps in UI
- [ ] Bulk delete
- [ ] Clear all button
- [ ] Better grid layout (true masonry vs fixed grid)

### Verify Improvements
- [ ] Each improvement tested in isolation
- [ ] Full regression test

---

## Improvement Cycle 2: Robustness

### Verify
1. Stress test: rapid captures, many notes
2. Test with unusual screenshot locations
3. Test with special characters in paths

### Potential Improvements
- [ ] Error handling and logging
- [ ] Crash recovery (corrupted notes.json)
- [ ] Performance with 1000+ notes
- [ ] Memory usage optimization (image caching)

### Verify Improvements
- [ ] Load test with 500 screenshots
- [ ] Test corruption recovery
- [ ] Memory profiling

---

## Improvement Cycle 3: UX Polish

### Verify
1. Use app for a real day of work
2. Note friction points

### Potential Improvements
- [ ] Keyboard navigation in grid
- [ ] Quick Look preview (spacebar)
- [ ] Drag out of TLNT to other apps
- [ ] Better empty state
- [ ] Settings panel for hotkey customization

### Verify Improvements
- [ ] Usability test each feature
- [ ] Ensure no regressions

---

## Build Commands

```bash
# Open in Xcode
cd ~/Documents/Projects/TLNT
open TLNT.xcodeproj

# Build from command line
xcodebuild -project TLNT.xcodeproj -scheme TLNT -configuration Debug build

# Run
open ./build/Debug/TLNT.app
```

---

## Files to Create (In Order)

1. `TLNT.xcodeproj` (via Xcode)
2. `TLNT/App/TLNTApp.swift`
3. `TLNT/App/AppDelegate.swift`
4. `TLNT/Models/Note.swift`
5. `TLNT/Storage/NoteStore.swift`
6. `TLNT/Storage/HashStore.swift`
7. `TLNT/Utilities/FileHasher.swift`
8. `TLNT/Utilities/ScreenshotLocator.swift`
9. `TLNT/Services/ScreenshotWatcher.swift`
10. `TLNT/Services/HotkeyManager.swift`
11. `TLNT/Services/TextCaptureService.swift`
12. `TLNT/Services/SpotlightIndexer.swift`
13. `TLNT/Views/ToastView.swift`
14. `TLNT/Views/MainWindow.swift`
15. `TLNT/Views/MainContentView.swift`
16. `TLNT/Views/NoteItemView.swift`
17. `TLNT/Views/OnboardingView.swift`

---

## Success Criteria

The app is DONE when:
1. All verification checkboxes pass
2. You can take 5 screenshots, send them all via ⌘⌥S, see them in the grid
3. You can highlight text anywhere, press ⌘⌥K, see it in the grid
4. You can search your notes in Spotlight
5. You can right-click → Show in Finder on any screenshot
6. No crashes, no jank, no lost data
