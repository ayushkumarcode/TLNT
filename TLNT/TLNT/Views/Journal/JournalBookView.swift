//
//  JournalBookView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI

struct JournalBookView: View {
    let journal: Journal
    @ObservedObject var journalStore: JournalStore
    let onClose: () -> Void

    @State private var pages: [JournalPage] = []
    @State private var currentPageIndex: Int = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Paper background
                Color(red: 0.99, green: 0.97, blue: 0.91)

                VStack(spacing: 0) {
                    // Top bar with close button
                    topBar

                    // Book spread
                    HStack(spacing: 0) {
                        // Left page (previous)
                        leftPage(width: geometry.size.width * 0.5 - 20)

                        // Spine
                        spineCenter

                        // Right page (current/active)
                        rightPage(width: geometry.size.width * 0.5 - 20)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            }
        }
        .onAppear {
            pages = journalStore.loadPages(for: journal.id)
            if pages.isEmpty {
                let page = journalStore.addPage(to: journal.id)
                pages = [page]
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Shelf")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(journal.title)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.12))

            Spacer()

            // Page indicator
            Text("Page \(currentPageIndex + 1) of \(pages.count)")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.96, green: 0.93, blue: 0.87))
    }

    // MARK: - Pages

    private func leftPage(width: CGFloat) -> some View {
        ZStack {
            // Paper texture
            paperBackground

            if currentPageIndex > 0 {
                let prevPage = pages[currentPageIndex - 1]
                VStack(alignment: .leading) {
                    pageHeader(pageNumber: prevPage.pageNumber, date: prevPage.createdAt)

                    ScrollView {
                        Text(prevPage.content.isEmpty ? "Empty page" : prevPage.content)
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(prevPage.content.isEmpty ? Color.gray.opacity(0.5) : Color(red: 0.20, green: 0.15, blue: 0.10))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding(16)
            } else {
                // Cover page / title page
                VStack(spacing: 20) {
                    Spacer()
                    Text(journal.title)
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.12))
                    Text(journal.createdAt.formatted(date: .long, time: .omitted))
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                    Spacer()
                }
            }

            // Inner spine shadow
            HStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.clear],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .frame(width: 15)
            }
        }
        .frame(width: width)
        .clipShape(Rectangle())
        .onTapGesture {
            if currentPageIndex > 0 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    currentPageIndex -= 1
                }
            }
        }
    }

    private func rightPage(width: CGFloat) -> some View {
        ZStack {
            paperBackground

            if currentPageIndex < pages.count {
                VStack(alignment: .leading) {
                    pageHeader(pageNumber: pages[currentPageIndex].pageNumber, date: pages[currentPageIndex].createdAt)

                    // Editable content area
                    RichTextEditorView(
                        text: Binding(
                            get: { pages[currentPageIndex].content },
                            set: { newValue in
                                guard currentPageIndex < pages.count else { return }
                                pages[currentPageIndex].content = newValue
                                journalStore.updatePage(pages[currentPageIndex])
                            }
                        )
                    )

                    Spacer()

                    // Navigation hint
                    HStack {
                        Spacer()
                        if currentPageIndex < pages.count - 1 {
                            Button(action: { flipForward() }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { addAndFlipForward() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("New Page")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }

            // Inner spine shadow
            HStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 15)
                Spacer()
            }

            // Outer page curl shadow
            HStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.04)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 10)
            }
        }
        .frame(width: width)
        .clipShape(Rectangle())
    }

    // MARK: - Helpers

    private var paperBackground: some View {
        ZStack {
            // Cream paper base
            Color(red: 0.99, green: 0.96, blue: 0.88)

            // Faint ruled lines
            Canvas { context, canvasSize in
                let lineSpacing: CGFloat = 24
                var y: CGFloat = 60 // Start below header
                while y < canvasSize.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 16, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - 16, y: y))
                    context.stroke(path, with: .color(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.4)), lineWidth: 0.5)
                    y += lineSpacing
                }
            }
        }
    }

    private func pageHeader(pageNumber: Int, date: Date) -> some View {
        HStack {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10, design: .serif))
                .foregroundColor(Color(red: 0.60, green: 0.52, blue: 0.42))

            Spacer()

            Text("\(pageNumber)")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(Color(red: 0.60, green: 0.52, blue: 0.42))
        }
        .padding(.bottom, 8)
    }

    private var spineCenter: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.75, green: 0.70, blue: 0.62),
                        Color(red: 0.65, green: 0.58, blue: 0.50),
                        Color(red: 0.75, green: 0.70, blue: 0.62),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 4)
            .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: 0)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 0)
    }

    private func flipForward() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentPageIndex = min(currentPageIndex + 1, pages.count - 1)
        }
    }

    private func addAndFlipForward() {
        let newPage = journalStore.addPage(to: journal.id)
        pages = journalStore.loadPages(for: journal.id)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentPageIndex = pages.count - 1
        }
    }
}
