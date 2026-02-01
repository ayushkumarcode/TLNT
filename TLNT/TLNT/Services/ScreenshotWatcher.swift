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
        TLNTLogger.debug("ScreenshotWatcher.init() called", category: TLNTLogger.screenshot)
        self.noteStore = noteStore
        self.hashStore = hashStore
        self.spotlightIndexer = spotlightIndexer
        TLNTLogger.debug("ScreenshotWatcher initialized", category: TLNTLogger.screenshot)
    }

    /// Gets the next unsent screenshot/recording (newest first, skipping already-sent)
    func getNextUnsent() -> URL? {
        TLNTLogger.debug("getNextUnsent() called", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Getting screenshot folder...", category: TLNTLogger.screenshot)
        let folder = ScreenshotLocator.getScreenshotFolder()
        TLNTLogger.debug("Screenshot folder: \(folder.path)", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Getting screenshots in folder...", category: TLNTLogger.screenshot)
        let files = ScreenshotLocator.getScreenshots(in: folder)
        TLNTLogger.debug("Found \(files.count) screenshots/recordings", category: TLNTLogger.screenshot)

        if files.isEmpty {
            TLNTLogger.warning("No screenshots found in folder", category: TLNTLogger.screenshot)
            return nil
        }

        for (index, file) in files.enumerated() {
            TLNTLogger.debug("Checking file[\(index)]: \(file.lastPathComponent)", category: TLNTLogger.screenshot)

            // Check if file exists
            guard FileManager.default.fileExists(atPath: file.path) else {
                TLNTLogger.warning("File does not exist: \(file.path)", category: TLNTLogger.screenshot)
                continue
            }

            TLNTLogger.debug("Computing hash for: \(file.lastPathComponent)", category: TLNTLogger.screenshot)
            guard let hash = FileHasher.sha256(fileAt: file) else {
                TLNTLogger.error("Failed to compute hash for: \(file.lastPathComponent)", category: TLNTLogger.screenshot)
                continue
            }
            TLNTLogger.debug("Hash computed: \(hash.prefix(16))...", category: TLNTLogger.screenshot)

            // Check hash store
            let inHashStore = hashStore.contains(hash)
            TLNTLogger.debug("Hash in hashStore: \(inHashStore)", category: TLNTLogger.screenshot)

            // Check note store
            let inNoteStore = noteStore.containsHash(hash)
            TLNTLogger.debug("Hash in noteStore: \(inNoteStore)", category: TLNTLogger.screenshot)

            if !inHashStore && !inNoteStore {
                TLNTLogger.success("Found unsent file: \(file.lastPathComponent)", category: TLNTLogger.screenshot)
                return file
            } else {
                TLNTLogger.debug("File already sent, skipping: \(file.lastPathComponent)", category: TLNTLogger.screenshot)
            }
        }

        TLNTLogger.info("All files have already been sent", category: TLNTLogger.screenshot)
        return nil
    }

    /// Sends the next unsent screenshot to TLNT
    /// Returns true if a screenshot was added, false if none available
    @discardableResult
    func sendNext() -> Bool {
        TLNTLogger.info("=== sendNext() START ===", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Calling getNextUnsent()...", category: TLNTLogger.screenshot)
        guard let file = getNextUnsent() else {
            TLNTLogger.info("getNextUnsent() returned nil - no files to send", category: TLNTLogger.screenshot)
            TLNTLogger.info("=== sendNext() END (no file) ===", category: TLNTLogger.screenshot)
            return false
        }

        TLNTLogger.debug("Got file to send: \(file.path)", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Computing hash for file...", category: TLNTLogger.screenshot)
        guard let hash = FileHasher.sha256(fileAt: file) else {
            TLNTLogger.error("Failed to compute hash for file: \(file.path)", category: TLNTLogger.screenshot)
            TLNTLogger.info("=== sendNext() END (hash failed) ===", category: TLNTLogger.screenshot)
            return false
        }
        TLNTLogger.debug("Hash: \(hash.prefix(16))...", category: TLNTLogger.screenshot)

        // Determine type based on extension
        let ext = file.pathExtension.lowercased()
        TLNTLogger.debug("File extension: \(ext)", category: TLNTLogger.screenshot)

        let type: Note.NoteType = ext == "mov" ? .recording : .screenshot
        TLNTLogger.debug("Note type: \(type)", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Creating Note object...", category: TLNTLogger.screenshot)
        let note = Note(
            type: type,
            content: file.path,
            hash: hash
        )
        TLNTLogger.debug("Note created with id: \(note.id)", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Adding note to noteStore...", category: TLNTLogger.screenshot)
        noteStore.add(note)
        TLNTLogger.success("Note added to noteStore", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Adding hash to hashStore...", category: TLNTLogger.screenshot)
        hashStore.add(hash)
        TLNTLogger.success("Hash added to hashStore", category: TLNTLogger.screenshot)

        TLNTLogger.debug("Indexing note in Spotlight...", category: TLNTLogger.screenshot)
        spotlightIndexer.indexNote(note)
        TLNTLogger.success("Note indexed in Spotlight", category: TLNTLogger.screenshot)

        TLNTLogger.success("=== sendNext() END (success) ===", category: TLNTLogger.screenshot)
        return true
    }
}
