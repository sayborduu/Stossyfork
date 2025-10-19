//
//  AudioPlayer.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import OggDecoder
import AVFoundation
import Speech
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if canImport(TranscriptionKit)
import TranscriptionKit
#endif

struct AudioPlayer: View {
    let url: URL
    let attachment: Attachment?
    let isVoiceMessage: Bool
    private let onScrubActiveChanged: ((Bool) -> Void)?

    @State private var player: AVPlayer?
    @State private var voicePlayer: AVAudioPlayer?
    @State private var voiceDelegate: VoicePlaybackDelegator?
    @State private var progress: Double = 0
    @State private var isPlaying = false
    @State private var downloadedVoiceURL: URL?
    @State private var processedVoiceURL: URL?
    @State private var waveformSamples: [CGFloat]
    @State private var waveformAnimationTimer: Timer?
    @State private var displayedDuration: TimeInterval?
    @State private var timeObserverToken: Any?
    @State private var isTranscribing = false
    @State private var transcription: String?
    @State private var transcriptionError: String?
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var voiceProgressTimer: Timer?
    @State private var playbackEndObserver: Any?
    @State private var isScrubbing = false

    @AppStorage("voiceMessageShowTranscription") private var showTranscriptionButton = true
    @AppStorage("voiceMessageTranscriptionLanguage") private var transcriptionLanguageSetting = "auto"

    private let fileManager = FileManager.default

    init(
        url: URL,
        attachment: Attachment? = nil,
        isVoiceMessage: Bool = false,
        onScrubActiveChanged: ((Bool) -> Void)? = nil
    ) {
        self.url = url
        self.attachment = attachment
        let resolvedVoiceFlag = isVoiceMessage || attachment?.isLikelyVoiceMessage == true
        self.isVoiceMessage = resolvedVoiceFlag
        self.onScrubActiveChanged = onScrubActiveChanged

        let samples = AudioPlayer.decodeWaveform(from: attachment?.waveform)
        let initialWaveform = samples.isEmpty && resolvedVoiceFlag ? AudioPlayer.placeholderWaveform() : samples
        _waveformSamples = State(initialValue: initialWaveform)
        _displayedDuration = State(initialValue: attachment?.durationSeconds)
    }

    var body: some View {
        Group {
            if isVoiceMessage {
                voiceMessageBody
            } else {
                standardBody
            }
        }
        .onDisappear(perform: teardown)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Slider(value: $progress, in: 0...1, onEditingChanged: sliderChanged)

            if let durationText = formattedDuration {
                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if shouldShowTranscribeButton {
                transcriptionSection
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private struct VoiceWaveformView: View {
        let samples: [CGFloat]
        let progress: Double
        let activeColor: Color
        let inactiveColor: Color
        let onScrubChanging: ((Double) -> Void)?
        let onScrubEnded: ((Double) -> Void)?
        let onScrubStateChanged: ((Bool) -> Void)?

        @State private var dragMode: WaveDragState = .undetermined
        @State private var isScrubActive = false

        private var displaySamples: [CGFloat] {
            let maxBars = 32
            if samples.count <= maxBars {
                return samples
            }
            let step = samples.count / maxBars
            return stride(from: 0, to: samples.count, by: step).map { samples[$0] }
        }

        init(
            samples: [CGFloat],
            progress: Double,
            activeColor: Color = .blue,
            inactiveColor: Color = Color.blue.opacity(0.25),
            onScrubChanging: ((Double) -> Void)? = nil,
            onScrubEnded: ((Double) -> Void)? = nil,
            onScrubStateChanged: ((Bool) -> Void)? = nil
        ) {
            self.samples = samples
            self.progress = progress
            self.activeColor = activeColor
            self.inactiveColor = inactiveColor
            self.onScrubChanging = onScrubChanging
            self.onScrubEnded = onScrubEnded
            self.onScrubStateChanged = onScrubStateChanged
        }

        var body: some View {
            GeometryReader { proxy in
                let sampleCount = max(displaySamples.count, 1)
                let safeProgress = min(max(progress, 0), 1)
                let width = max(proxy.size.width, 1)
                let height = proxy.size.height
                let spacing = max(1, width / CGFloat(sampleCount * 3))
                let barWidth = max(1, min((width - CGFloat(sampleCount - 1) * spacing) / CGFloat(sampleCount), 3))
                let activeIndex = max(0, min(sampleCount - 1, Int(round(safeProgress * Double(sampleCount - 1)))))

                let gesture = DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        updateDragMode(with: value.translation)
                        guard dragMode == .horizontal else {
                            if isScrubActive {
                                isScrubActive = false
                                onScrubStateChanged?(false)
                            }
                            return
                        }
                        if !isScrubActive {
                            isScrubActive = true
                            onScrubStateChanged?(true)
                        }
                        let normalized = Self.normalizedProgress(x: value.location.x, width: width)
                        onScrubChanging?(normalized)
                    }
                    .onEnded { value in
                        defer {
                            if isScrubActive {
                                isScrubActive = false
                                onScrubStateChanged?(false)
                            }
                            dragMode = .undetermined
                        }
                        guard dragMode == .horizontal else { return }
                        let normalized = Self.normalizedProgress(x: value.location.x, width: width)
                        onScrubEnded?(normalized)
                    }

                HStack(alignment: .center, spacing: spacing) {
                    ForEach(Array(displaySamples.enumerated()), id: \.offset) { index, sample in
                        RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                            .fill(index <= activeIndex ? activeColor : inactiveColor)
                            .frame(width: barWidth, height: max(height * 0.18, sample * height))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .gesture(gesture)
            }
        }

        private func updateDragMode(with translation: CGSize) {
            guard dragMode == .undetermined else { return }
            let horizontal = abs(translation.width)
            let vertical = abs(translation.height)

            if horizontal > 12 && horizontal > vertical * 1.2 {
                dragMode = .horizontal
            } else if vertical > horizontal {
                dragMode = .vertical
            }
        }

        private static func normalizedProgress(x: CGFloat, width: CGFloat) -> Double {
            guard width > 0 else { return 0 }
            let clampedX = max(0, min(width, x))
            return Double(clampedX / width)
        }

        private enum WaveDragState {
            case undetermined
            case horizontal
            case vertical
        }
    }

    private var voiceMessageBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let voiceTitle {
                Text(voiceTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                voicePlayButton

                VoiceWaveformView(
                    samples: waveformSamples,
                    progress: progress,
                    activeColor: voiceAccent,
                    inactiveColor: voiceAccent.opacity(0.25),
                    onScrubChanging: { newValue in
                        waveformScrubChanged(newValue)
                    },
                    onScrubEnded: { newValue in
                        waveformScrubEnded(newValue)
                    },
                    onScrubStateChanged: { isActive in
                        onScrubActiveChanged?(isActive)
                    }
                )
                .frame(height: 36)

                if let durationText = formattedDuration {
                    Text(durationText)
                        .font(.system(.footnote, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            voiceTranscriptionContent
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(voiceBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(voiceAccent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: voiceAccent.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var voicePlayButton: some View {
        Button(action: togglePlayPause) {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [voiceAccent, voiceAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: voiceAccent.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var voiceTranscriptionContent: some View {
        if let transcription {
            Text(transcription)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineSpacing(2)
        } else if isTranscribing {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Transcribing…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            if let transcriptionError {
                Text(transcriptionError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if shouldShowTranscribeButton {
                Button(action: transcribeTapped) {
                    Label("Transcribe", systemImage: "text.alignleft")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var voiceTitle: String? {
        if let filename = attachment?.filename, !filename.lowercased().hasPrefix("voice-message") {
            return filename
        }
        if url.isFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return nil
    }

    private var voiceAccent: Color {
        #if os(iOS)
        Color(UIColor.systemBlue)
        #elseif os(macOS)
        Color(NSColor.controlAccentColor)
        #else
        Color.accentColor
        #endif
    }

    private var voiceBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        Color(NSColor.textBackgroundColor).opacity(0.85)
        #else
        Color.gray.opacity(0.15)
        #endif
    }

    private var shouldShowTranscribeButton: Bool {
        isVoiceMessage && showTranscriptionButton
    }

    @ViewBuilder
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let transcription {
                Text(transcription)
                    .font(.body)
                    .foregroundStyle(.primary)
            } else if let transcriptionError {
                Text(transcriptionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: transcribeTapped) {
                if isTranscribing {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Label("Transcribe", systemImage: "text.alignleft")
                }
            }
            .disabled(isTranscribing)
        }
    }

    private var formattedDuration: String? {
        // If scrubbing or playing, show current position time
        if isScrubbing || isPlaying {
            let currentTime: TimeInterval
            if let voicePlayer = voicePlayer {
                currentTime = voicePlayer.currentTime
            } else if let player = player {
                currentTime = player.currentItem?.currentTime().seconds ?? 0
            } else {
                currentTime = progress * (displayedDuration ?? attachment?.durationSeconds ?? 0)
            }
            return formattedTime(currentTime)
        }
        // If paused, show total duration
        let duration = displayedDuration ?? attachment?.durationSeconds
        return duration != nil ? formattedTime(duration!) : nil
    }

    private func formattedTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = duration >= 60 ? [.minute, .second] : [.second]
        return formatter.string(from: duration) ?? String(format: "%.1f", duration)
    }

    private func togglePlayPause() {
        if isVoiceMessage {
            toggleVoicePlayback()
        } else {
            toggleStandardPlayback()
        }
    }

    private func toggleStandardPlayback() {
        if isPlaying {
            player?.pause()
            removeTimeObserver()
            isPlaying = false
            isScrubbing = false
            return
        }

        isScrubbing = false
        progress = 0
        let player = AVPlayer(url: url)
        self.player = player
        player.play()
        addTimeObserver(to: player)
        observePlaybackEnd(for: player)
        isPlaying = true
    }

    private func toggleVoicePlayback() {
        if isPlaying {
            stopVoicePlayback()
            return
        }

        isScrubbing = false
        progress = 0
        prepareVoiceFile { localURL in
            guard let localURL else { return }
            do {
                let voicePlayer = try AVAudioPlayer(contentsOf: localURL)
                let delegate = VoicePlaybackDelegator(onFinish: { finishPlayback() })
                voiceDelegate = delegate
                voicePlayer.delegate = delegate
                voicePlayer.play()
                self.voicePlayer = voicePlayer
                self.displayedDuration = voicePlayer.duration
                startWaveformAnimation()
                startVoiceProgressMonitoring()
                self.isPlaying = true
            } catch {
                transcriptionError = "Unable to play voice message."
            }
        }
    }

    private func prepareVoiceFile(completion: @escaping (URL?) -> Void) {
        if url.isFileURL {
            completion(url)
            return
        }

        if let processedVoiceURL {
            completion(processedVoiceURL)
            return
        }

        downloadAudioFile(from: url.absoluteString) { downloadedURL in
            guard let downloadedURL else {
                DispatchQueue.main.async {
                    transcriptionError = "Failed to download voice message."
                    completion(nil)
                }
                return
            }

            let lowercasedExtension = downloadedURL.pathExtension.lowercased()
            if lowercasedExtension == "ogg" {
                let decoder = OGGDecoder()
                decoder.decode(downloadedURL) { decodedURL in
                    DispatchQueue.main.async {
                        if let decodedURL {
                            self.downloadedVoiceURL = downloadedURL
                            self.processedVoiceURL = decodedURL
                            completion(decodedURL)
                        } else {
                            print("[AudioPlayer] Failed to decode OGG stream, using original file.")
                            self.downloadedVoiceURL = downloadedURL
                            self.processedVoiceURL = downloadedURL
                            completion(downloadedURL)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.downloadedVoiceURL = downloadedURL
                    self.processedVoiceURL = downloadedURL
                    completion(downloadedURL)
                }
            }
        }
    }

    private func stopVoicePlayback() {
        voiceProgressTimer?.invalidate()
        voiceProgressTimer = nil
        stopWaveformAnimation()
        voicePlayer?.stop()
        voicePlayer = nil
        voiceDelegate = nil
        isPlaying = false
        isScrubbing = false
    }

    private func finishPlayback() {
        isPlaying = false
        progress = 0
        voiceProgressTimer?.invalidate()
        voiceProgressTimer = nil
        stopWaveformAnimation()
        isScrubbing = false
        removeTimeObserver()
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        voicePlayer?.stop()
        voicePlayer = nil
        voiceDelegate = nil
        if let player {
            player.pause()
            player.seek(to: .zero)
        }
    }
    private func startWaveformAnimation() {
        stopWaveformAnimation()
        waveformAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            animateWaveform()
        }
    }

    private func stopWaveformAnimation() {
        waveformAnimationTimer?.invalidate()
        waveformAnimationTimer = nil
    }

    private func animateWaveform() {
        // Simple animation: randomly jitter the samples a bit
        guard isPlaying, isVoiceMessage else { return }
        waveformSamples = waveformSamples.map { sample in
            let jitter = CGFloat.random(in: -0.08...0.08)
            return max(0.08, min(1.0, sample + jitter))
        }
    }

    private func addTimeObserver(to player: AVPlayer) {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return }
            if !isScrubbing {
                progress = min(1, max(0, time.seconds / duration))
            }
            displayedDuration = duration
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func observePlaybackEnd(for player: AVPlayer) {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            finishPlayback()
        }
    }

    private func sliderChanged(_ editing: Bool) {
        isScrubbing = editing
        seek(to: progress)
        if !editing {
            isScrubbing = false
        }
    }

    private func waveformScrubChanged(_ newProgress: Double) {
        isScrubbing = true
        previewScrub(at: newProgress)
    }

    private func waveformScrubEnded(_ newProgress: Double) {
        previewScrub(at: newProgress)
        commitScrub(at: newProgress)
        isScrubbing = false
    }

    private func previewScrub(at newProgress: Double) {
        progress = max(0, min(1, newProgress))
    }

    private func commitScrub(at newProgress: Double) {
        seek(to: newProgress)
    }

    private func seek(to newProgress: Double) {
        let clamped = max(0, min(1, newProgress))
        progress = clamped
        if let voicePlayer {
            let duration = voicePlayer.duration
            guard duration > 0 else { return }
            voicePlayer.currentTime = duration * clamped
            displayedDuration = duration
        } else if let player {
            let duration = player.currentItem?.duration.seconds ?? 0
            guard duration.isFinite, duration > 0 else { return }
            let target = CMTime(seconds: duration * clamped, preferredTimescale: 600)
            player.seek(to: target)
            displayedDuration = duration
        }
    }

    private func startVoiceProgressMonitoring() {
        guard let voicePlayer else { return }

        voiceProgressTimer?.invalidate()
        voiceProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            if let voicePlayer = self.voicePlayer, voicePlayer.isPlaying {
                let duration = voicePlayer.duration
                guard duration > 0 else { return }
                if !self.isScrubbing {
                    self.progress = voicePlayer.currentTime / duration
                }
                self.displayedDuration = duration
            } else {
                timer.invalidate()
                self.voiceProgressTimer = nil
            }
        }
        if let timer = voiceProgressTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func transcribeTapped() {
        transcriptionTask?.cancel()
        transcriptionError = nil
        transcription = nil

        transcriptionTask = Task {
            await transcribeVoiceMessage()
            await MainActor.run {
                transcriptionTask = nil
            }
        }
    }

    @MainActor
    private func transcribeVoiceMessage() async {
        guard isVoiceMessage else { return }
        isTranscribing = true
        defer { isTranscribing = false }

        let status = await requestSpeechAuthorization()
        guard status == .authorized else {
            transcriptionError = "Microphone transcription permission denied."
            return
        }

        let localURL = await withCheckedContinuation { continuation in
            prepareVoiceFile { url in
                continuation.resume(returning: url)
            }
        }

        guard let localURL else {
            transcriptionError = "Unable to prepare audio for transcription."
            return
        }

        do {
            let locale = selectedLocale()
#if canImport(TranscriptionKit)
            if #available(iOS 18.0, *), let tkResult = try await transcribeWithTranscriptionKit(url: localURL, locale: locale) {
                transcription = tkResult
                return
            }
#endif
            let result = try await performSpeechRecognition(for: localURL, locale: locale)
            if let text = result {
                transcription = text
            } else {
                transcriptionError = "No transcription available."
            }
        } catch {
            transcriptionError = error.localizedDescription
        }
    }

    private func performSpeechRecognition(for url: URL, locale: Locale) async throws -> String? {
        let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()

        guard let recognizer else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func selectedLocale() -> Locale {
        let trimmed = transcriptionLanguageSetting.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "auto":
            return Locale.autoupdatingCurrent
        case "device":
            return Locale.current
        default:
            return Locale(identifier: trimmed)
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func teardown() {
        voiceProgressTimer?.invalidate()
        voiceProgressTimer = nil
        stopVoicePlayback()
        player?.pause()
        removeTimeObserver()
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        transcriptionTask?.cancel()
        transcriptionTask = nil
        if let processedVoiceURL, processedVoiceURL.isFileURL, processedVoiceURL != url, fileManager.fileExists(atPath: processedVoiceURL.path) {
            try? fileManager.removeItem(at: processedVoiceURL)
        }
        if let downloadedVoiceURL, downloadedVoiceURL != processedVoiceURL, downloadedVoiceURL.isFileURL, downloadedVoiceURL != url, fileManager.fileExists(atPath: downloadedVoiceURL.path) {
            try? fileManager.removeItem(at: downloadedVoiceURL)
        }
        downloadedVoiceURL = nil
        processedVoiceURL = nil
    }

    private static func decodeWaveform(from base64: String?) -> [CGFloat] {
        guard let base64, let data = Data(base64Encoded: base64) else { return [] }
        return data.map { CGFloat($0) / 255.0 }
    }

    private static func placeholderWaveform(count: Int = 32) -> [CGFloat] {
        guard count > 0 else { return [] }
        var value: CGFloat = 0.45
        return (0..<count).map { _ in
            value = max(0.15, min(0.95, value + CGFloat.random(in: -0.2...0.2)))
            return value
        }
    }

#if canImport(TranscriptionKit)
    @available(iOS 18.0, *)
    private func transcribeWithTranscriptionKit(url: URL, locale: Locale) async throws -> String? {
        let session = TranscriptionSession(locale: locale)
        let request = TranscriptionRequest(audioURL: url)
        let result = try await session.transcribe(request)
        return result.bestTranscription.formattedString
    }
#endif
}

private final class VoicePlaybackDelegator: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

enum TranscriptionError: Error {
    case recognizerUnavailable
}
