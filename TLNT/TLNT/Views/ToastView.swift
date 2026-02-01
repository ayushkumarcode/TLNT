//
//  ToastView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import Cocoa
import SwiftUI

/// Manager that keeps toast windows alive until they're dismissed
class ToastManager {
    static let shared = ToastManager()
    private var activeToasts: [ToastWindow] = []
    private let lock = NSLock()

    private init() {}

    func showToast(_ message: String) {
        TLNTLogger.debug("ToastManager.showToast called with: '\(message)'", category: TLNTLogger.ui)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            TLNTLogger.debug("Creating ToastWindow on main thread...", category: TLNTLogger.ui)
            let toast = ToastWindow(message: message)

            self.lock.lock()
            self.activeToasts.append(toast)
            TLNTLogger.debug("Toast added to activeToasts, count: \(self.activeToasts.count)", category: TLNTLogger.ui)
            self.lock.unlock()

            toast.showAndDismiss { [weak self] in
                TLNTLogger.debug("Toast dismissed, removing from activeToasts", category: TLNTLogger.ui)
                self?.lock.lock()
                self?.activeToasts.removeAll { $0 === toast }
                TLNTLogger.debug("Toast removed, count: \(self?.activeToasts.count ?? 0)", category: TLNTLogger.ui)
                self?.lock.unlock()
            }
        }
    }
}

class ToastWindow: NSWindow {

    private var onDismiss: (() -> Void)?

    init(message: String) {
        TLNTLogger.debug("ToastWindow.init called with message: '\(message)'", category: TLNTLogger.ui)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        TLNTLogger.debug("ToastWindow super.init completed", category: TLNTLogger.ui)

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false // IMPORTANT: Don't release when closed

        TLNTLogger.debug("Creating NSHostingView for toast content...", category: TLNTLogger.ui)
        let hostingView = NSHostingView(rootView: ToastContent(message: message))
        hostingView.frame = self.frame
        self.contentView = hostingView
        TLNTLogger.debug("NSHostingView set as contentView", category: TLNTLogger.ui)

        // Position in top-right corner of main screen
        positionInTopRight()
        TLNTLogger.debug("ToastWindow initialized successfully", category: TLNTLogger.ui)
    }

    private func positionInTopRight() {
        TLNTLogger.debug("positionInTopRight called", category: TLNTLogger.ui)

        guard let screen = NSScreen.main else {
            TLNTLogger.warning("No main screen found", category: TLNTLogger.ui)
            return
        }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 20
        let y = screenFrame.maxY - frame.height - 20

        TLNTLogger.debug("Positioning toast at (\(x), \(y))", category: TLNTLogger.ui)
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showAndDismiss(after delay: TimeInterval = 1.5, completion: @escaping () -> Void) {
        TLNTLogger.debug("showAndDismiss called with delay: \(delay)", category: TLNTLogger.ui)

        self.onDismiss = completion
        self.alphaValue = 0

        TLNTLogger.debug("Ordering toast window front...", category: TLNTLogger.ui)
        self.orderFront(nil)

        // Fade in
        TLNTLogger.debug("Starting fade-in animation...", category: TLNTLogger.ui)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1
        } completionHandler: {
            TLNTLogger.debug("Fade-in complete", category: TLNTLogger.ui)
        }

        // Fade out after delay - use strong self to keep window alive
        TLNTLogger.debug("Scheduling fade-out after \(delay) seconds...", category: TLNTLogger.ui)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            TLNTLogger.debug("Starting fade-out animation...", category: TLNTLogger.ui)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self.animator().alphaValue = 0
            } completionHandler: {
                TLNTLogger.debug("Fade-out complete, closing window...", category: TLNTLogger.ui)
                self.orderOut(nil)
                TLNTLogger.debug("Window ordered out, calling completion...", category: TLNTLogger.ui)
                self.onDismiss?()
                self.onDismiss = nil
                TLNTLogger.debug("Toast dismissal complete", category: TLNTLogger.ui)
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
