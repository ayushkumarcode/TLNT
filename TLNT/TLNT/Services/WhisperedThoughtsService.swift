//
//  WhisperedThoughtsService.swift
//  TLNT
//
//  Watches ~/Documents/Projects/thoughts/ for YYYY-MM-DD.md files,
//  synthesizes each via Claude API into memory-jogging bullet points,
//  and upserts pages into the "Whispered Thoughts" journal.
//

import Foundation
import CryptoKit

class WhisperedThoughtsService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let journalStore: JournalStore
    private var journal: Journal?

    /// The folder to watch for YYYY-MM-DD.md files.
    /// Stored as a security-scoped bookmark in UserDefaults so it persists across launches.
    /// Defaults to ~/Documents/thoughts/ if no bookmark is saved.
    var thoughtsFolder: URL {
        get {
            if let data = UserDefaults.standard.data(forKey: "whisperedThoughtsFolderBookmark"),
               let url = Self.resolveBookmark(data) {
                return url
            }
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("thoughts")
        }
    }

    private static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: .withSecurityScope,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else { return nil }
        if isStale { return nil }
        return url
    }

    /// Call this from an NSOpenPanel handler to let the user pick the thoughts folder.
    func setThoughtsFolder(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil) else { return }
        UserDefaults.standard.set(bookmark, forKey: "whisperedThoughtsFolderBookmark")
        Task { await sync() }
    }
    private var timer: Timer?

    private static let apiKeyName = "anthropic_api_key"

    init(journalStore: JournalStore) {
        self.journalStore = journalStore
        journal = journalStore.ensureWhisperedThoughtsJournal()
        startTimer()
        Task { await sync() }
    }

    // MARK: - API Key

    var apiKey: String? {
        get { KeychainHelper.load(key: Self.apiKeyName) }
        set {
            if let key = newValue, !key.isEmpty {
                KeychainHelper.save(key: Self.apiKeyName, value: key)
            } else {
                KeychainHelper.delete(key: Self.apiKeyName)
            }
        }
    }

    var hasAPIKey: Bool { apiKey != nil }

    // MARK: - Sync

    @MainActor
    func sync() async {
        guard let apiKey = apiKey else {
            syncError = "No Anthropic API key set. Right-click Whispered Thoughts on the shelf to add one."
            return
        }
        guard let journal = journal else { return }
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        let pages = journalStore.getPages(for: journal.id)
        let filesToSync = await collectFilesNeedingSync(pages: pages)

        for item in filesToSync {
            guard let synthesized = await synthesize(content: item.content, dateString: item.dateString, apiKey: apiKey) else {
                TLNTLogger.error("Synthesis failed for \(item.dateString)", category: TLNTLogger.app)
                continue
            }
            journalStore.upsertPage(
                for: journal.id,
                sourceDate: item.dateString,
                content: synthesized,
                sourceHash: item.hash
            )
        }

        isSyncing = false
        lastSyncDate = Date()
        TLNTLogger.success("Whispered Thoughts sync complete (\(filesToSync.count) updated)", category: TLNTLogger.app)
    }

    // MARK: - File Collection

    private struct SyncItem {
        let dateString: String
        let content: String
        let hash: String
    }

    private func collectFilesNeedingSync(pages: [JournalPage]) async -> [SyncItem] {
        return await Task.detached(priority: .background) { [thoughtsFolder] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: thoughtsFolder, includingPropertiesForKeys: nil) else { return [] }

            return files
                .filter { Self.isDateFilename($0.lastPathComponent) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .compactMap { file -> SyncItem? in
                    let dateString = String(file.lastPathComponent.dropLast(3)) // strip .md
                    guard let content = try? String(contentsOf: file, encoding: .utf8), !content.isEmpty else { return nil }
                    let hash = Self.sha256(content)
                    let existing = pages.first(where: { $0.sourceDate == dateString })
                    guard existing?.sourceHash != hash else { return nil } // already up to date
                    return SyncItem(dateString: dateString, content: content, hash: hash)
                }
        }.value
    }

    // MARK: - Claude API

    private func synthesize(content: String, dateString: String, apiKey: String) async -> String? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }

        let system = """
        You synthesize personal voice journal entries into memory-jogging bullet points.

        Rules:
        - Each bullet must be specific enough that reading it months later brings back the exact idea, feeling, or insight
        - Never write generic summaries like "talked about X" — capture the actual thought or observation
        - Write in fragments, not full sentences; lean and vivid
        - 4–8 bullets per entry (more if the entry covers many distinct ideas)
        - Preserve names, products, numbers, and emotions that make memories specific
        - Group naturally by topic if the entry has clear themes; no headers needed
        - Output only the bullet list using "- " prefixes, no preamble or closing remarks
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 600,
            "system": system,
            "messages": [["role": "user", "content": "Date: \(dateString)\n\n\(content)"]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArray = json["content"] as? [[String: Any]],
                  let text = contentArray.first?["text"] as? String else {
                TLNTLogger.error("Unexpected API response for \(dateString)", category: TLNTLogger.app)
                return nil
            }
            return text
        } catch {
            TLNTLogger.error("API request failed: \(error)", category: TLNTLogger.app)
            return nil
        }
    }

    // MARK: - Helpers

    private static func isDateFilename(_ filename: String) -> Bool {
        filename.range(of: #"^\d{4}-\d{2}-\d{2}\.md$"#, options: .regularExpression) != nil
    }

    private static func sha256(_ string: String) -> String {
        let hash = SHA256.hash(data: Data(string.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { await self?.sync() }
        }
    }

    deinit { timer?.invalidate() }
}
