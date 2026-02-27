//
//  Note.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let type: NoteType
    let content: String  // Text content OR file path for media
    let hash: String?    // SHA256 for media files (nil for text)
    let createdAt: Date
    var tabId: UUID?     // Which tab this note belongs to (nil = home tab for backwards compat)
    var width: CGFloat?  // Custom width for resizable notes (nil = auto)
    var height: CGFloat? // Custom height for resizable notes (nil = auto)
    var sortOrder: Int   // Order within the tab (lower = earlier)

    enum NoteType: String, Codable {
        case text
        case screenshot
        case recording
    }

    init(id: UUID = UUID(), type: NoteType, content: String, hash: String? = nil, createdAt: Date = Date(), tabId: UUID? = nil, width: CGFloat? = nil, height: CGFloat? = nil, sortOrder: Int = 0) {
        self.id = id
        self.type = type
        self.content = content
        self.hash = hash
        self.createdAt = createdAt
        self.tabId = tabId
        self.width = width
        self.height = height
        self.sortOrder = sortOrder
    }
}

// MARK: - Transferable for Drag & Drop

extension Note: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .tlntNote)
    }
}

extension UTType {
    static let tlntNote = UTType(exportedAs: "com.ayushkumar.tlnt.note")
}
