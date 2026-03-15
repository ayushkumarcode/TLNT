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

    // Cover open/close animation — multi-phase
    @State private var coverRotation: Double = 0
    @State private var coverShadowRadius: CGFloat = 8
    @State private var coverShadowOffset: CGFloat = 4
    @State private var isBookOpen = false
    @State private var bookScale: CGFloat = 0.6
    @State private var bookOpacity: Double = 0
    @State private var liftOffset: CGFloat = 40

    // Page flip
    @State private var pageFlipAngle: Double = 0
    @State private var isFlippingForward = false
    @State private var isFlippingBackward = false
    @State private var flipShadowOpacity: Double = 0
    @State private var leftPageCurlAmount: CGFloat = 0
    @State private var rightPageCurlAmount: CGFloat = 0

    // Search
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var searchResults: [JournalPage] = []
    @FocusState private var isSearchFieldFocused: Bool

    // Ambient page animation
    @State private var pageBreathScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep background
                Color(red: 0.12, green: 0.10, blue: 0.08)

                // Paper background with ambient shadow
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.99, green: 0.97, blue: 0.91))
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .padding(8)
                    .opacity(isBookOpen ? 1 : 0)

                if isBookOpen {
                    VStack(spacing: 0) {
                        topBar

                        // The open book spread
                        ZStack {
                            HStack(spacing: 0) {
                                leftPage(width: geometry.size.width * 0.5 - 22)
                                spineCenter(height: geometry.size.height - 60)
                                rightPage(width: geometry.size.width * 0.5 - 22)
                            }

                            // Page thickness at top and bottom
                            pageThicknessEdges(geometry: geometry)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                        .scaleEffect(pageBreathScale)
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }

                // Cover opening animation
                if !isBookOpen {
                    coverOpeningScene(geometry: geometry)
                }
            }
        }
        .onAppear {
            pages = journalStore.loadPages(for: journal.id)
            if pages.isEmpty {
                let page = journalStore.addPage(to: journal.id)
                pages = [page]
            }
            performOpenAnimation()
        }
    }

    // MARK: - Open Animation (multi-phase)

    private func performOpenAnimation() {
        // Phase 1: Fade in and float up (0-0.3s)
        withAnimation(.easeOut(duration: 0.35)) {
            bookOpacity = 1
            bookScale = 0.85
            liftOffset = 10
        }

        // Phase 2: Scale to full size (0.3-0.6s)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
            bookScale = 1.0
            liftOffset = 0
        }

        // Phase 3: Open the cover with growing shadow (0.5-1.1s)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.45)) {
            coverRotation = -180
            coverShadowRadius = 25
            coverShadowOffset = 15
        }

        // Phase 4: Reveal pages (at 0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeInOut(duration: 0.25)) {
                isBookOpen = true
            }
            // Subtle breathing animation
            startPageBreathing()
        }
    }

    private func startPageBreathing() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            pageBreathScale = 1.002
        }
    }

    // MARK: - Cover Opening Scene

    private func coverOpeningScene(geometry: GeometryProxy) -> some View {
        let coverW = geometry.size.width * 0.42
        let coverH = geometry.size.height * 0.82

        return ZStack {
            // Shadow on the "desk" beneath the book
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: coverW * 1.1, height: 30)
                .blur(radius: 12)
                .offset(y: coverH * 0.48)
                .scaleEffect(x: bookScale * 1.2)

            // First page peek behind the cover
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.99, green: 0.96, blue: 0.88))
                .frame(width: coverW - 4, height: coverH - 4)
                .shadow(color: .black.opacity(0.1), radius: 3)

            // The cover itself rotating open
            BookCoverView(journal: journal, size: CGSize(width: coverW, height: coverH))
                .rotation3DEffect(
                    .degrees(coverRotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.35
                )
                .shadow(
                    color: .black.opacity(0.5),
                    radius: coverShadowRadius,
                    x: coverShadowOffset,
                    y: coverShadowOffset
                )
        }
        .scaleEffect(bookScale)
        .offset(y: liftOffset)
        .opacity(bookOpacity)
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            Button(action: closeBook) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Shelf")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.92, green: 0.88, blue: 0.80).opacity(0.5))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(journal.title)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.12))

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSearching.toggle()
                    if isSearching {
                        isSearchFieldFocused = true
                    } else {
                        searchQuery = ""
                        searchResults = []
                        isSearchFieldFocused = false
                    }
                }
            }) {
                Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.45, green: 0.38, blue: 0.28))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)

            Text("Page \(currentPageIndex + 1) of \(pages.count)")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(Color(red: 0.55, green: 0.48, blue: 0.38))
                .padding(.leading, 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Color(red: 0.96, green: 0.93, blue: 0.87)
                .shadow(.inner(color: Color.black.opacity(0.05), radius: 2, y: -1))
        )

        if isSearching {
            searchOverlay
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Pages

    private func leftPage(width: CGFloat) -> some View {
        ZStack {
            paperBackground(isLeftPage: true)

            if currentPageIndex > 0 {
                let prevPage = pages[currentPageIndex - 1]
                VStack(alignment: .leading) {
                    pageHeader(pageNumber: prevPage.pageNumber, date: prevPage.createdAt)
                    ScrollView {
                        Text(prevPage.content.isEmpty ? "" : prevPage.content)
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(prevPage.content.isEmpty ? Color.gray.opacity(0.3) : Color(red: 0.20, green: 0.15, blue: 0.10))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                }
                .padding(20)
            } else {
                // Title page
                VStack(spacing: 16) {
                    Spacer()

                    // Decorative flourish
                    HStack(spacing: 8) {
                        Rectangle().fill(Color(red: 0.75, green: 0.65, blue: 0.50)).frame(width: 30, height: 1)
                        Circle().fill(Color(red: 0.75, green: 0.65, blue: 0.50)).frame(width: 4, height: 4)
                        Rectangle().fill(Color(red: 0.75, green: 0.65, blue: 0.50)).frame(width: 30, height: 1)
                    }
                    .opacity(0.5)

                    Text(journal.title)
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundColor(Color(red: 0.25, green: 0.18, blue: 0.10))
                        .tracking(1.5)

                    Text(journal.createdAt.formatted(date: .long, time: .omitted))
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(Color(red: 0.55, green: 0.48, blue: 0.38))
                        .italic()

                    HStack(spacing: 8) {
                        Rectangle().fill(Color(red: 0.75, green: 0.65, blue: 0.50)).frame(width: 30, height: 1)
                        Circle().fill(Color(red: 0.75, green: 0.65, blue: 0.50)).frame(width: 4, height: 4)
                        Rectangle().fill(Color(red: 0.75, green: 0.65, blue: 0.50)).frame(width: 30, height: 1)
                    }
                    .opacity(0.5)

                    Spacer()
                }
            }

            // Deep spine shadow on right edge
            HStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.04), Color.clear],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .frame(width: 25)
            }

            // Outer left page curl
            HStack {
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 0, y: size.height), control: CGPoint(x: 6, y: size.height * 0.5))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    context.fill(path, with: .color(Color.black.opacity(0.04)))
                }
                .frame(width: 8)
                Spacer()
            }
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.08), radius: 4, x: -2, y: 2)
        .onTapGesture {
            if currentPageIndex > 0 && !isFlippingForward && !isFlippingBackward {
                flipBackward()
            }
        }
    }

    private func rightPage(width: CGFloat) -> some View {
        ZStack {
            paperBackground(isLeftPage: false)

            if currentPageIndex < pages.count {
                VStack(alignment: .leading) {
                    pageHeader(pageNumber: pages[currentPageIndex].pageNumber, date: pages[currentPageIndex].createdAt)

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

                    HStack {
                        Spacer()
                        if currentPageIndex < pages.count - 1 {
                            Button(action: { flipForward() }) {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .font(.system(size: 11, design: .serif))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.95, green: 0.92, blue: 0.85))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { addAndFlipForward() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("New Page")
                                        .font(.system(size: 11, design: .serif))
                                }
                                .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.95, green: 0.92, blue: 0.85))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }

            // Deep spine shadow on left edge
            HStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.04), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 25)
                Spacer()
            }

            // Outer right page curl
            HStack {
                Spacer()
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: size.width, y: 0))
                    path.addQuadCurve(to: CGPoint(x: size.width, y: size.height), control: CGPoint(x: size.width - 6, y: size.height * 0.5))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                    context.fill(path, with: .color(Color.black.opacity(0.04)))
                }
                .frame(width: 8)
            }

            // Flip shadow overlay
            if flipShadowOpacity > 0 {
                LinearGradient(
                    colors: [Color.black.opacity(flipShadowOpacity * 0.15), Color.clear, Color.black.opacity(flipShadowOpacity * 0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)
            }
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 2, y: 2)
        .rotation3DEffect(
            .degrees(pageFlipAngle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.3
        )
        .shadow(
            color: .black.opacity(abs(pageFlipAngle) > 0 ? 0.25 * sin(abs(pageFlipAngle) / 180 * .pi) : 0),
            radius: 15,
            x: pageFlipAngle < 0 ? -8 : 8,
            y: 3
        )
    }

    // MARK: - Paper Background

    private func paperBackground(isLeftPage: Bool) -> some View {
        ZStack {
            // Slightly different cream for left vs right (left is more "read", slightly more aged)
            Color(red: isLeftPage ? 0.98 : 0.99, green: isLeftPage ? 0.95 : 0.96, blue: isLeftPage ? 0.86 : 0.88)

            // Ruled lines
            Canvas { context, canvasSize in
                let lineSpacing: CGFloat = 24
                var y: CGFloat = 56
                while y < canvasSize.height - 20 {
                    var path = Path()
                    path.move(to: CGPoint(x: 20, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - 20, y: y))
                    context.stroke(path, with: .color(Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.3)), lineWidth: 0.5)
                    y += lineSpacing
                }

                // Paper fiber texture
                let step: CGFloat = 5
                for x in stride(from: 0, to: canvasSize.width, by: step) {
                    for yi in stride(from: 0, to: canvasSize.height, by: step) {
                        let noise = sin(x * 5.123 + yi * 11.456) * 43758.5453
                        let frac = noise - floor(noise)
                        if frac > 0.93 {
                            let rect = CGRect(x: x, y: yi, width: step * 0.4, height: step * 0.2)
                            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.85, green: 0.82, blue: 0.75).opacity(0.12)))
                        }
                    }
                }
            }

            // Edge aging — all four sides
            VStack(spacing: 0) {
                LinearGradient(colors: [Color(red: 0.88, green: 0.84, blue: 0.74).opacity(0.25), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 25)
                Spacer()
                LinearGradient(colors: [Color.clear, Color(red: 0.88, green: 0.84, blue: 0.74).opacity(0.25)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 25)
            }
        }
    }

    // MARK: - Page Thickness Edges

    private func pageThicknessEdges(geometry: GeometryProxy) -> some View {
        VStack {
            // Top page edges (stack of pages visible)
            HStack(spacing: 0) {
                Spacer().frame(width: 14)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.93, blue: 0.86), Color(red: 0.92, green: 0.89, blue: 0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 3)
                    .shadow(color: .black.opacity(0.05), radius: 1, y: -1)
                Spacer().frame(width: 14)
            }
            Spacer()
            // Bottom page edges
            HStack(spacing: 0) {
                Spacer().frame(width: 14)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.92, green: 0.89, blue: 0.82), Color(red: 0.88, green: 0.85, blue: 0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 3)
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                Spacer().frame(width: 14)
            }
        }
    }

    private func pageHeader(pageNumber: Int, date: Date) -> some View {
        HStack {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10, design: .serif))
                .foregroundColor(Color(red: 0.60, green: 0.52, blue: 0.42))
                .italic()
            Spacer()
            Text("\(pageNumber)")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(Color(red: 0.60, green: 0.52, blue: 0.42))
        }
        .padding(.bottom, 10)
    }

    // MARK: - Spine

    private func spineCenter(height: CGFloat) -> some View {
        ZStack {
            // Spine groove
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.68, green: 0.62, blue: 0.52),
                            Color(red: 0.55, green: 0.48, blue: 0.38),
                            Color(red: 0.58, green: 0.52, blue: 0.42),
                            Color(red: 0.55, green: 0.48, blue: 0.38),
                            Color(red: 0.68, green: 0.62, blue: 0.52),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 6)

            // Stitching down the spine
            Canvas { context, canvasSize in
                let dashHeight: CGFloat = 4
                let gapHeight: CGFloat = 3
                var y: CGFloat = 8
                while y < canvasSize.height - 8 {
                    var path = Path()
                    path.move(to: CGPoint(x: canvasSize.width / 2, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width / 2, y: y + dashHeight))
                    context.stroke(path, with: .color(Color(red: 0.45, green: 0.38, blue: 0.28).opacity(0.3)), lineWidth: 0.5)
                    y += dashHeight + gapHeight
                }
            }
            .frame(width: 6)
        }
        .shadow(color: .black.opacity(0.15), radius: 3, x: -2, y: 0)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 0)
    }

    // MARK: - Page Flip (realistic multi-phase)

    private func flipForward() {
        guard !isFlippingForward && !isFlippingBackward else { return }
        guard currentPageIndex < pages.count - 1 else { return }

        isFlippingForward = true

        // Phase 1: Slight lift (page peels up)
        withAnimation(.easeOut(duration: 0.12)) {
            flipShadowOpacity = 0.3
        }

        // Phase 2: Full rotation with deceleration
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.5)) {
            pageFlipAngle = -180
        }

        // Phase 3: Shadow sweep
        withAnimation(.easeInOut(duration: 0.5)) {
            flipShadowOpacity = 1.0
        }

        // Content swap at midpoint
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentPageIndex = min(currentPageIndex + 1, pages.count - 1)
        }

        // Phase 4: Settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                pageFlipAngle = 0
                flipShadowOpacity = 0
            }
            isFlippingForward = false
        }
    }

    private func flipBackward() {
        guard !isFlippingForward && !isFlippingBackward else { return }
        guard currentPageIndex > 0 else { return }

        isFlippingBackward = true

        withAnimation(.easeOut(duration: 0.12)) {
            flipShadowOpacity = 0.3
        }

        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.5)) {
            pageFlipAngle = 180
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            flipShadowOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentPageIndex = max(currentPageIndex - 1, 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                pageFlipAngle = 0
                flipShadowOpacity = 0
            }
            isFlippingBackward = false
        }
    }

    private func addAndFlipForward() {
        let _ = journalStore.addPage(to: journal.id)
        pages = journalStore.loadPages(for: journal.id)
        flipForward()
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
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchQuery) { _, query in
                        searchResults = journalStore.searchPages(in: journal.id, query: query)
                    }
                    .onSubmit {
                        if let first = searchResults.first,
                           let index = pages.firstIndex(where: { $0.id == first.id }) {
                            currentPageIndex = index
                            isSearching = false
                            searchQuery = ""
                            searchResults = []
                        }
                    }

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = ""; searchResults = [] }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSearching = false
                        searchQuery = ""
                        searchResults = []
                        isSearchFieldFocused = false
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(red: 0.94, green: 0.91, blue: 0.85))

            if !searchQuery.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if searchResults.isEmpty {
                            Text("No matches found")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(.secondary)
                                .padding(14)
                        } else {
                            ForEach(searchResults) { page in
                                Button(action: {
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
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Page \(page.pageNumber)")
                                            .font(.system(size: 11, weight: .semibold, design: .serif))
                                            .foregroundColor(Color(red: 0.30, green: 0.22, blue: 0.12))
                                        Text(page.content.prefix(120) + (page.content.count > 120 ? "..." : ""))
                                            .font(.system(size: 11, design: .serif))
                                            .foregroundColor(Color(red: 0.50, green: 0.42, blue: 0.32))
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.horizontal, 18)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(red: 0.97, green: 0.95, blue: 0.90))
            }
        }
    }

    // MARK: - Close Animation (multi-phase reverse)

    private func closeBook() {
        // Phase 1: Hide pages, show cover
        withAnimation(.easeInOut(duration: 0.2)) {
            isBookOpen = false
            pageBreathScale = 1.0
        }

        // Phase 2: Close cover
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
            coverRotation = 0
            coverShadowRadius = 8
            coverShadowOffset = 4
        }

        // Phase 3: Shrink and fade out
        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            bookScale = 0.7
            bookOpacity = 0
            liftOffset = 30
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            onClose()
        }
    }
}
