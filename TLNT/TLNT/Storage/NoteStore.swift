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
        TLNTLogger.debug("Note type: \(note.type), content length: \(note.content.count)", category: TLNTLogger.storage)

        notes.insert(note, at: 0) // Newest first
        TLNTLogger.debug("Note inserted at index 0, total notes: \(notes.count)", category: TLNTLogger.storage)

        save()
        TLNTLogger.success("Note added successfully", category: TLNTLogger.storage)
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
