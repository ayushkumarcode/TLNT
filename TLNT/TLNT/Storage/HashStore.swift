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
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tlntURL = documentsURL.appendingPathComponent("TLNT")
        fileURL = tlntURL.appendingPathComponent("hashes.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: tlntURL, withIntermediateDirectories: true)

        load()
    }

    // MARK: - Public Methods

    func contains(_ hash: String) -> Bool {
        return hashes.contains(hash)
    }

    func add(_ hash: String) {
        hashes.insert(hash)
        save()
    }

    func remove(_ hash: String) {
        hashes.remove(hash)
        save()
    }

    // MARK: - Private Methods

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            hashes = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let array = try JSONDecoder().decode([String].self, from: data)
            hashes = Set(array)
        } catch {
            print("Failed to load hashes: \(error)")
            hashes = []
        }
    }

    private func save() {
        do {
            let array = Array(hashes)
            let data = try JSONEncoder().encode(array)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save hashes: \(error)")
        }
    }
}
