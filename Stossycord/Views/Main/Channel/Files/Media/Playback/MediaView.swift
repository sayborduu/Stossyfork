//
//  MediaView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import Foundation
import AVFoundation
import OggDecoder
import SwiftUI
#if os(iOS)
import Giffy
#endif
import AVKit

struct MediaView: View {
    @State private var savefile = false

    private let attachment: Attachment?
    private let url: URL?
    private let isVoiceMessage: Bool
    private let isCurrentUser: Bool?
    private let onVoiceScrubChanged: ((Bool) -> Void)?

    @AppStorage("voiceMessagesEnabled") private var voiceMessagesEnabled = true

    private let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv"]
    private let audioExtensions = ["mp3", "m4a", "ogg"]
    private let imageExtensions = ["jpg", "jpeg", "png"]
    private let maxDimension: CGFloat = 300.0

    init(
        attachment: Attachment,
        isVoiceMessage: Bool,
        isCurrentUser: Bool?,
        onVoiceScrubChanged: ((Bool) -> Void)? = nil
    ) {
        self.attachment = attachment
        self.url = URL(string: attachment.url)
        self.isVoiceMessage = isVoiceMessage
        self.isCurrentUser = isCurrentUser
        self.onVoiceScrubChanged = onVoiceScrubChanged
    }

    init(url: String, isCurrentUser: Bool? = nil, onVoiceScrubChanged: ((Bool) -> Void)? = nil) {
        self.attachment = nil
        self.url = URL(string: url)
        self.isVoiceMessage = false
        self.isCurrentUser = isCurrentUser
        self.onVoiceScrubChanged = onVoiceScrubChanged
    }

    private var alignment: Alignment {
        guard let isCurrentUser else { return .center }
        return isCurrentUser ? .trailing : .leading
    }

    var body: some View {
        Group {
            if let url {
                if isVoiceMessage && !voiceMessagesEnabled {
                    disabledVoiceMessageView
                } else {
                    content(for: url)
                }
            } else {
                Text("Invalid URL")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    @ViewBuilder
    private func content(for url: URL) -> some View {
        if videoExtensions.contains(url.pathExtension.lowercased()) {
            FSVideoPlayer(url: url)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: maxDimension)
                .contextMenu { saveButton }
        } else if imageExtensions.contains(url.pathExtension.lowercased()) {
            imageView(for: url)
        } else if url.pathExtension.lowercased() == "gif" {
            gifView(for: url)
        } else if audioExtensions.contains(url.pathExtension.lowercased()) {
            AudioPlayer(
                url: url,
                attachment: attachment,
                isVoiceMessage: isVoiceMessage,
                onScrubActiveChanged: onVoiceScrubChanged
            )
                .contextMenu { saveButton }
        } else {
            DownloadView(url: url)
        }
    }

    private var saveButton: some View {
        Button { savefile = true } label: { Text("Save to photos") }
    }

    private var disabledVoiceMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Voice message blocked", systemImage: "waveform")
                .font(.headline)
            Text("Enable voice messages in settings to view or play this clip.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: alignment)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    private func imageView(for url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 50, height: 50)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxDimension)
                    .contextMenu { saveButton }
            case .failure:
                DownloadView(url: url)
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func gifView(for url: URL) -> some View {
#if !os(macOS)
        AsyncGiffy(url: url) { phase in
            switch phase {
            case .loading:
                ProgressView()
                    .frame(width: 50, height: 50)
            case .error:
                DownloadView(url: url)
            case .success(let giffy):
                giffy
                    .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxDimension)
                    .contextMenu { saveButton }
            }
        }
#else
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 50, height: 50)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxDimension)
                    .contextMenu { saveButton }
            case .failure:
                DownloadView(url: url)
            @unknown default:
                EmptyView()
            }
        }
#endif
    }
}
