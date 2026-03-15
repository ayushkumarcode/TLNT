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

    private var coverColors: (base: Color, highlight: Color) {
        switch journal.coverStyle {
        case .black:
            return (Color(red: 0.10, green: 0.10, blue: 0.10), Color(red: 0.18, green: 0.18, blue: 0.18))
        case .brown:
            return (Color(red: 0.30, green: 0.18, blue: 0.10), Color(red: 0.42, green: 0.28, blue: 0.18))
        case .burgundy:
            return (Color(red: 0.35, green: 0.08, blue: 0.12), Color(red: 0.48, green: 0.15, blue: 0.18))
        case .navy:
            return (Color(red: 0.08, green: 0.12, blue: 0.25), Color(red: 0.15, green: 0.20, blue: 0.38))
        case .forest:
            return (Color(red: 0.08, green: 0.20, blue: 0.10), Color(red: 0.15, green: 0.30, blue: 0.18))
        }
    }

    var body: some View {
        ZStack {
            // Book body with spine and page edges
            HStack(spacing: 0) {
                // Spine
                spineView
                    .frame(width: size.width * 0.08)

                // Cover face
                ZStack {
                    // Leather base
                    leatherBase

                    // Grain texture overlay
                    grainOverlay

                    // Wear patina
                    wearPatina

                    // Stitching border
                    stitchingBorder

                    // Gold clasp at top-center
                    goldClasp

                    // Title emboss
                    titleEmboss

                    // Page edges visible on right side
                    pageEdges
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.5), radius: 8, x: 4, y: 4)
    }

    // MARK: - Cover Components

    private var leatherBase: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [coverColors.highlight, coverColors.base, coverColors.base.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Inner edge shadow for depth
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.4), lineWidth: 1)
            )
    }

    private var grainOverlay: some View {
        Canvas { context, canvasSize in
            // Procedural leather grain — fine pebble texture
            let step: CGFloat = 2.5
            for x in stride(from: 0, to: canvasSize.width, by: step) {
                for y in stride(from: 0, to: canvasSize.height, by: step) {
                    let noise = sin(x * 12.9898 + y * 78.233) * 43758.5453
                    let frac = noise - floor(noise)

                    // Light grain highlights (pebble peaks)
                    if frac > 0.55 {
                        let opacity = (frac - 0.55) * 0.12
                        let rect = CGRect(x: x, y: y, width: step * 0.7, height: step * 0.7)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity)))
                    }

                    // Dark grain valleys
                    if frac < 0.2 {
                        let opacity = (0.2 - frac) * 0.15
                        let rect = CGRect(x: x, y: y, width: step * 1.0, height: step * 0.5)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(opacity)))
                    }

                    // Cross-hatch grain (diagonal lines for leather texture)
                    let noise2 = sin(x * 7.456 + y * 23.111) * 12345.6789
                    let frac2 = noise2 - floor(noise2)
                    if frac2 > 0.85 {
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: y))
                        line.addLine(to: CGPoint(x: x + step * 2, y: y + step))
                        context.stroke(line, with: .color(Color.black.opacity(0.04)), lineWidth: 0.3)
                    }
                }
            }

            // Edge darkening (vignette on the cover)
            let edgeInset: CGFloat = 8
            let topGrad = CGRect(x: 0, y: 0, width: canvasSize.width, height: edgeInset)
            context.fill(Path(topGrad), with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.12), Color.clear]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: edgeInset)
            ))
            let bottomGrad = CGRect(x: 0, y: canvasSize.height - edgeInset, width: canvasSize.width, height: edgeInset)
            context.fill(Path(bottomGrad), with: .linearGradient(
                Gradient(colors: [Color.clear, Color.black.opacity(0.12)]),
                startPoint: CGPoint(x: 0, y: canvasSize.height - edgeInset),
                endPoint: CGPoint(x: 0, y: canvasSize.height)
            ))
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .allowsHitTesting(false)
    }

    private var wearPatina: some View {
        Canvas { context, canvasSize in
            // Simulate worn areas with lighter spots
            let wearSpots: [(CGFloat, CGFloat, CGFloat)] = [
                (0.3, 0.25, 0.3),
                (0.7, 0.4, 0.25),
                (0.5, 0.7, 0.35),
                (0.2, 0.6, 0.2),
                (0.8, 0.8, 0.15),
            ]
            for (xFrac, yFrac, radius) in wearSpots {
                let center = CGPoint(x: canvasSize.width * xFrac, y: canvasSize.height * yFrac)
                let r = canvasSize.width * radius
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.06), Color.clear]),
                        center: center,
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .allowsHitTesting(false)
    }

    private var stitchingBorder: some View {
        RoundedRectangle(cornerRadius: 3)
            .inset(by: 6)
            .stroke(
                coverColors.highlight.opacity(0.4),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
            )
            .allowsHitTesting(false)
    }

    private var goldClasp: some View {
        VStack {
            // Leather tab
            RoundedRectangle(cornerRadius: 2)
                .fill(coverColors.base)
                .frame(width: 14, height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                )

            // Gold circle button
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.42),
                            Color(red: 0.77, green: 0.64, blue: 0.30),
                            Color(red: 0.55, green: 0.46, blue: 0.21)
                        ],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: 6
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0.5, y: 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
    }

    private var titleEmboss: some View {
        VStack {
            Spacer()

            Text(journal.title)
                .font(.system(size: max(8, size.width * 0.08), weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.77, green: 0.64, blue: 0.30).opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: 0.5)

            Spacer()
                .frame(height: size.height * 0.25)
        }
    }

    private var pageEdges: some View {
        HStack {
            Spacer()

            // Stack of page edges on the right side
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color(red: 0.98, green: 0.97, blue: 0.91))
                        .frame(width: 2, height: (size.height - 12) / 8)
                        .overlay(
                            Rectangle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 2, height: 0.5),
                            alignment: .bottom
                        )
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Spine

    private var spineView: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [coverColors.base.opacity(0.7), coverColors.base, coverColors.base.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Spine ridges
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                    Spacer()
                }
            }
            .padding(.vertical, 10)

            // Spine title (rotated)
            Text(journal.title)
                .font(.system(size: 6, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.77, green: 0.64, blue: 0.30).opacity(0.5))
                .rotationEffect(.degrees(-90))
                .lineLimit(1)
        }
    }
}
