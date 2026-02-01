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
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA256 hash of a string
    static func sha256(string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
