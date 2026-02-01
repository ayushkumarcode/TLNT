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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.screencapture", "location"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress errors

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                let url = URL(fileURLWithPath: path)
                // Expand ~ if needed
                let expanded = url.path.hasPrefix("~")
                    ? URL(fileURLWithPath: NSString(string: url.path).expandingTildeInPath)
                    : url
                return expanded
            }
        } catch {
            print("Failed to read screenshot location: \(error)")
        }

        // Default to Desktop
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// Returns screenshots sorted by modification date (newest first)
    static func getScreenshots(in folder: URL) -> [URL] {
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        ) else {
            return []
        }

        // Match macOS screenshot/recording naming patterns
        // "Screenshot 2024-01-31 at 10.23.45.png"
        // "Screen Recording 2024-01-31 at 10.23.45.mov"
        let screenshotPattern = /^Screenshot \d{4}-\d{2}-\d{2} at \d+\.\d+\.\d+.*\.png$/
        let recordingPattern = /^Screen Recording \d{4}-\d{2}-\d{2} at \d+\.\d+\.\d+.*\.mov$/

        let filtered = files.filter { url in
            let name = url.lastPathComponent
            return name.wholeMatch(of: screenshotPattern) != nil ||
                   name.wholeMatch(of: recordingPattern) != nil
        }

        // Sort by modification date, newest first
        return filtered.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return date1 > date2
        }
    }
}
