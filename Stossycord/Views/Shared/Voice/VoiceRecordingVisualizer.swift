//
//  VoiceRecordingVisualizer.swift
//  Stossycord
//
//  Created by Alex Badi on 15/10/2025.
//

import SwiftUI

struct VoiceRecordingVisualizer: View {
    let samples: [CGFloat]
    let duration: TimeInterval

    private var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 60 ? [.minute, .second] : [.second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? String(format: "%.1f", duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let trimmedSamples = Array(samples.suffix(30))
                let availableWidth = max(proxy.size.width, 1)
                let availableHeight = max(proxy.size.height, 1)
                let sampleCount = max(trimmedSamples.count, 1)
                let spacing = max(2, availableWidth / CGFloat(sampleCount * 14))
                let barWidth = max(2, min(6, (availableWidth - CGFloat(sampleCount - 1) * spacing) / CGFloat(sampleCount)))

                HStack(alignment: .bottom, spacing: spacing) {
                    Spacer(minLength: 0)
                    ForEach(Array(trimmedSamples.enumerated()).reversed(), id: \.offset) { pair in
                        let value = max(0.1, pair.element)
                        Capsule()
                            .fill(Color.blue.opacity(0.9))
                            .frame(
                                width: barWidth,
                                height: max(availableHeight * 0.18, value * availableHeight)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .animation(.easeOut(duration: 0.1), value: trimmedSamples)
            }
            .frame(height: 44)

            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Recording \(formattedDuration)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 76)
    }
}

#Preview {
    VoiceRecordingVisualizer(
        samples: Array(repeating: 0.5, count: 32),
        duration: 12.4
    )
    .padding()
    .background(Color.black.opacity(0.4))
}
