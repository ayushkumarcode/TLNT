//
//  Journal.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import Foundation

struct Journal: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let coverStyle: CoverStyle
    let createdAt: Date
    var lastOpenedAt: Date

    init(id: UUID = UUID(), title: String = "Untitled Journal", coverStyle: CoverStyle = .black, createdAt: Date = Date(), lastOpenedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.coverStyle = coverStyle
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }
}

enum CoverStyle: String, Codable, CaseIterable {
    case black
    case brown
    case burgundy
    case navy
    case forest
}
