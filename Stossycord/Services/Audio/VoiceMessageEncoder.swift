//
//  VoiceMessageEncoder.swift
//  Stossycord
//
//  Created by Alex Badi on 15/10/2025.
//

import Foundation
import AVFoundation
import AudioToolbox

private let oggOpusFileType: AudioFileTypeID = FourCharCode("opus")

private func FourCharCode(_ code: String) -> AudioFileTypeID {
    var result: UInt32 = 0
    for scalar in code.utf16 {
        result = (result << 8) | UInt32(scalar)
    }
    return result
}

enum VoiceMessageEncoder {
    enum EncodingError: Error {
        case failedToOpenSource
        case failedToCreateDestination
        case readError(OSStatus)
        case writeError(OSStatus)
        case propertyError(OSStatus)
        case bufferCreationFailed
    }

    static func encodePCMToOpusOgg(inputURL: URL, outputURL: URL) throws {
        try? FileManager.default.removeItem(at: outputURL)

        var sourceFile: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(inputURL as CFURL, &sourceFile)
        guard status == noErr, let sourceFile else { throw EncodingError.failedToOpenSource }
        defer { ExtAudioFileDispose(sourceFile) }

        var sourceFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &sourceFormat)
        guard status == noErr else { throw EncodingError.propertyError(status) }

        let preferredSampleRate: Double = 48_000
        let channelCount = max<UInt32>(1, sourceFormat.mChannelsPerFrame)

        guard let pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: preferredSampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            throw EncodingError.bufferCreationFailed
        }

        var clientFormat = pcmFormat.streamDescription.pointee
        clientFormat.mSampleRate = preferredSampleRate

        var clientFormatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, clientFormatSize, &clientFormat)
        guard status == noErr else { throw EncodingError.propertyError(status) }

        var destinationFile: ExtAudioFileRef?
        var destinationFormat = AudioStreamBasicDescription(
            mSampleRate: preferredSampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 960,
            mBytesPerFrame: 0,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 0,
            mReserved: 0
        )

        status = ExtAudioFileCreateWithURL(
            outputURL as CFURL,
            oggOpusFileType,
            &destinationFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &destinationFile
        )
        guard status == noErr, let destinationFile else { throw EncodingError.failedToCreateDestination }
        defer { ExtAudioFileDispose(destinationFile) }

        status = ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, clientFormatSize, &clientFormat)
        guard status == noErr else { throw EncodingError.propertyError(status) }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 4_096) else {
            throw EncodingError.bufferCreationFailed
        }

        while true {
            buffer.frameLength = buffer.frameCapacity
            var frameCount = buffer.frameLength
            status = ExtAudioFileRead(sourceFile, &frameCount, buffer.mutableAudioBufferList)
            guard status == noErr else { throw EncodingError.readError(status) }
            if frameCount == 0 { break }
            buffer.frameLength = frameCount
            status = ExtAudioFileWrite(destinationFile, frameCount, buffer.mutableAudioBufferList)
            guard status == noErr else { throw EncodingError.writeError(status) }
        }
    }
}
