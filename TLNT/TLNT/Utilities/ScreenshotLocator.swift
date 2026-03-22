//
//  ScreenshotLocator.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation

enum ScreenshotLocator {

    /// Reads screenshot location from macOS preferences
    static func getScreenshotFolder() -> URL {
        TLNTLogger.debug("getScreenshotFolder() called", category: TLNTLogger.screenshot)

        // Read com.apple.screencapture preferences without spawning a process (sandbox-safe)
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !path.isEmpty {
            TLNTLogger.debug("Raw path from screencapture prefs: '\(path)'", category: TLNTLogger.screenshot)
            let expanded = NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            TLNTLogger.success("Screenshot folder: \(url.path)", category: TLNTLogger.screenshot)
            return url
        }

        // Default to Desktop
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        TLNTLogger.info("Using default Desktop folder: \(desktop.path)", category: TLNTLogger.screenshot)
        return desktop
    }

    /// Returns screenshots sorted by modification date (newest first)
    static func getScreenshots(in folder: URL) -> [URL] {
        TLNTLogger.debug("getScreenshots(in: \(folder.path)) called", category: TLNTLogger.screenshot)

        let fm = FileManager.default

        // Check if folder exists
        var isDirectory: ObjCBool = false
        let exists = fm.fileExists(atPath: folder.path, isDirectory: &isDirectory)
        TLNTLogger.debug("Folder exists: \(exists), isDirectory: \(isDirectory.boolValue)", category: TLNTLogger.screenshot)

        if !exists || !isDirectory.boolValue {
            TLNTLogger.error("Folder does not exist or is not a directory: \(folder.path)", category: TLNTLogger.screenshot)
            return []
        }

        guard let files = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        ) else {
            TLNTLogger.error("Failed to list contents of folder: \(folder.path)", category: TLNTLogger.screenshot)
            return []
        }

        TLNTLogger.debug("Found \(files.count) total files in folder", category: TLNTLogger.screenshot)

        // Log first few files for debugging
        for (index, file) in files.prefix(5).enumerated() {
            TLNTLogger.debug("  File[\(index)]: \(file.lastPathComponent)", category: TLNTLogger.screenshot)
        }

        // Match macOS screenshot/recording naming patterns
        // "Screenshot 2024-01-31 at 10.23.45.png"
        // "Screen Recording 2024-01-31 at 10.23.45.mov"
        let filtered = files.filter { url in
            let name = url.lastPathComponent

            // Check for screenshot pattern
            let isScreenshot = name.hasPrefix("Screenshot ") && name.hasSuffix(".png")
            let isRecording = name.hasPrefix("Screen Recording ") && name.hasSuffix(".mov")

            if isScreenshot || isRecording {
                TLNTLogger.debug("  Matched: \(name) (screenshot: \(isScreenshot), recording: \(isRecording))", category: TLNTLogger.screenshot)
            }

            return isScreenshot || isRecording
        }

        TLNTLogger.debug("Found \(filtered.count) screenshots/recordings after filtering", category: TLNTLogger.screenshot)

        // Sort by modification date, newest first
        let sorted = filtered.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return date1 > date2
        }

        TLNTLogger.debug("Sorted \(sorted.count) files by date (newest first)", category: TLNTLogger.screenshot)

        // Log the sorted results
        for (index, file) in sorted.prefix(3).enumerated() {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            TLNTLogger.debug("  Sorted[\(index)]: \(file.lastPathComponent) - \(date?.description ?? "no date")", category: TLNTLogger.screenshot)
        }

        return sorted
    }
}
