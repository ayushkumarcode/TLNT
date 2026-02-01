//
//  ScreenshotWatcher.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation

class ScreenshotWatcher {
    private let noteStore: NoteStore
    private let hashStore: HashStore
    private let spotlightIndexer: SpotlightIndexer

    init(noteStore: NoteStore, hashStore: HashStore, spotlightIndexer: SpotlightIndexer) {
        self.noteStore = noteStore
        self.hashStore = hashStore
        self.spotlightIndexer = spotlightIndexer
    }

    /// Gets the next unsent screenshot/recording (newest first, skipping already-sent)
    func getNextUnsent() -> URL? {
        let folder = ScreenshotLocator.getScreenshotFolder()
        let files = ScreenshotLocator.getScreenshots(in: folder)

        for file in files {
            guard let hash = FileHasher.sha256(fileAt: file) else { continue }

            // Check both hash store and note store
            if !hashStore.contains(hash) && !noteStore.containsHash(hash) {
                return file
            }
        }

        return nil
    }

    /// Sends the next unsent screenshot to TLNT
    /// Returns true if a screenshot was added, false if none available
    @discardableResult
    func sendNext() -> Bool {
        guard let file = getNextUnsent() else {
            return false
        }

        guard let hash = FileHasher.sha256(fileAt: file) else {
            return false
        }

        // Determine type based on extension
        let type: Note.NoteType = file.pathExtension.lowercased() == "mov" ? .recording : .screenshot

        let note = Note(
            type: type,
            content: file.path,
            hash: hash
        )

        noteStore.add(note)
        hashStore.add(hash)
        spotlightIndexer.indexNote(note)

        return true
    }
}
