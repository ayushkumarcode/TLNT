//
//  ZoomStore.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import Foundation

class ZoomStore: ObservableObject {
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 2.0
    static let step: CGFloat = 0.1

    @Published var level: CGFloat {
        didSet {
            level = max(Self.minZoom, min(Self.maxZoom, level))
            UserDefaults.standard.set(Double(level), forKey: "tlnt_zoomLevel")
        }
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: "tlnt_zoomLevel")
        self.level = saved > 0 ? CGFloat(saved) : 1.0
    }

    func zoomIn() {
        withMutations {
            level = min(level + Self.step, Self.maxZoom)
        }
    }

    func zoomOut() {
        withMutations {
            level = max(level - Self.step, Self.minZoom)
        }
    }

    func resetZoom() {
        level = 1.0
    }

    private func withMutations(_ body: () -> Void) {
        objectWillChange.send()
        body()
    }
}
