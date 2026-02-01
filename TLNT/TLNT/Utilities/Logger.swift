//
//  Logger.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Foundation
import os.log

/// Central logging utility for TLNT
enum TLNTLogger {
    private static let subsystem = "com.tlnt.app"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let screenshot = Logger(subsystem: subsystem, category: "Screenshot")
    static let text = Logger(subsystem: subsystem, category: "TextCapture")
    static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let spotlight = Logger(subsystem: subsystem, category: "Spotlight")

    /// Quick debug print that also logs
    static func debug(_ message: String, category: Logger = app) {
        category.debug("🔍 \(message)")
        print("[TLNT DEBUG] \(message)")
    }

    static func info(_ message: String, category: Logger = app) {
        category.info("ℹ️ \(message)")
        print("[TLNT INFO] \(message)")
    }

    static func warning(_ message: String, category: Logger = app) {
        category.warning("⚠️ \(message)")
        print("[TLNT WARNING] \(message)")
    }

    static func error(_ message: String, category: Logger = app) {
        category.error("❌ \(message)")
        print("[TLNT ERROR] \(message)")
    }

    static func success(_ message: String, category: Logger = app) {
        category.info("✅ \(message)")
        print("[TLNT SUCCESS] \(message)")
    }
}
