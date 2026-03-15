//
//  BookCoverView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI

struct BookCoverView: View {
    let journal: Journal
    let size: CGSize

    private var coverColors: (base: Color, highlight: Color, sheen: Color) {
        switch journal.coverStyle {
        case .black:
            return (Color(red: 0.08, green: 0.08, blue: 0.08), Color(red: 0.16, green: 0.16, blue: 0.16), Color(red: 0.30, green: 0.30, blue: 0.30))
        case .brown:
            return (Color(red: 0.28, green: 0.16, blue: 0.08), Color(red: 0.40, green: 0.26, blue: 0.16), Color(red: 0.52, green: 0.38, blue: 0.26))
        case .burgundy:
            return (Color(red: 0.32, green: 0.06, blue: 0.10), Color(red: 0.45, green: 0.13, blue: 0.16), Color(red: 0.55, green: 0.22, blue: 0.24))
        case .navy:
            return (Color(red: 0.06, green: 0.10, blue: 0.22), Color(red: 0.13, green: 0.18, blue: 0.35), Color(red: 0.22, green: 0.28, blue: 0.48))
        case .forest:
            return (Color(red: 0.06, green: 0.18, blue: 0.08), Color(red: 0.13, green: 0.28, blue: 0.16), Color(red: 0.22, green: 0.38, blue: 0.24))
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Spine
                spineView
                    .frame(width: size.width * 0.08)

                // Cover face
                ZStack {
                    leatherBase
                    smoothGrainOverlay
                    glossySheen
                    wearScuffs
                    stitchingBorder
                    leatherTabClasp
                    titleEmboss
                    pageEdges
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.5), radius: 8, x: 4, y: 4)
    }

    // MARK: - Cover Components

    private var leatherBase: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [coverColors.highlight, coverColors.base, coverColors.base, coverColors.highlight.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
            )
    }

    // Smooth leather grain (calfskin style — subtle, not pebbled)
    private var smoothGrainOverlay: some View {
        Canvas { context, canvasSize in
            let step: CGFloat = 2
            for x in stride(from: 0, to: canvasSize.width, by: step) {
                for y in stride(from: 0, to: canvasSize.height, by: step) {
                    let noise = sin(x * 12.9898 + y * 78.233) * 43758.5453
                    let frac = noise - floor(noise)

                    // Very subtle grain (smooth leather has less texture)
                    if frac > 0.7 {
                        let opacity = (frac - 0.7) * 0.08
                        let rect = CGRect(x: x, y: y, width: step * 0.5, height: step * 0.5)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity)))
                    }

                    if frac < 0.12 {
                        let opacity = (0.12 - frac) * 0.10
                        let rect = CGRect(x: x, y: y, width: step * 0.8, height: step * 0.4)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(opacity)))
                    }
                }
            }

            // Edge darkening
            let edgeInset: CGFloat = 10
            let topRect = CGRect(x: 0, y: 0, width: canvasSize.width, height: edgeInset)
            context.fill(Path(topRect), with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.15), Color.clear]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: edgeInset)
            ))
            let bottomRect = CGRect(x: 0, y: canvasSize.height - edgeInset, width: canvasSize.width, height: edgeInset)
            context.fill(Path(bottomRect), with: .linearGradient(
                Gradient(colors: [Color.clear, Color.black.opacity(0.15)]),
                startPoint: CGPoint(x: 0, y: canvasSize.height - edgeInset),
                endPoint: CGPoint(x: 0, y: canvasSize.height)
            ))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .allowsHitTesting(false)
    }

    // Glossy sheen — the reflective quality of polished leather
    private var glossySheen: some View {
        Canvas { context, canvasSize in
            // Large specular highlight in upper-left area (like light reflecting off leather)
            let center = CGPoint(x: canvasSize.width * 0.35, y: canvasSize.height * 0.3)
            let r = canvasSize.width * 0.5
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: r
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .allowsHitTesting(false)
    }

    // Wear scuffs — whitish marks at corners and edges (matching the real journal)
    private var wearScuffs: some View {
        Canvas { context, canvasSize in
            // Bottom-right corner scuff (prominent in the photo)
            let scuffs: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, opacity: Double)] = [
                (0.7, 0.85, 0.4, 0.2, 0.12),   // Bottom-right corner
                (0.2, 0.9, 0.3, 0.15, 0.10),    // Bottom-left corner
                (0.8, 0.75, 0.15, 0.1, 0.08),   // Right edge wear
                (0.5, 0.95, 0.5, 0.1, 0.09),    // Bottom edge
                (0.15, 0.3, 0.1, 0.2, 0.05),    // Left side light wear
            ]

            for scuff in scuffs {
                let center = CGPoint(x: canvasSize.width * scuff.x, y: canvasSize.height * scuff.y)
                let w = canvasSize.width * scuff.w
                let h = canvasSize.height * scuff.h
                let rect = CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(scuff.opacity), Color.clear]),
                        center: center,
                        startRadius: 0,
                        endRadius: max(w, h) / 2
                    )
                )
            }

            // Fine scratch lines
            let scratches: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = [
                (0.3, 0.6, 0.5, 0.65),
                (0.6, 0.5, 0.75, 0.52),
                (0.4, 0.8, 0.55, 0.82),
            ]
            for scratch in scratches {
                var path = Path()
                path.move(to: CGPoint(x: canvasSize.width * scratch.x1, y: canvasSize.height * scratch.y1))
                path.addLine(to: CGPoint(x: canvasSize.width * scratch.x2, y: canvasSize.height * scratch.y2))
                context.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .allowsHitTesting(false)
    }

    // Stitching around all edges
    private var stitchingBorder: some View {
        RoundedRectangle(cornerRadius: 4)
            .inset(by: 5)
            .stroke(
                coverColors.sheen.opacity(0.3),
                style: StrokeStyle(lineWidth: 0.8, dash: [2.5, 2.5])
            )
            .allowsHitTesting(false)
    }

    // Leather tab + gold rose emblem (matching the real journal's clasp)
    private var leatherTabClasp: some View {
        VStack(spacing: 0) {
            // Leather tab extending from top
            ZStack {
                // Tab shape
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 2, bottomLeading: 4, bottomTrailing: 4, topTrailing: 2))
                    .fill(coverColors.base)
                    .frame(width: 20, height: 22)
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 2, bottomLeading: 4, bottomTrailing: 4, topTrailing: 2))
                            .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Gold rose/flower emblem
                ZStack {
                    // Outer circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.88, green: 0.78, blue: 0.45),
                                    Color(red: 0.80, green: 0.68, blue: 0.35),
                                    Color(red: 0.60, green: 0.50, blue: 0.25)
                                ],
                                center: .init(x: 0.4, y: 0.35),
                                startRadius: 0,
                                endRadius: 7
                            )
                        )
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.4), radius: 0.5, x: 0.5, y: 0.5)

                    // Inner rose spiral detail
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let r: CGFloat = 3

                        // Spiral petals
                        for i in 0..<6 {
                            let angle = Double(i) * .pi / 3
                            let petalCenter = CGPoint(
                                x: center.x + cos(angle) * r * 0.4,
                                y: center.y + sin(angle) * r * 0.4
                            )
                            let petalRect = CGRect(x: petalCenter.x - 1.5, y: petalCenter.y - 1.5, width: 3, height: 3)
                            context.fill(
                                Path(ellipseIn: petalRect),
                                with: .color(Color(red: 0.70, green: 0.58, blue: 0.28).opacity(0.5))
                            )
                        }

                        // Center dot
                        let dotRect = CGRect(x: center.x - 1, y: center.y - 1, width: 2, height: 2)
                        context.fill(Path(ellipseIn: dotRect), with: .color(Color(red: 0.55, green: 0.45, blue: 0.20)))
                    }
                    .frame(width: 12, height: 12)
                }
                .offset(y: 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 6)
    }

    private var titleEmboss: some View {
        VStack {
            Spacer()

            Text(journal.title)
                .font(.system(size: max(8, size.width * 0.08), weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.77, green: 0.64, blue: 0.30).opacity(0.65))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.4), radius: 0.5, x: 0, y: 0.5)

            Spacer()
                .frame(height: size.height * 0.25)
        }
    }

    private var pageEdges: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(red: 0.97, green: 0.96, blue: 0.90))
                        .frame(width: 2.5, height: (size.height - 10) / 10)
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(0.04))
                                .frame(width: 2.5, height: 0.5),
                            alignment: .bottom
                        )
                }
            }
            .padding(.vertical, 5)
        }
    }

    // MARK: - Spine

    private var spineView: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [coverColors.base.opacity(0.6), coverColors.base, coverColors.base.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Spine ridges
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                    Spacer()
                }
            }
            .padding(.vertical, 8)

            // Spine title
            Text(journal.title)
                .font(.system(size: 6, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.77, green: 0.64, blue: 0.30).opacity(0.4))
                .rotationEffect(.degrees(-90))
                .lineLimit(1)
        }
    }
}
