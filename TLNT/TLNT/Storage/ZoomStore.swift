//
//  ZoomStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import Foundation
import Combine

class ZoomStore: ObservableObject {
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 2.0
    static let step: CGFloat = 0.1

    @Published var level: CGFloat = 1.0

    init() {
        let saved = UserDefaults.standard.double(forKey: "tlnt_zoomLevel")
        if saved > 0 {
            self.level = max(Self.minZoom, min(Self.maxZoom, CGFloat(saved)))
        }
    }

    func zoomIn() {
        let newLevel = min(level + Self.step, Self.maxZoom)
        setLevel(newLevel)
    }

    func zoomOut() {
        let newLevel = max(level - Self.step, Self.minZoom)
        setLevel(newLevel)
    }

    func resetZoom() {
        setLevel(1.0)
    }

    private func setLevel(_ newLevel: CGFloat) {
        let clamped = max(Self.minZoom, min(Self.maxZoom, newLevel))
        level = clamped
        UserDefaults.standard.set(Double(clamped), forKey: "tlnt_zoomLevel")
    }
}
