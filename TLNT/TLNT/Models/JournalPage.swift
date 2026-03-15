//
//  JournalPage.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import Foundation

struct JournalPage: Identifiable, Codable, Equatable {
    let id: UUID
    let journalId: UUID
    var pageNumber: Int
    var content: String // Markdown
    let createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), journalId: UUID, pageNumber: Int, content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.journalId = journalId
        self.pageNumber = pageNumber
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
