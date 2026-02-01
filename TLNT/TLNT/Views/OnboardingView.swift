//
//  OnboardingView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import SwiftUI
import Cocoa

class OnboardingWindowController {
    private var window: NSWindow?
    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func show() {
        let contentView = OnboardingView {
            self.window?.close()
            self.onComplete()
        }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Welcome to TLNT"
        window?.contentView = NSHostingView(rootView: contentView)
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var accessibilityGranted = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            // Title
            Text("Welcome to TLNT")
                .font(.title)
                .fontWeight(.semibold)

            // Description
            Text("The fastest way to capture screenshots and text snippets.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.horizontal, 32)

            // Permission Section
            VStack(spacing: 16) {
                Text("Accessibility Permission")
                    .font(.headline)

                Text("Required to capture selected text from any app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: requestPermission) {
                    if accessibilityGranted {
                        Label("Permission Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("Grant Permission")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(accessibilityGranted)
            }

            Divider()
                .padding(.horizontal, 32)

            // Hotkeys
            VStack(alignment: .leading, spacing: 10) {
                Text("Hotkeys")
                    .font(.headline)

                HotkeyRow(keys: "⌘⌥S", description: "Send next screenshot to TLNT")
                HotkeyRow(keys: "⌘⌥K", description: "Capture selected text")
                HotkeyRow(keys: "⌘⌥L", description: "Open TLNT window")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)

            Spacer()

            // Get Started Button
            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!accessibilityGranted)
        }
        .padding(24)
        .frame(width: 450, height: 420)
        .onAppear {
            checkPermission()
        }
    }

    private func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted

        // Poll for permission grant since the system dialog is async
        if !trusted {
            pollForPermission()
        }
    }

    private func checkPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func pollForPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if AXIsProcessTrusted() {
                accessibilityGranted = true
            } else {
                pollForPermission()
            }
        }
    }
}

struct HotkeyRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}
