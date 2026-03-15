//
//  PageFlipView.swift
//  TLNT
//
//  Created by Ayush Kumar on 3/15/26.
//

import SwiftUI
import AppKit
import QuartzCore

struct PageFlipView: NSViewRepresentable {
    let frontContent: NSView
    let backContent: NSView
    let isFlipping: Bool
    let flipProgress: CGFloat // 0 = front showing, 1 = back showing
    let onFlipComplete: () -> Void

    func makeNSView(context: Context) -> PageFlipHostView {
        let view = PageFlipHostView()
        view.onFlipComplete = onFlipComplete
        view.setContent(front: frontContent, back: backContent)
        return view
    }

    func updateNSView(_ nsView: PageFlipHostView, context: Context) {
        if isFlipping {
            nsView.animateFlip(progress: flipProgress)
        }
    }
}

class PageFlipHostView: NSView {
    private var frontLayer: CALayer?
    private var backLayer: CALayer?
    private var flipLayer: CALayer?
    var onFlipComplete: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isDoubleSided = false

        // Set perspective on the parent layer
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 800.0
        layer?.sublayerTransform = perspective
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(front: NSView, back: NSView) {
        // Clear existing layers
        flipLayer?.removeFromSuperlayer()

        let container = CALayer()
        container.frame = bounds
        container.anchorPoint = CGPoint(x: 0, y: 0.5) // Anchor at left (spine)
        container.position = CGPoint(x: 0, y: bounds.midY)
        container.isDoubleSided = false

        // Front face
        let fl = CALayer()
        fl.frame = container.bounds
        fl.backgroundColor = NSColor(red: 0.99, green: 0.96, blue: 0.88, alpha: 1.0).cgColor
        fl.isDoubleSided = false
        container.addSublayer(fl)
        frontLayer = fl

        // Back face (mirrored)
        let bl = CALayer()
        bl.frame = container.bounds
        bl.backgroundColor = NSColor(red: 0.98, green: 0.95, blue: 0.87, alpha: 1.0).cgColor
        bl.isDoubleSided = false
        bl.transform = CATransform3DMakeRotation(.pi, 0, 1, 0) // Pre-rotated to show on back
        container.addSublayer(bl)
        backLayer = bl

        layer?.addSublayer(container)
        flipLayer = container
    }

    func animateFlip(progress: CGFloat) {
        guard let flipLayer = flipLayer else { return }

        let angle = -CGFloat.pi * progress // 0 to -pi

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1.0))
        CATransaction.setCompletionBlock { [weak self] in
            if progress >= 1.0 {
                self?.onFlipComplete?()
            }
        }

        flipLayer.transform = CATransform3DMakeRotation(angle, 0, 1, 0)

        // Shadow effect during flip
        let shadowOpacity = Float(sin(Double(progress) * .pi) * 0.3)
        frontLayer?.shadowOpacity = shadowOpacity
        frontLayer?.shadowOffset = CGSize(width: 5, height: 5)
        frontLayer?.shadowRadius = 8

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        flipLayer?.frame = bounds
        frontLayer?.frame = flipLayer?.bounds ?? bounds
        backLayer?.frame = flipLayer?.bounds ?? bounds
    }
}
