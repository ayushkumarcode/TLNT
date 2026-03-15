//
//  JournalShelfView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI

struct JournalShelfView: View {
    @ObservedObject var journalStore: JournalStore
    var zoomLevel: CGFloat = 1.0
    let onOpenJournal: (Journal) -> Void

    @State private var isCreatingJournal = false
    @State private var newJournalTitle = ""
    @State private var newJournalCover: CoverStyle = .black
    @State private var hoveredJournalId: UUID?
    @State private var tappedJournalId: UUID?

    private var bookSize: CGSize {
        CGSize(width: 120 * zoomLevel, height: 165 * zoomLevel)
    }
    private var booksPerShelf: Int {
        max(2, Int(4.0 / zoomLevel))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 30)

                    let shelves = shelfRows()
                    ForEach(Array(shelves.enumerated()), id: \.offset) { index, shelfJournals in
                        shelfRow(journals: shelfJournals, shelfIndex: index, totalWidth: geometry.size.width)
                    }

                    if shelves.isEmpty || (shelves.last?.count ?? 0) >= booksPerShelf {
                        emptyShelfRow(totalWidth: geometry.size.width)
                    }

                    Spacer().frame(height: 50)
                }
            }
            .background(shelfBackground(size: geometry.size))
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

        currentRow.append(nil) // "add new" slot
        rows.append(currentRow)

        return rows
    }

    private func shelfRow(journals: [Journal?], shelfIndex: Int, totalWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 24) {
                ForEach(Array(journals.enumerated()), id: \.offset) { index, journal in
                    if let journal = journal {
                        bookOnShelf(journal: journal)
                    } else {
                        addBookButton
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 0)

            shelfPlank(width: totalWidth)
        }
    }

    private func emptyShelfRow(totalWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: bookSize.height + 30)
            shelfPlank(width: totalWidth)
        }
    }

    // MARK: - Book on Shelf (with hover + tap animation)

    private func bookOnShelf(journal: Journal) -> some View {
        let isHovered = hoveredJournalId == journal.id
        let isTapped = tappedJournalId == journal.id

        return BookCoverView(journal: journal, size: bookSize)
            .rotation3DEffect(
                .degrees(isHovered ? -15 : -8),
                axis: (x: isHovered ? 0.3 : 0.1, y: 1, z: 0),
                perspective: 0.5
            )
            .scaleEffect(isTapped ? 1.08 : (isHovered ? 1.03 : 1.0))
            .offset(y: isTapped ? -12 : (isHovered ? -4 : 0))
            .shadow(
                color: .black.opacity(isTapped ? 0.5 : (isHovered ? 0.4 : 0.3)),
                radius: isTapped ? 15 : (isHovered ? 10 : 6),
                x: isTapped ? 0 : 3,
                y: isTapped ? 10 : (isHovered ? 6 : 3)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isTapped)
            .onHover { hovering in
                hoveredJournalId = hovering ? journal.id : nil
            }
            .onTapGesture {
                // Tap animation: pull forward, then open
                tappedJournalId = journal.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    tappedJournalId = nil
                    onOpenJournal(journal)
                }
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
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.25, green: 0.20, blue: 0.15).opacity(0.8))
                    .frame(width: bookSize.width, height: bookSize.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.65, green: 0.55, blue: 0.40).opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )

                VStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color(red: 0.75, green: 0.65, blue: 0.48))
                    Text("New Journal")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundColor(Color(red: 0.75, green: 0.65, blue: 0.48))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
        }
        .buttonStyle(.plain)
        .rotation3DEffect(.degrees(-8), axis: (x: 0.1, y: 1, z: 0), perspective: 0.5)
        .popover(isPresented: $isCreatingJournal) {
            newJournalPopover
        }
    }

    // MARK: - Shelf Plank (enhanced 3D)

    private func shelfPlank(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Plank top surface with better wood color
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.30, blue: 0.20),
                            Color(red: 0.50, green: 0.36, blue: 0.24),
                            Color(red: 0.46, green: 0.33, blue: 0.22),
                            Color(red: 0.42, green: 0.30, blue: 0.20),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 16)
                .shadow(color: .black.opacity(0.1), radius: 2, y: -1)

            // Wood grain
            Canvas { context, canvasSize in
                for i in stride(from: CGFloat(0), to: canvasSize.width, by: 30) {
                    let noise = sin(i * 0.08) * 4
                    let noise2 = cos(i * 0.15) * 2
                    var path = Path()
                    path.move(to: CGPoint(x: i, y: 3 + noise))
                    path.addQuadCurve(
                        to: CGPoint(x: i + 28, y: 5 + noise2),
                        control: CGPoint(x: i + 14, y: 2 + noise * 0.5)
                    )
                    context.stroke(path, with: .color(Color.white.opacity(0.07)), lineWidth: 0.5)

                    // Second grain line slightly offset
                    var path2 = Path()
                    path2.move(to: CGPoint(x: i + 5, y: 9 + noise * 0.3))
                    path2.addLine(to: CGPoint(x: i + 25, y: 11 + noise2 * 0.5))
                    context.stroke(path2, with: .color(Color.black.opacity(0.04)), lineWidth: 0.3)
                }
            }
            .frame(height: 16)
            .allowsHitTesting(false)

            // Front face with highlight and shadow
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.25, blue: 0.16),
                                Color(red: 0.30, green: 0.20, blue: 0.12),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 12)

                // Bottom shadow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.2), Color.black.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 4)
            }
            .offset(y: 16)
        }
        .frame(height: 33)
    }

    // MARK: - Background

    private func shelfBackground(size: CGSize) -> some View {
        ZStack {
            // Wall behind the shelf — warm dark wood paneling
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.16, blue: 0.12),
                    Color(red: 0.18, green: 0.13, blue: 0.09),
                    Color(red: 0.14, green: 0.10, blue: 0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Warm ambient light from above
            RadialGradient(
                colors: [
                    Color(red: 0.35, green: 0.25, blue: 0.18).opacity(0.25),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.1),
                startRadius: 0,
                endRadius: size.height * 0.7
            )

            // Subtle vignette
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.2)],
                center: .center,
                startRadius: size.width * 0.3,
                endRadius: size.width * 0.8
            )
        }
    }

    // MARK: - New Journal Popover

    private var newJournalPopover: some View {
        VStack(spacing: 16) {
            Text("New Journal")
                .font(.headline)

            TextField("Journal title", text: $newJournalTitle)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

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
        onOpenJournal(journal)
    }
}
