//
//  Tab.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/2/26.
//

import Foundation

struct Tab: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let isHome: Bool  // Home tab cannot be deleted or renamed
    let createdAt: Date

    init(id: UUID = UUID(), name: String, isHome: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.isHome = isHome
        self.createdAt = createdAt
    }

    static let home = Tab(name: "Home", isHome: true)
}
