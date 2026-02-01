//
//  FileHasher.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation
import CryptoKit

enum FileHasher {

    /// Computes SHA256 hash of a file
    static func sha256(fileAt url: URL) -> String? {
        TLNTLogger.debug("sha256(fileAt: \(url.lastPathComponent)) called", category: TLNTLogger.storage)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            TLNTLogger.error("File does not exist: \(url.path)", category: TLNTLogger.storage)
            return nil
        }

        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                TLNTLogger.debug("File size: \(fileSize) bytes", category: TLNTLogger.storage)

                // Warn if file is very large
                if fileSize > 100_000_000 { // 100MB
                    TLNTLogger.warning("File is very large (\(fileSize) bytes), hashing may take time", category: TLNTLogger.storage)
                }
            }
        } catch {
            TLNTLogger.warning("Could not get file attributes: \(error)", category: TLNTLogger.storage)
        }

        TLNTLogger.debug("Reading file data...", category: TLNTLogger.storage)
        guard let data = try? Data(contentsOf: url) else {
            TLNTLogger.error("Failed to read file data: \(url.path)", category: TLNTLogger.storage)
            return nil
        }
        TLNTLogger.debug("Read \(data.count) bytes", category: TLNTLogger.storage)

        TLNTLogger.debug("Computing SHA256 hash...", category: TLNTLogger.storage)
        let hash = SHA256.hash(data: data)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        TLNTLogger.debug("Hash computed: \(hashString.prefix(16))...", category: TLNTLogger.storage)

        return hashString
    }

    /// Computes SHA256 hash of a string
    static func sha256(string: String) -> String {
        TLNTLogger.debug("sha256(string:) called, length: \(string.count)", category: TLNTLogger.storage)

        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()

        TLNTLogger.debug("String hash computed: \(hashString.prefix(16))...", category: TLNTLogger.storage)
        return hashString
    }
}
