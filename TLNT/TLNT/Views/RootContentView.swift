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

    @State private var openedJournal: Journal?

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle integrated into the top bar (hidden when journal is open)
            if openedJournal == nil {
                HStack(spacing: 0) {
                    modeToggle
                        .padding(.leading, 12)
                        .padding(.vertical, 6)

                    Spacer()
                }
                .background(Color(NSColor.windowBackgroundColor))
            }

            // Content based on active mode
            Group {
                switch appModeStore.activeMode {
                case .quickNotes:
                    MainContentView(noteStore: noteStore, tabStore: tabStore)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                case .journal:
                    if let journal = openedJournal {
                        JournalBookView(
                            journal: journal,
                            journalStore: journalStore,
                            onClose: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                    openedJournal = nil
                                }
                            }
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        JournalShelfView(journalStore: journalStore) { journal in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                                openedJournal = journal
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                    }
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

}
