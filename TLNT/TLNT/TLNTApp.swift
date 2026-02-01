//
//  TLNTApp.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import SwiftUI

@main
struct TLNTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene - we're a menu bar app
        Settings {
            EmptyView()
        }
    }
}
