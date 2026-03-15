//
//  AppModeStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import Foundation

class AppModeStore: ObservableObject {
    @Published var activeMode: AppMode {
        didSet {
            UserDefaults.standard.set(activeMode.rawValue, forKey: "tlnt_activeMode")
            TLNTLogger.info("Mode switched to: \(activeMode.rawValue)", category: TLNTLogger.ui)
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "tlnt_activeMode"),
           let mode = AppMode(rawValue: saved) {
            self.activeMode = mode
        } else {
            self.activeMode = .quickNotes
        }
        TLNTLogger.debug("AppModeStore initialized with mode: \(activeMode.rawValue)", category: TLNTLogger.storage)
    }
}
