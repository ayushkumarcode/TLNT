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
    @State private var modeAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle (hidden when a journal is open)
            if openedJournal == nil {
                HStack(spacing: 0) {
                    modeToggle
                        .padding(.leading, 12)
                        .padding(.vertical, 6)
                    Spacer()
                }
                .background(Color(NSColor.windowBackgroundColor))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Content
            ZStack {
                switch appModeStore.activeMode {
                case .quickNotes:
                    MainContentView(noteStore: noteStore, tabStore: tabStore)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: -30)).animation(.spring(response: 0.4, dampingFraction: 0.85)),
                            removal: .opacity.combined(with: .offset(x: -30)).animation(.easeIn(duration: 0.2))
                        ))
                case .journal:
                    if let journal = openedJournal {
                        JournalBookView(
                            journal: journal,
                            journalStore: journalStore,
                            onClose: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    openedJournal = nil
                                }
                            }
                        )
                        .transition(.opacity)
                    } else {
                        JournalShelfView(journalStore: journalStore) { journal in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                openedJournal = journal
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 30)).animation(.spring(response: 0.4, dampingFraction: 0.85)),
                            removal: .opacity.combined(with: .offset(x: 30)).animation(.easeIn(duration: 0.2))
                        ))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: appModeStore.activeMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: openedJournal?.id)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Mode Toggle (pill-style segmented control)

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton(mode: .quickNotes, icon: "square.grid.2x2", label: "Notes")
            modeButton(mode: .journal, icon: "book.closed.fill", label: "Journal")
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }

    private func modeButton(mode: AppMode, icon: String, label: String) -> some View {
        let isActive = appModeStore.activeMode == mode

        return Button(action: {
            guard !modeAnimating else { return }
            modeAnimating = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appModeStore.activeMode = mode
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                modeAnimating = false
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                            .shadow(color: Color.accentColor.opacity(0.1), radius: 2, y: 1)
                    }
                }
            )
            .foregroundColor(isActive ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
