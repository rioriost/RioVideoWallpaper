//
//  ExportedVideoValidator.swift
//  RioVideoWallpaper
//

import AVFoundation
import Foundation

struct ExportedVideoSummary: Equatable {
    var width: Int
    var height: Int
    var durationSeconds: Double
    var frameCount: Int
    var nominalFrameRate: Float
}

enum ExportedVideoValidator {
    static func validate(url: URL, expected settings: ExportSettings) async throws -> ExportedVideoSummary {
        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExportedVideoValidationError.missingFile
        }

        let normalizedSettings = try settings.validatedForExport()
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        try Task.checkCancellation()

        guard let videoTrack = tracks.first else {
            throw ExportedVideoValidationError.missingVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let durationSeconds = duration.seconds
        let actualWidth = Int(naturalSize.width.rounded())
        let actualHeight = Int(naturalSize.height.rounded())

        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ExportedVideoValidationError.nonPositiveDuration(durationSeconds)
        }

        guard actualWidth == normalizedSettings.width, actualHeight == normalizedSettings.height else {
            throw ExportedVideoValidationError.unexpectedDimensions(
                expectedWidth: normalizedSettings.width,
                expectedHeight: normalizedSettings.height,
                actualWidth: actualWidth,
                actualHeight: actualHeight
            )
        }

        let clock = RenderClock(fps: normalizedSettings.fps, loopSeconds: normalizedSettings.loopSeconds)
        let expectedDuration = clock.durationSeconds
        let durationTolerance = max(0.02, 0.5 / Double(normalizedSettings.fps))
        guard abs(durationSeconds - expectedDuration) <= durationTolerance else {
            throw ExportedVideoValidationError.unexpectedDuration(
                expectedSeconds: expectedDuration,
                actualSeconds: durationSeconds
            )
        }

        let frameCount = try await countVideoSamples(url: url, clock: clock)
        let expectedFrameCount = clock.totalFrames
        guard frameCount == expectedFrameCount else {
            throw ExportedVideoValidationError.unexpectedFrameCount(
                expected: expectedFrameCount,
                actual: frameCount
            )
        }

        try Task.checkCancellation()
        return ExportedVideoSummary(
            width: actualWidth,
            height: actualHeight,
            durationSeconds: durationSeconds,
            frameCount: frameCount,
            nominalFrameRate: nominalFrameRate
        )
    }

    private static func countVideoSamples(url: URL, clock: RenderClock) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw ExportedVideoValidationError.missingVideoTrack
        }

        let reader = try AVAssetReader(asset: asset)
        defer {
            if reader.status == .reading { reader.cancelReading() }
        }
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw ExportedVideoValidationError.sampleReaderFailed(nil)
        }
        reader.add(output)

        guard reader.startReading() else {
            throw ExportedVideoValidationError.sampleReaderFailed(reader.error)
        }

        var frameCount = 0
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            // AVAssetReader also emits zero-sample control buffers; those are not video frames.
            for sample in 0..<CMSampleBufferGetNumSamples(buffer) {
                var timing = CMSampleTimingInfo()
                let status = CMSampleBufferGetSampleTimingInfo(buffer, at: sample, timingInfoOut: &timing)
                let actualTime = timing.presentationTimeStamp.seconds
                let expectedTime = Double(frameCount) / Double(clock.fps)
                guard status == noErr, actualTime.isFinite, abs(actualTime - expectedTime) < 0.002 else {
                    throw ExportedVideoValidationError.unexpectedFrameTiming(
                        expectedSeconds: expectedTime, actualSeconds: actualTime
                    )
                }
                frameCount += 1
            }
        }

        if reader.status == .failed || reader.status == .cancelled {
            throw ExportedVideoValidationError.sampleReaderFailed(reader.error)
        }

        return frameCount
    }
}

enum ExportedVideoValidationError: LocalizedError {
    case missingFile
    case missingVideoTrack
    case nonPositiveDuration(Double)
    case unexpectedDimensions(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
    case unexpectedDuration(expectedSeconds: Double, actualSeconds: Double)
    case unexpectedFrameCount(expected: Int, actual: Int)
    case unexpectedFrameTiming(expectedSeconds: Double, actualSeconds: Double)
    case sampleReaderFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "The exported video file was not created."
        case .missingVideoTrack:
            return "The exported file does not contain a video track."
        case .nonPositiveDuration(let duration):
            return "The exported video has an invalid duration: \(duration) seconds."
        case .unexpectedDimensions(let expectedWidth, let expectedHeight, let actualWidth, let actualHeight):
            return "The exported video is \(actualWidth) x \(actualHeight), expected \(expectedWidth) x \(expectedHeight)."
        case .unexpectedDuration(let expectedSeconds, let actualSeconds):
            return "The exported video duration is \(actualSeconds) seconds, expected \(expectedSeconds) seconds."
        case .unexpectedFrameCount(let expected, let actual):
            return "The exported video contains \(actual) frames, expected \(expected) frames."
        case .unexpectedFrameTiming(let expected, let actual):
            return "The exported video frame is timed at \(actual) seconds, expected \(expected) seconds."
        case .sampleReaderFailed(let error):
            return error?.localizedDescription ?? "The exported video samples could not be read."
        }
    }
}
