//
//  NoteItemView.swift
//  TLNT
//
//  Created by Ayush Kumar on 2/1/26.
//

import SwiftUI
import AppKit
import AVKit

struct NoteItemView: View {
    let note: Note
    let onDelete: () -> Void

    var body: some View {
        Group {
            switch note.type {
            case .text:
                TextNoteView(text: note.content)
            case .screenshot:
                ImageNoteView(path: note.content)
            case .recording:
                VideoNoteView(path: note.content)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .contextMenu {
            if note.type != .text {
                Button {
                    showInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Divider()
            }

            Button {
                copyNote()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func showInFinder() {
        let url = URL(fileURLWithPath: note.content)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    private func copyNote() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch note.type {
        case .text:
            pasteboard.setString(note.content, forType: .string)
        case .screenshot, .recording:
            let url = URL(fileURLWithPath: note.content)
            pasteboard.writeObjects([url as NSURL])
        }
    }
}

// MARK: - Text Note View

struct TextNoteView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .lineLimit(12)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

// MARK: - Image Note View

struct ImageNoteView: View {
    let path: String

    var body: some View {
        Group {
            if let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipped()
            } else {
                missingFileView
            }
        }
        .onTapGesture(count: 2) {
            openFile()
        }
    }

    private var missingFileView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("File not found")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }

    private func openFile() {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Video Note View

struct VideoNoteView: View {
    let path: String
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
            } else if FileManager.default.fileExists(atPath: path) {
                Color.black
                    .frame(height: 150)
            } else {
                missingFileView
            }

            if FileManager.default.fileExists(atPath: path) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            generateThumbnail()
        }
        .onTapGesture(count: 2) {
            openFile()
        }
    }

    private var missingFileView: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("File not found")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }

    private func generateThumbnail() {
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0, preferredTimescale: 600)

        DispatchQueue.global(qos: .userInitiated).async {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.thumbnail = nsImage
                }
            }
        }
    }

    private func openFile() {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}
