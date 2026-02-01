//
//  ToastView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Cocoa
import SwiftUI

class ToastWindow: NSWindow {

    init(message: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let hostingView = NSHostingView(rootView: ToastContent(message: message))
        hostingView.frame = self.frame
        self.contentView = hostingView

        // Position in top-right corner of main screen
        positionInTopRight()
    }

    private func positionInTopRight() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 20
        let y = screenFrame.maxY - frame.height - 20

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showAndDismiss(after delay: TimeInterval = 1.5) {
        self.alphaValue = 0
        self.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1
        }

        // Fade out after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self?.animator().alphaValue = 0
            } completionHandler: {
                self?.close()
            }
        }
    }
}

struct ToastContent: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}
