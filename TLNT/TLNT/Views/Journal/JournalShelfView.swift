//
//  JournalShelfView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI

struct JournalShelfView: View {
    @ObservedObject var journalStore: JournalStore
    let onOpenJournal: (Journal) -> Void

    @State private var isCreatingJournal = false
    @State private var newJournalTitle = ""
    @State private var newJournalCover: CoverStyle = .black

    private let bookSize = CGSize(width: 120, height: 165)
    private let booksPerShelf = 4

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    let shelves = shelfRows()
                    ForEach(Array(shelves.enumerated()), id: \.offset) { index, shelfJournals in
                        shelfRow(journals: shelfJournals, shelfIndex: index, totalWidth: geometry.size.width)
                    }

                    // Extra empty shelf if last shelf is full
                    if shelves.isEmpty || (shelves.last?.count ?? 0) >= booksPerShelf {
                        emptyShelfRow(totalWidth: geometry.size.width)
                    }
                }
            }
            .background(shelfBackground)
            .drawingGroup() // Metal-rendered for 60fps with Canvas-heavy shelf
        }
    }

    // MARK: - Shelf Layout

    private func shelfRows() -> [[Journal?]] {
        var rows: [[Journal?]] = []
        var currentRow: [Journal?] = []

        for journal in journalStore.journals {
            currentRow.append(journal)
            if currentRow.count >= booksPerShelf {
                rows.append(currentRow)
                currentRow = []
            }
        }

        // Add the "new journal" slot
        currentRow.append(nil) // nil = "add new" placeholder
        rows.append(currentRow)

        return rows
    }

    private func shelfRow(journals: [Journal?], shelfIndex: Int, totalWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Books sitting on this shelf
            HStack(alignment: .bottom, spacing: 20) {
                ForEach(Array(journals.enumerated()), id: \.offset) { index, journal in
                    if let journal = journal {
                        bookOnShelf(journal: journal)
                    } else {
                        addBookButton
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 0)

            // Shelf plank
            shelfPlank(width: totalWidth)
        }
    }

    private func emptyShelfRow(totalWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: bookSize.height + 20)
            shelfPlank(width: totalWidth)
        }
    }

    // MARK: - Book on Shelf

    private func bookOnShelf(journal: Journal) -> some View {
        BookCoverView(journal: journal, size: bookSize)
            .rotation3DEffect(.degrees(-8), axis: (x: 0.1, y: 1, z: 0), perspective: 0.5)
            .onTapGesture {
                onOpenJournal(journal)
            }
            .contextMenu {
                Button(role: .destructive) {
                    journalStore.deleteJournal(journal)
                } label: {
                    Label("Delete Journal", systemImage: "trash")
                }
            }
    }

    // MARK: - Add Book Button

    private var addBookButton: some View {
        Button(action: { isCreatingJournal = true }) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .frame(width: bookSize.width, height: bookSize.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )

                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.secondary.opacity(0.6))

                    Text("New Journal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
        .rotation3DEffect(.degrees(-8), axis: (x: 0.1, y: 1, z: 0), perspective: 0.5)
        .popover(isPresented: $isCreatingJournal) {
            newJournalPopover
        }
    }

    // MARK: - Shelf Plank

    private func shelfPlank(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Plank top surface
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.20, blue: 0.14),
                            Color(red: 0.36, green: 0.25, blue: 0.17),
                            Color(red: 0.30, green: 0.20, blue: 0.14),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 14)

            // Wood grain lines
            Canvas { context, canvasSize in
                for i in stride(from: CGFloat(0), to: canvasSize.width, by: 40) {
                    let noise = sin(i * 0.1) * 3
                    var path = Path()
                    path.move(to: CGPoint(x: i, y: 2 + noise))
                    path.addLine(to: CGPoint(x: i + 35, y: 4 + noise))
                    context.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)
                }
            }
            .frame(height: 14)
            .allowsHitTesting(false)

            // Front face of the shelf (3D edge)
            VStack(spacing: 0) {
                // Highlight at top edge
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.16, blue: 0.10),
                                Color(red: 0.20, green: 0.13, blue: 0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 10)

                // Shadow below
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 2)
            }
            .offset(y: 14)
        }
        .frame(height: 26)
    }

    // MARK: - Background

    private var shelfBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.10, blue: 0.07),
                Color(red: 0.12, green: 0.08, blue: 0.05),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            // Subtle vignette
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        )
    }

    // MARK: - New Journal Popover

    private var newJournalPopover: some View {
        VStack(spacing: 16) {
            Text("New Journal")
                .font(.headline)

            TextField("Journal title", text: $newJournalTitle)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            // Cover style picker
            HStack(spacing: 8) {
                ForEach(CoverStyle.allCases, id: \.self) { style in
                    coverStyleButton(style)
                }
            }

            HStack {
                Button("Cancel") {
                    newJournalTitle = ""
                    isCreatingJournal = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createJournal()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newJournalTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    private func coverStyleButton(_ style: CoverStyle) -> some View {
        let colors: (Color, Color) = {
            switch style {
            case .black: return (Color(red: 0.10, green: 0.10, blue: 0.10), Color(red: 0.18, green: 0.18, blue: 0.18))
            case .brown: return (Color(red: 0.30, green: 0.18, blue: 0.10), Color(red: 0.42, green: 0.28, blue: 0.18))
            case .burgundy: return (Color(red: 0.35, green: 0.08, blue: 0.12), Color(red: 0.48, green: 0.15, blue: 0.18))
            case .navy: return (Color(red: 0.08, green: 0.12, blue: 0.25), Color(red: 0.15, green: 0.20, blue: 0.38))
            case .forest: return (Color(red: 0.08, green: 0.20, blue: 0.10), Color(red: 0.15, green: 0.30, blue: 0.18))
            }
        }()

        return Button(action: { newJournalCover = style }) {
            Circle()
                .fill(LinearGradient(colors: [colors.1, colors.0], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(newJournalCover == style ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func createJournal() {
        let title = newJournalTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        let journal = journalStore.addJournal(title: title, coverStyle: newJournalCover)
        newJournalTitle = ""
        newJournalCover = .black
        isCreatingJournal = false

        // Auto-open the new journal
        onOpenJournal(journal)
    }
}
