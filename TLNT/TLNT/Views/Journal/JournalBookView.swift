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
    @State private var coverRotation: Double = 0 // 0 = closed, -180 = fully open
    @State private var isBookOpen = false
    @State private var pageFlipAngle: Double = 0
    @State private var isFlippingForward = false
    @State private var isFlippingBackward = false
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var searchResults: [JournalPage] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Paper background (visible when book is open)
                Color(red: 0.99, green: 0.97, blue: 0.91)
                    .opacity(isBookOpen ? 1 : 0)

                if isBookOpen {
                    // Open book content
                    VStack(spacing: 0) {
                        topBar

                        HStack(spacing: 0) {
                            leftPage(width: geometry.size.width * 0.5 - 20)
                            spineCenter
                            rightPage(width: geometry.size.width * 0.5 - 20)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                    .transition(.opacity)
                }

                // Cover (animates open)
                if !isBookOpen {
                    coverAnimation(geometry: geometry)
                }
            }
        }
        .onAppear {
            pages = journalStore.loadPages(for: journal.id)
            if pages.isEmpty {
                let page = journalStore.addPage(to: journal.id)
                pages = [page]
            }

            // Animate the cover opening
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.1)) {
                coverRotation = -180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBookOpen = true
                }
            }
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            Button(action: closeBook) {
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

            // Search button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching.toggle()
                    if !isSearching {
                        searchQuery = ""
                        searchResults = []
                    }
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)

            // Page indicator
            Text("Page \(currentPageIndex + 1) of \(pages.count)")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.96, green: 0.93, blue: 0.87))

        // Search overlay
        if isSearching {
            searchOverlay
        }
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
            if currentPageIndex > 0 && !isFlippingForward && !isFlippingBackward {
                flipBackward()
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
        .rotation3DEffect(
            .degrees(pageFlipAngle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.4
        )
        // Moving shadow during page flip
        .shadow(
            color: .black.opacity(abs(pageFlipAngle) > 0 ? 0.2 * sin(abs(pageFlipAngle) / 180 * .pi) : 0),
            radius: 10,
            x: pageFlipAngle < 0 ? -5 : 5,
            y: 0
        )
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

                // Subtle paper fiber noise
                let step: CGFloat = 4
                for x in stride(from: 0, to: canvasSize.width, by: step) {
                    for yi in stride(from: 0, to: canvasSize.height, by: step) {
                        let noise = sin(x * 5.123 + yi * 11.456) * 43758.5453
                        let frac = noise - floor(noise)
                        if frac > 0.92 {
                            let rect = CGRect(x: x, y: yi, width: step * 0.5, height: step * 0.3)
                            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.85, green: 0.82, blue: 0.75).opacity(0.15)))
                        }
                    }
                }
            }

            // Paper aging — darker edges
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.3), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)

                Spacer()

                LinearGradient(
                    colors: [Color.clear, Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
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
        guard !isFlippingForward && !isFlippingBackward else { return }
        guard currentPageIndex < pages.count - 1 else { return }

        isFlippingForward = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            pageFlipAngle = -180
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentPageIndex = min(currentPageIndex + 1, pages.count - 1)
            pageFlipAngle = 0
            isFlippingForward = false
        }
    }

    private func flipBackward() {
        guard !isFlippingForward && !isFlippingBackward else { return }
        guard currentPageIndex > 0 else { return }

        isFlippingBackward = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            pageFlipAngle = 180
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentPageIndex = max(currentPageIndex - 1, 0)
            pageFlipAngle = 0
            isFlippingBackward = false
        }
    }

    private func addAndFlipForward() {
        let newPage = journalStore.addPage(to: journal.id)
        pages = journalStore.loadPages(for: journal.id)

        isFlippingForward = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            pageFlipAngle = -180
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentPageIndex = pages.count - 1
            pageFlipAngle = 0
            isFlippingForward = false
        }
    }

    // MARK: - Cover Animation

    private func coverAnimation(geometry: GeometryProxy) -> some View {
        ZStack {
            // First page preview behind the cover
            paperBackground
                .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.85)
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)

            // The cover that rotates open
            BookCoverView(journal: journal, size: CGSize(width: geometry.size.width * 0.45, height: geometry.size.height * 0.85))
                .rotation3DEffect(
                    .degrees(coverRotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.4
                )
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
        }
    }

    // MARK: - Search

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                    .font(.system(size: 12))

                TextField("Search pages...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .serif))
                    .onChange(of: searchQuery) { _, query in
                        searchResults = journalStore.searchPages(in: journal.id, query: query)
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching = false
                        searchQuery = ""
                        searchResults = []
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.94, green: 0.91, blue: 0.85))

            // Search results
            if !searchQuery.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if searchResults.isEmpty {
                            Text("No matches found")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(searchResults) { page in
                                Button(action: {
                                    // Navigate to the matching page
                                    if let index = pages.firstIndex(where: { $0.id == page.id }) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            currentPageIndex = index
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isSearching = false
                                            searchQuery = ""
                                            searchResults = []
                                        }
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Page \(page.pageNumber)")
                                            .font(.system(size: 11, weight: .semibold, design: .serif))
                                            .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.12))

                                        Text(page.content.prefix(100) + (page.content.count > 100 ? "..." : ""))
                                            .font(.system(size: 11, design: .serif))
                                            .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(red: 0.97, green: 0.95, blue: 0.90))
            }
        }
    }

    private func closeBook() {
        // First close the cover
        withAnimation(.easeInOut(duration: 0.2)) {
            isBookOpen = false
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            coverRotation = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onClose()
        }
    }
}
