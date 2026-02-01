//
//  HashStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation

class HashStore {
    private var hashes: Set<String> = []
    private let fileURL: URL

    init() {
        TLNTLogger.debug("HashStore.init() called", category: TLNTLogger.storage)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tlntURL = documentsURL.appendingPathComponent("TLNT")
        fileURL = tlntURL.appendingPathComponent("hashes.json")
        TLNTLogger.debug("Hash file URL: \(fileURL.path)", category: TLNTLogger.storage)

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(at: tlntURL, withIntermediateDirectories: true)
            TLNTLogger.debug("Ensured TLNT directory exists", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to create TLNT directory: \(error)", category: TLNTLogger.storage)
        }

        load()
        TLNTLogger.success("HashStore initialized with \(hashes.count) hashes", category: TLNTLogger.storage)
    }

    // MARK: - Public Methods

    func contains(_ hash: String) -> Bool {
        TLNTLogger.debug("contains() called with hash: \(hash.prefix(16))...", category: TLNTLogger.storage)
        let result = hashes.contains(hash)
        TLNTLogger.debug("contains() result: \(result)", category: TLNTLogger.storage)
        return result
    }

    func add(_ hash: String) {
        TLNTLogger.debug("add() called with hash: \(hash.prefix(16))...", category: TLNTLogger.storage)

        let countBefore = hashes.count
        hashes.insert(hash)
        let countAfter = hashes.count

        TLNTLogger.debug("Hashes count before: \(countBefore), after: \(countAfter)", category: TLNTLogger.storage)

        save()
        TLNTLogger.success("Hash added successfully", category: TLNTLogger.storage)
    }

    func remove(_ hash: String) {
        TLNTLogger.debug("remove() called with hash: \(hash.prefix(16))...", category: TLNTLogger.storage)

        let countBefore = hashes.count
        hashes.remove(hash)
        let countAfter = hashes.count

        TLNTLogger.debug("Hashes count before: \(countBefore), after: \(countAfter)", category: TLNTLogger.storage)

        save()
        TLNTLogger.success("Hash removed successfully", category: TLNTLogger.storage)
    }

    // MARK: - Private Methods

    private func load() {
        TLNTLogger.debug("load() called", category: TLNTLogger.storage)
        TLNTLogger.debug("Loading from: \(fileURL.path)", category: TLNTLogger.storage)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            TLNTLogger.info("hashes.json does not exist, starting with empty set", category: TLNTLogger.storage)
            hashes = []
            return
        }

        do {
            TLNTLogger.debug("Reading hashes.json file...", category: TLNTLogger.storage)
            let data = try Data(contentsOf: fileURL)
            TLNTLogger.debug("Read \(data.count) bytes from hashes.json", category: TLNTLogger.storage)

            TLNTLogger.debug("Decoding JSON...", category: TLNTLogger.storage)
            let array = try JSONDecoder().decode([String].self, from: data)
            hashes = Set(array)
            TLNTLogger.success("Loaded \(hashes.count) hashes from disk", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to load hashes: \(error)", category: TLNTLogger.storage)
            hashes = []
        }
    }

    private func save() {
        TLNTLogger.debug("save() called", category: TLNTLogger.storage)
        TLNTLogger.debug("Saving \(hashes.count) hashes to: \(fileURL.path)", category: TLNTLogger.storage)

        do {
            let array = Array(hashes)
            TLNTLogger.debug("Converting set to array...", category: TLNTLogger.storage)

            let data = try JSONEncoder().encode(array)
            TLNTLogger.debug("Encoded to \(data.count) bytes", category: TLNTLogger.storage)

            try data.write(to: fileURL, options: .atomic)
            TLNTLogger.success("Saved \(hashes.count) hashes to disk", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to save hashes: \(error)", category: TLNTLogger.storage)
        }
    }
}
