//
//  RootContentView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI

struct RootContentView: View {
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var tabStore: TabStore
    @ObservedObject var appModeStore: AppModeStore
    @ObservedObject var journalStore: JournalStore

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle integrated into the top bar
            HStack(spacing: 0) {
                modeToggle
                    .padding(.leading, 12)
                    .padding(.vertical, 6)

                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor))

            // Content based on active mode
            Group {
                switch appModeStore.activeMode {
                case .quickNotes:
                    MainContentView(noteStore: noteStore, tabStore: tabStore)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case .journal:
                    journalPlaceholder
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appModeStore.activeMode)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 2) {
            modeButton(mode: .quickNotes, icon: "square.grid.2x2", label: "Notes")
            modeButton(mode: .journal, icon: "book.closed", label: "Journal")
        }
        .padding(3)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func modeButton(mode: AppMode, icon: String, label: String) -> some View {
        let isActive = appModeStore.activeMode == mode

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                appModeStore.activeMode = mode
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(isActive ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Journal Placeholder

    private var journalPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Journal Mode")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Coming soon...")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
