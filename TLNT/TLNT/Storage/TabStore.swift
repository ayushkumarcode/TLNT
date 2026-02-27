//
//  TabStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/2/26.
//

import Foundation
import Combine

class TabStore: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published var activeTabId: UUID

    private let storageURL: URL
    private var tabsURL: URL { storageURL.appendingPathComponent("tabs.json") }
    private var activeTabKey = "activeTabId"

    init() {
        TLNTLogger.debug("TabStore.init() called", category: TLNTLogger.storage)

        // ~/Documents/TLNT/
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsURL.appendingPathComponent("TLNT")

        // Temporary assignment, will be set after load
        activeTabId = UUID()

        ensureDirectoryExists()
        load()

        // Set active tab from UserDefaults or default to home
        if let savedActiveId = UserDefaults.standard.string(forKey: activeTabKey),
           let uuid = UUID(uuidString: savedActiveId),
           tabs.contains(where: { $0.id == uuid }) {
            activeTabId = uuid
        } else if let homeTab = tabs.first(where: { $0.isHome }) {
            activeTabId = homeTab.id
        }

        TLNTLogger.success("TabStore initialized with \(tabs.count) tabs", category: TLNTLogger.storage)
    }

    // MARK: - Public Methods

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabId }
    }

    func setActiveTab(_ tab: Tab) {
        TLNTLogger.info("Switching to tab: \(tab.name)", category: TLNTLogger.storage)
        activeTabId = tab.id
        UserDefaults.standard.set(tab.id.uuidString, forKey: activeTabKey)
    }

    func cycleToNextTab() -> Tab? {
        guard tabs.count > 1 else { return activeTab }

        if let currentIndex = tabs.firstIndex(where: { $0.id == activeTabId }) {
            let nextIndex = (currentIndex + 1) % tabs.count
            let nextTab = tabs[nextIndex]
            setActiveTab(nextTab)
            return nextTab
        }
        return activeTab
    }

    func add(name: String) -> Tab {
        TLNTLogger.debug("add(name:) called with name: \(name)", category: TLNTLogger.storage)

        let tab = Tab(name: name)
        tabs.append(tab)
        save()

        TLNTLogger.success("Tab added: \(name)", category: TLNTLogger.storage)
        return tab
    }

    func rename(_ tab: Tab, to newName: String) {
        guard !tab.isHome else {
            TLNTLogger.warning("Cannot rename home tab", category: TLNTLogger.storage)
            return
        }

        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index].name = newName
            save()
            TLNTLogger.success("Tab renamed to: \(newName)", category: TLNTLogger.storage)
        }
    }

    func delete(_ tab: Tab) {
        guard !tab.isHome else {
            TLNTLogger.warning("Cannot delete home tab", category: TLNTLogger.storage)
            return
        }

        TLNTLogger.debug("delete(tab:) called for tab: \(tab.name)", category: TLNTLogger.storage)

        tabs.removeAll { $0.id == tab.id }

        // If deleted tab was active, switch to home
        if activeTabId == tab.id, let homeTab = tabs.first(where: { $0.isHome }) {
            setActiveTab(homeTab)
        }

        save()
        TLNTLogger.success("Tab deleted: \(tab.name)", category: TLNTLogger.storage)
    }

    // MARK: - Private Methods

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageURL.path) {
            do {
                try fm.createDirectory(at: storageURL, withIntermediateDirectories: true)
            } catch {
                TLNTLogger.error("Failed to create directory: \(error)", category: TLNTLogger.storage)
            }
        }
    }

    private func load() {
        TLNTLogger.debug("TabStore.load() called", category: TLNTLogger.storage)

        guard FileManager.default.fileExists(atPath: tabsURL.path) else {
            TLNTLogger.info("tabs.json does not exist, creating default home tab", category: TLNTLogger.storage)
            tabs = [Tab.home]
            save()
            return
        }

        do {
            let data = try Data(contentsOf: tabsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            tabs = try decoder.decode([Tab].self, from: data)

            // Ensure home tab exists
            if !tabs.contains(where: { $0.isHome }) {
                tabs.insert(Tab.home, at: 0)
                save()
            }

            TLNTLogger.success("Loaded \(tabs.count) tabs from disk", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to load tabs: \(error)", category: TLNTLogger.storage)
            tabs = [Tab.home]
            save()
        }
    }

    private func save() {
        TLNTLogger.debug("TabStore.save() called", category: TLNTLogger.storage)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(tabs)
            try data.write(to: tabsURL, options: .atomic)
            TLNTLogger.success("Saved \(tabs.count) tabs to disk", category: TLNTLogger.storage)
        } catch {
            TLNTLogger.error("Failed to save tabs: \(error)", category: TLNTLogger.storage)
        }
    }
}
