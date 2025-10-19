//
//  VoiceRecordingManager.swift
//  Stossycord
//
//  Created by Alex Badi on 15/10/2025.
//

import Foundation
import AVFoundation
import CoreGraphics
import SwiftUI

@MainActor
final class VoiceRecordingManager: NSObject, ObservableObject {
    enum RecordingState: Equatable {
        case idle
        case preparing
        case recording
        case finishing
        case failed(VoiceRecordingError)
    }

    enum VoiceRecordingError: Error, Equatable {
        case permissionDenied
        case configurationFailed
        case recordingFailed
        case encodingFailed
    }

    struct Clip {
        let fileURL: URL
        let filename: String
        let duration: TimeInterval
        let waveform: Data

        var fileSize: Int {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                return size
            }
            return (try? Data(contentsOf: fileURL).count) ?? 0
        }

        var base64Waveform: String {
            waveform.base64EncodedString()
        }

        var roundedDuration: Double {
            max(0.3, (duration * 10).rounded() / 10)
        }

        var mimeType: String {
            switch fileURL.pathExtension.lowercased() {
            case "ogg":
                return "audio/ogg"
            case "m4a", "mp4":
                return "audio/mp4"
            case "caf":
                return "audio/x-caf"
            case "wav":
                return "audio/wav"
            default:
                return "application/octet-stream"
            }
        }
    }

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var displaySamples: [CGFloat] = Array(repeating: 0.2, count: Constants.visualSampleCount)

    private enum Constants {
        static let visualSampleCount = 30
        static let waveformSampleCount = 256
        static let meterInterval: TimeInterval = 0.05
        static let minimumDuration: TimeInterval = 0.3
        static let baseFilename = "voice-message"
    }

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var recordedSamples: [CGFloat] = []
    private var recordingURL: URL?
    @AppStorage("voiceMessageUseFakeWaveform") private var voiceMessageUseFakeWaveform = false

    func beginRecording() async throws {
        guard state != .recording else { return }
        state = .preparing

        guard try await requestPermission() else {
            state = .failed(.permissionDenied)
            throw VoiceRecordingError.permissionDenied
        }

        do {
            try configureAudioSession()
            try prepareRecorder()
            try startRecorder()
            startMetering()
            state = .recording
        } catch {
            cleanupAfterFailure()
            state = .failed(.configurationFailed)
            throw VoiceRecordingError.configurationFailed
        }
    }

    func finishRecording() async throws -> Clip? {
        guard state == .recording else { return nil }
        state = .finishing

        stopMetering()
        let finalDuration = recorder?.currentTime ?? duration
        recorder?.stop()
        recorder = nil
        deactivateAudioSession()

        guard let currentRecordingURL = recordingURL else {
            cleanupAfterFailure()
            state = .failed(.recordingFailed)
            throw VoiceRecordingError.recordingFailed
        }

        duration = max(duration, finalDuration)

        if duration < Constants.minimumDuration {
            cleanupFiles()
            state = .idle
            return nil
        }

        recordedSamples = Array(recordedSamples.suffix(Constants.waveformSampleCount))
        let waveformSamples = voiceMessageUseFakeWaveform ? Self.fakeWaveform(count: Constants.waveformSampleCount) : recordedSamples
        let waveformData = Self.waveformData(from: waveformSamples, targetCount: Constants.waveformSampleCount)

        let clip = Clip(
            fileURL: currentRecordingURL,
            filename: currentRecordingURL.lastPathComponent,
            duration: duration,
            waveform: waveformData
        )

        self.recordingURL = nil
        resetState()
        return clip
    }

    func cancelRecording() {
        stopMetering()
        recorder?.stop()
        recorder = nil
        deactivateAudioSession()
        cleanupFiles()
        resetState()
    }

    private func requestPermission() async throws -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return try await withCheckedThrowingContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func prepareRecorder() throws {
        let baseFilename = Self.makeFilename()
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let recordingURL = temporaryDirectory.appendingPathComponent("\(baseFilename).m4a")
        self.recordingURL = recordingURL

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        duration = 0
        recordedSamples.removeAll()
        displaySamples = Array(repeating: 0.2, count: Constants.visualSampleCount)
    }

    private func startRecorder() throws {
        guard recorder?.record() == true else {
            throw VoiceRecordingError.recordingFailed
        }
    }

    private func startMetering() {
        stopMetering()
        levelTimer = Timer.scheduledTimer(withTimeInterval: Constants.meterInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMeter()
            }
        }
        if let levelTimer {
            RunLoop.main.add(levelTimer, forMode: .common)
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateMeter() {
        guard let recorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let normalizedPower = Self.normalize(power: power)
        recordedSamples.append(normalizedPower)
        if recordedSamples.count > Constants.waveformSampleCount {
            recordedSamples.removeFirst(recordedSamples.count - Constants.waveformSampleCount)
        }
        duration = recorder.currentTime
        displaySamples = Self.reduce(samples: recordedSamples, to: Constants.visualSampleCount)
    }

    private func cleanupAfterFailure() {
        cleanupFiles()
        resetState()
    }

    private func cleanupFiles() {
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
    }

    private func resetState() {
        recorder = nil
        levelTimer?.invalidate()
        levelTimer = nil
        state = .idle
        duration = 0
        recordedSamples.removeAll()
        displaySamples = Array(repeating: 0.2, count: Constants.visualSampleCount)
        recordingURL = nil
    }

    private static func normalize(power: Float) -> CGFloat {
        let minDb: Float = -60
        let clampedPower = max(power, minDb)
        let range = minDb * -1
        let adjusted = 1 - ((clampedPower - minDb) / range)
        let linear = 1 - adjusted
        return CGFloat(max(0, min(1, linear)))
    }

    private static func reduce(samples: [CGFloat], to count: Int) -> [CGFloat] {
        guard !samples.isEmpty else {
            return Array(repeating: 0.15, count: count)
        }
        if samples.count <= count {
            let padding = Array(repeating: samples.last ?? 0.15, count: count - samples.count)
            return samples + padding
        }
        let stride = Double(samples.count) / Double(count)
        return (0..<count).map { index in
            let start = Int((Double(index) * stride).rounded(.down))
            let end = Int((Double(index + 1) * stride).rounded(.down))
            let clampedStart = max(0, start)
            let clampedEnd = max(clampedStart + 1, min(samples.count, end))
            let slice = samples[clampedStart..<clampedEnd]
            let average = slice.reduce(0, +) / CGFloat(slice.count)
            return average
        }
    }

    private static func waveformData(from samples: [CGFloat], targetCount: Int) -> Data {
        let reduced = reduce(samples: samples, to: targetCount)
        let bytes = reduced.map { sample -> UInt8 in
            let clamped = max(0, min(1, sample))
            return UInt8((clamped * 255).rounded())
        }
        return Data(bytes)
    }

    private static func fakeWaveform(count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        var samples: [CGFloat] = []
        var current: CGFloat = 0.45
        for _ in 0..<count {
            let delta = CGFloat.random(in: -0.25...0.25)
            current = max(0.12, min(0.95, current + delta))
            samples.append(current)
        }
        return samples
    }

    private static func makeFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let date = formatter.string(from: Date())
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        let time = timeFormatter.string(from: Date())
        return "\(Constants.baseFilename)-\(date)-\(time)"
    }
}

extension VoiceRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        cancelRecording()
        state = .failed(.recordingFailed)
    }
}
