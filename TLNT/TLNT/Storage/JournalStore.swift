//
//  JournalStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import Foundation

class JournalStore: ObservableObject {
    @Published private(set) var journals: [Journal] = []
    @Published private(set) var currentPages: [JournalPage] = []

    private let storageURL: URL
    private var journalsURL: URL { storageURL.appendingPathComponent("journals.json") }

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsURL.appendingPathComponent("TLNT")
        TLNTLogger.debug("JournalStore storage URL: \(storageURL.path)", category: TLNTLogger.storage)

        ensureDirectoryExists()
        loadJournals()
        TLNTLogger.success("JournalStore initialized with \(journals.count) journals", category: TLNTLogger.storage)
    }

    // MARK: - Journal CRUD

    func addJournal(title: String = "Untitled Journal", coverStyle: CoverStyle = .black) -> Journal {
        let journal = Journal(title: title, coverStyle: coverStyle)
        journals.append(journal)
        saveJournals()

        // Create the journal's page directory and first page
        ensureJournalDirectory(for: journal.id)
        let firstPage = JournalPage(journalId: journal.id, pageNumber: 1)
        savePages([firstPage], for: journal.id)

        TLNTLogger.success("Journal added: \(journal.title)", category: TLNTLogger.storage)
        return journal
    }

    func deleteJournal(_ journal: Journal) {
        journals.removeAll { $0.id == journal.id }
        saveJournals()

        // Remove journal directory
        let journalDir = storageURL.appendingPathComponent("Journals/\(journal.id.uuidString)")
        try? FileManager.default.removeItem(at: journalDir)

        TLNTLogger.success("Journal deleted: \(journal.title)", category: TLNTLogger.storage)
    }

    func updateJournal(_ journal: Journal) {
        if let index = journals.firstIndex(where: { $0.id == journal.id }) {
            journals[index] = journal
            saveJournals()
        }
    }

    // MARK: - Page Operations

    func loadPages(for journalId: UUID) -> [JournalPage] {
        let pagesURL = pagesURL(for: journalId)
        guard FileManager.default.fileExists(atPath: pagesURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: pagesURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let pages = try decoder.decode([JournalPage].self, from: data)
            currentPages = pages.sorted { $0.pageNumber < $1.pageNumber }
            return currentPages
        } catch {
            TLNTLogger.error("Failed to load pages: \(error)", category: TLNTLogger.storage)
            return []
        }
    }

    func addPage(to journalId: UUID) -> JournalPage {
        var pages = loadPages(for: journalId)
        let nextNumber = (pages.map(\.pageNumber).max() ?? 0) + 1
        let page = JournalPage(journalId: journalId, pageNumber: nextNumber)
        pages.append(page)
        savePages(pages, for: journalId)
        currentPages = pages
        TLNTLogger.success("Page \(nextNumber) added to journal", category: TLNTLogger.storage)
        return page
    }

    func updatePage(_ page: JournalPage) {
        var pages = loadPages(for: page.journalId)
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            var updated = page
            updated.modifiedAt = Date()
            pages[index] = updated
            savePages(pages, for: page.journalId)
            currentPages = pages
        }
    }

    func deletePage(_ page: JournalPage) {
        var pages = loadPages(for: page.journalId)
        pages.removeAll { $0.id == page.id }

        // Renumber remaining pages
        for i in pages.indices {
            pages[i].pageNumber = i + 1
        }

        savePages(pages, for: page.journalId)
        currentPages = pages
    }

    func searchPages(in journalId: UUID, query: String) -> [JournalPage] {
        let pages = loadPages(for: journalId)
        guard !query.isEmpty else { return pages }
        return pages.filter { $0.content.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Private

    private func pagesURL(for journalId: UUID) -> URL {
        storageURL.appendingPathComponent("Journals/\(journalId.uuidString)/pages.json")
    }

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        let journalsDir = storageURL.appendingPathComponent("Journals")
        if !fm.fileExists(atPath: journalsDir.path) {
            try? fm.createDirectory(at: journalsDir, withIntermediateDirectories: true)
        }
    }

    private func ensureJournalDirectory(for journalId: UUID) {
        let journalDir = storageURL.appendingPathComponent("Journals/\(journalId.uuidString)")
        if !FileManager.default.fileExists(atPath: journalDir.path) {
            try? FileManager.default.createDirectory(at: journalDir, withIntermediateDirectories: true)
        }
    }

    private func loadJournals() {
        guard FileManager.default.fileExists(atPath: journalsURL.path) else {
            journals = []
            return
        }

        do {
            let data = try Data(contentsOf: journalsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            journals = try decoder.decode([Journal].self, from: data)
        } catch {
            TLNTLogger.error("Failed to load journals: \(error)", category: TLNTLogger.storage)
            journals = []
        }
    }

    private func saveJournals() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(journals)
            try data.write(to: journalsURL, options: .atomic)
        } catch {
            TLNTLogger.error("Failed to save journals: \(error)", category: TLNTLogger.storage)
        }
    }

    private func savePages(_ pages: [JournalPage], for journalId: UUID) {
        ensureJournalDirectory(for: journalId)
        let url = pagesURL(for: journalId)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(pages)
            try data.write(to: url, options: .atomic)
        } catch {
            TLNTLogger.error("Failed to save pages: \(error)", category: TLNTLogger.storage)
        }
    }
}
