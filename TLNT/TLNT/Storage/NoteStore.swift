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
        // ~/Documents/TLNT/
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsURL.appendingPathComponent("TLNT")

        ensureDirectoryExists()
        load()
    }

    // MARK: - Public Methods

    func add(_ note: Note) {
        notes.insert(note, at: 0) // Newest first
        save()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    func containsHash(_ hash: String) -> Bool {
        return notes.contains { $0.hash == hash }
    }

    func note(withId id: UUID) -> Note? {
        return notes.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageURL.path) {
            try? fm.createDirectory(at: storageURL, withIntermediateDirectories: true)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            notes = []
            return
        }

        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            print("Failed to load notes: \(error)")
            notes = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("Failed to save notes: \(error)")
        }
    }
}
