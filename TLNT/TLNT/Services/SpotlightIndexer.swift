//
//  SpotlightIndexer.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

class SpotlightIndexer {
    private let index = CSSearchableIndex.default()
    private let domainIdentifier = "com.tlnt.notes"

    // MARK: - Index Note

    func indexNote(_ note: Note) {
        let attributeSet: CSSearchableItemAttributeSet

        switch note.type {
        case .text:
            attributeSet = CSSearchableItemAttributeSet(contentType: UTType.text)
            attributeSet.textContent = note.content
            attributeSet.title = String(note.content.prefix(50))
            attributeSet.contentDescription = note.content

        case .screenshot:
            attributeSet = CSSearchableItemAttributeSet(contentType: UTType.image)
            attributeSet.title = "TLNT Screenshot"
            attributeSet.contentDescription = URL(fileURLWithPath: note.content).lastPathComponent

        case .recording:
            attributeSet = CSSearchableItemAttributeSet(contentType: UTType.movie)
            attributeSet.title = "TLNT Recording"
            attributeSet.contentDescription = URL(fileURLWithPath: note.content).lastPathComponent
        }

        attributeSet.contentCreationDate = note.createdAt
        attributeSet.contentModificationDate = note.createdAt

        let item = CSSearchableItem(
            uniqueIdentifier: note.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // Keep in index for 30 days
        item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

        index.indexSearchableItems([item]) { error in
            if let error = error {
                print("Spotlight indexing error: \(error)")
            }
        }
    }

    // MARK: - Remove Note

    func removeNote(_ note: Note) {
        index.deleteSearchableItems(withIdentifiers: [note.id.uuidString]) { error in
            if let error = error {
                print("Spotlight removal error: \(error)")
            }
        }
    }

    // MARK: - Reindex All

    func reindexAll(notes: [Note]) {
        // First delete all items in our domain
        index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { [weak self] error in
            if let error = error {
                print("Spotlight clear error: \(error)")
            }

            // Then re-add all notes
            for note in notes {
                self?.indexNote(note)
            }
        }
    }
}
