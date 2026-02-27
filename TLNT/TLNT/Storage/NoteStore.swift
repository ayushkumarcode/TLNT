//
//  NoteStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation
import Combine

class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let storageURL: URL
    private var metadataURL: URL { storageURL.appendingPathComponent("notes.json") }

    init() {
        TLNTLogger.debug("NoteStore.init() called", category: TLNTLogger.storage)

        // ~/Documents/TLNT/
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsURL.appendingPathComponent("TLNT")
        TLNTLogger.debug("Storage URL: \(storageURL.path)", category: TLNTLogger.storage)

        ensureDirectoryExists()
        load()

        TLNTLogger.success("NoteStore initialized with \(notes.count) notes", category: TLNTLogger.storage)
    }

    // MARK: - Public Methods

    func add(_ note: Note) {
        TLNTLogger.debug("add(note:) called for note id: \(note.id)", category: TLNTLogger.storage)
        TLNTLogger.debug("Note type: \(note.type), content length: \(note.content.count), tabId: \(note.tabId?.uuidString ?? "nil")", category: TLNTLogger.storage)

        notes.insert(note, at: 0) // Newest first
        TLNTLogger.debug("Note inserted at index 0, total notes: \(notes.count)", category: TLNTLogger.storage)

        save()
        TLNTLogger.success("Note added successfully", category: TLNTLogger.storage)
    }

    func notes(forTabId tabId: UUID?, homeTabId: UUID?) -> [Note] {
        // Notes with nil tabId belong to home tab
        let filtered = notes.filter { note in
            if let noteTabId = note.tabId {
                return noteTabId == tabId
            } else {
                // Legacy notes (nil tabId) belong to home tab
                return tabId == homeTabId || tabId == nil
            }
        }
        // Sort by sortOrder (lower first), then by createdAt (newer first) as fallback
        return filtered.sorted { a, b in
            if a.sortOrder != b.sortOrder {
                return a.sortOrder < b.sortOrder
            }
            return a.createdAt > b.createdAt
        }
    }

    func delete(_ note: Note) {
        TLNTLogger.debug("delete(note:) called for note id: \(note.id)", category: TLNTLogger.storage)

        let countBefore = notes.count
        notes.removeAll { $0.id == note.id }
        let countAfter = notes.count

        TLNTLogger.debug("Notes count before: \(countBefore), after: \(countAfter)", category: TLNTLogger.storage)

        save()
        TLNTLogger.success("Note deleted successfully", category: TLNTLogger.storage)
    }

    func deleteNotesForTab(_ tabId: UUID) {
        TLNTLogger.debug("deleteNotesForTab called for tab id: \(tabId)", category: TLNTLogger.storage)

        let countBefore = notes.count
        notes.removeAll { $0.tabId == tabId }
        let countAfter = notes.count

        TLNTLogger.debug("Notes count before: \(countBefore), after: \(countAfter), deleted: \(countBefore - countAfter)", category: TLNTLogger.storage)

        save()
        TLNTLogger.success("Notes for tab deleted successfully", category: TLNTLogger.storage)
    }

    func update(_ note: Note, content: String) {
        TLNTLogger.debug("update(note:content:) called for note id: \(note.id)", category: TLNTLogger.storage)

        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            let updatedNote = Note(
                id: note.id,
                type: note.type,
                content: content,
                hash: note.hash,
                createdAt: note.createdAt,
                tabId: note.tabId,
                width: note.width,
                height: note.height
            )
            notes[index] = updatedNote
            save()
            TLNTLogger.success("Note updated successfully", category: TLNTLogger.storage)
        }
    }

    func resize(_ note: Note, width: CGFloat?, height: CGFloat?) {
        TLNTLogger.debug("resize(note:) called for note id: \(note.id), width: \(width ?? 0), height: \(height ?? 0)", category: TLNTLogger.storage)

        // Store previous state for undo
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            let previousNote = notes[index]
            undoStack.append(UndoAction(noteId: note.id, previousWidth: previousNote.width, previousHeight: previousNote.height))

            let updatedNote = Note(
                id: note.id,
                type: note.type,
                content: note.content,
                hash: note.hash,
                createdAt: note.createdAt,
                tabId: note.tabId,
                width: width,
                height: height
            )
            notes[index] = updatedNote
            save()
            TLNTLogger.success("Note resized successfully", category: TLNTLogger.storage)
        }
    }

    // MARK: - Undo Support

    struct UndoAction {
        let noteId: UUID
        let previousWidth: CGFloat?
        let previousHeight: CGFloat?
    }

    private var undoStack: [UndoAction] = []

    func undo() {
        guard let action = undoStack.popLast() else {
            TLNTLogger.debug("Nothing to undo", category: TLNTLogger.storage)
            return
        }

        TLNTLogger.debug("Undoing resize for note: \(action.noteId)", category: TLNTLogger.storage)

        if let index = notes.firstIndex(where: { $0.id == action.noteId }) {
            let currentNote = notes[index]
            let restoredNote = Note(
                id: currentNote.id,
                type: currentNote.type,
                content: currentNote.content,
                hash: currentNote.hash,
                createdAt: currentNote.createdAt,
                tabId: currentNote.tabId,
                width: action.previousWidth,
                height: action.previousHeight
            )
            notes[index] = restoredNote
            save()
            TLNTLogger.success("Undo successful", category: TLNTLogger.storage)
        }
    }

    func containsHash(_ hash: String) -> Bool {
        TLNTLogger.debug("containsHash() called with hash: \(hash.prefix(16))...", category: TLNTLogger.storage)

        let result = notes.contains { $0.hash == hash }
        TLNTLogger.debug("containsHash result: \(result)", category: TLNTLogger.storage)

        return result
    }

    func note(withId id: UUID) -> Note? {
        TLNTLogger.debug("note(withId:) called for id: \(id)", category: TLNTLogger.storage)

        let result = notes.first { $0.id == id }
        TLNTLogger.debug("note(withId:) result: \(result != nil ? "found" : "not found")", category: TLNTLogger.storage)

        return result
    }

    // MARK: - Move and Reorder

    /// Move a note to a different tab
    func moveNote(_ note: Note, toTabId newTabId: UUID?) {
        TLNTLogger.debug("moveNote called for note: \(note.id) to tab: \(newTabId?.uuidString ?? "home")", category: TLNTLogger.storage)

        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updatedNote = notes[index]
            updatedNote.tabId = newTabId
            // Set sort order to 0 to put it at the top of the new tab
            updatedNote.sortOrder = 0
            // Increment all other notes in the target tab
            for i in notes.indices {
                if notes[i].tabId == newTabId && notes[i].id != note.id {
                    notes[i].sortOrder += 1
                }
            }
            notes[index] = updatedNote
            save()
            TLNTLogger.success("Note moved to new tab", category: TLNTLogger.storage)
        }
    }

    /// Reorder notes within a tab - move sourceNote to the position before targetNote
    func reorderNote(_ sourceNote: Note, before targetNote: Note) {
        TLNTLogger.debug("reorderNote called: \(sourceNote.id) before \(targetNote.id)", category: TLNTLogger.storage)

        guard sourceNote.id != targetNote.id else { return }
        guard let sourceIndex = notes.firstIndex(where: { $0.id == sourceNote.id }),
              let targetIndex = notes.firstIndex(where: { $0.id == targetNote.id }) else { return }

        // Get the target sort order
        let targetOrder = notes[targetIndex].sortOrder

        // Update sort orders
        for i in notes.indices {
            if notes[i].tabId == targetNote.tabId {
                if notes[i].id == sourceNote.id {
                    notes[i].sortOrder = targetOrder
                } else if notes[i].sortOrder >= targetOrder {
                    notes[i].sortOrder += 1
                }
            }
        }

        save()
        TLNTLogger.success("Note reordered", category: TLNTLogger.storage)
    }

    /// Import an image file as a screenshot note
    func importImage(from url: URL, tabId: UUID?) -> Note? {
        TLNTLogger.debug("importImage called for: \(url.path)", category: TLNTLogger.storage)

        // Check if it's an image file
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]
        guard imageExtensions.contains(url.pathExtension.lowercased()) else {
            TLNTLogger.error("Not an image file: \(url.pathExtension)", category: TLNTLogger.storage)
            return nil
        }

        // Copy the file to our storage directory
        let fm = FileManager.default
        let screenshotsDir = storageURL.appendingPathComponent("Screenshots")

        // Ensure screenshots directory exists
        if !fm.fileExists(atPath: screenshotsDir.path) {
            try? fm.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        }

        // Generate unique filename
        let filename = "\(UUID().uuidString).\(url.pathExtension)"
        let destURL = screenshotsDir.appendingPathComponent(filename)

        do {
            try fm.copyItem(at: url, to: destURL)
            TLNTLogger.debug("Copied image to: \(destURL.path)", category: TLNTLogger.storage)

            // Create note
            let note = Note(
                type: .screenshot,
                content: destURL.path,
                tabId: tabId,
                sortOrder: 0
            )

            // Increment sort orders for other notes in this tab
            for i in notes.indices {
                if notes[i].tabId == tabId {
                    notes[i].sortOrder += 1
                }
            }

            notes.insert(note, at: 0)
            save()

            TLNTLogger.success("Image imported successfully", category: TLNTLogger.storage)
            return note
        } catch {
            TLNTLogger.error("Failed to copy image: \(error)", category: TLNTLogger.storage)
            return nil
        }
    }

    // MARK: - Private Methods

    private func ensureDirectoryExists() {
        TLNTLogger.debug("ensureDirectoryExists() called", category: TLNTLogger.storage)

        let fm = FileManager.default
        if !fm.fileExists(atPath: storageURL.path) {
            TLNTLogger.debug("Directory does not exist, creating: \(storageURL.path)", category: TLNTLogger.storage)

            do {
                try fm.createDirectory(at: storageURL, withIntermediateDirectories: true)
                TLNTLogger.success("Directory created: \(storageURL.path)", category: TLNTLogger.storage)
            } catch {
                TLNTLogger.error("Failed to create directory: \(error)", category: TLNTLogger.storage)
            }
        } else {
            TLNTLogger.debug("Directory already exists: \(storageURL.path)", category: TLNTLogger.storage)
        }
    }

    private func load() {
        TLNTLogger.debug("load() called", category: TLNTLogger.storage)
        TLNTLogger.debug("Loading from: \(metadataURL.path)", category: TLNTLogger.storage)

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            TLNTLogger.info("notes.json does not exist, starting with empty array", category: TLNTLogger.storage)
            notes = []
            return
        }

        do {
            TLNTLogger.debug("Reading notes.json file...", category: TLNTLogger.storage)
            let data = try Data(contentsOf: metadataURL)
            TLNTLogger.debug("Read \(data.count) bytes from notes.json", category: TLNTLogger.storage)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            TLNTLogger.debug("Decoding JSON...", category: TLNTLogger.storage)
            notes = try decoder.decode([Note].self, from: data)
            TLNTLogger.success("Loaded \(notes.count) notes from disk", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to load notes: \(error)", category: TLNTLogger.storage)
            notes = []
        }
    }

    private func save() {
        TLNTLogger.debug("save() called", category: TLNTLogger.storage)
        TLNTLogger.debug("Saving \(notes.count) notes to: \(metadataURL.path)", category: TLNTLogger.storage)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            TLNTLogger.debug("Encoding notes to JSON...", category: TLNTLogger.storage)
            let data = try encoder.encode(notes)
            TLNTLogger.debug("Encoded to \(data.count) bytes", category: TLNTLogger.storage)

            TLNTLogger.debug("Writing to disk...", category: TLNTLogger.storage)
            try data.write(to: metadataURL, options: .atomic)
            TLNTLogger.success("Saved \(notes.count) notes to disk", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to save notes: \(error)", category: TLNTLogger.storage)
        }
    }
}
