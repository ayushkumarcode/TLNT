//
//  MainContentView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import SwiftUI

struct MainContentView: View {
    @ObservedObject var noteStore: NoteStore
    @State private var searchText = ""

    private var filteredNotes: [Note] {
        let sorted = noteStore.notes.sorted { $0.createdAt > $1.createdAt }

        if searchText.isEmpty {
            return sorted
        }

        return sorted.filter { note in
            switch note.type {
            case .text:
                return note.content.localizedCaseInsensitiveContains(searchText)
            case .screenshot, .recording:
                return note.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if noteStore.notes.isEmpty {
                emptyState
            } else if filteredNotes.isEmpty {
                noResultsState
            } else {
                notesGrid
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No notes yet")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HotkeyHint(keys: "⌘⌥S", description: "Send screenshot")
                HotkeyHint(keys: "⌘⌥K", description: "Capture text")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No results for \"\(searchText)\"")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Notes Grid

    private var notesGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200, maximum: 350), spacing: 16)],
                spacing: 16
            ) {
                ForEach(filteredNotes) { note in
                    NoteItemView(note: note, onDelete: {
                        withAnimation {
                            noteStore.delete(note)
                        }
                    })
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Hotkey Hint

struct HotkeyHint: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}
