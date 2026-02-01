//
//  Note.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let type: NoteType
    let content: String  // Text content OR file path for media
    let hash: String?    // SHA256 for media files (nil for text)
    let createdAt: Date

    enum NoteType: String, Codable {
        case text
        case screenshot
        case recording
    }

    init(id: UUID = UUID(), type: NoteType, content: String, hash: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.content = content
        self.hash = hash
        self.createdAt = createdAt
    }
}
