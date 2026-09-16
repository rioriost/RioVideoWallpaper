//
//  RenderClock.swift
//  RioVideoWallpaper
//

import Foundation

struct RenderClock: Equatable {
    let fps: Int
    let loopSeconds: Double
    let wrapsTime: Bool
    let frameOffset: Double

    init(fps: Int, loopSeconds: Double, wrapsTime: Bool = true, frameOffset: Double = 0) {
        self.fps = min(ExportSettings.maximumFPS, max(1, fps))
        self.loopSeconds = loopSeconds.isFinite
            ? min(ExportSettings.maximumLoopSeconds, max(0.1, loopSeconds))
            : ExportSettings.minimumLoopSeconds
        self.wrapsTime = wrapsTime
        self.frameOffset = frameOffset.isFinite ? frameOffset : 0
    }

    var totalFrames: Int {
        max(1, Int((Double(fps) * loopSeconds).rounded()))
    }

    func normalizedLoopTime(frameIndex: Int) -> Double {
        let frame = wrapsTime ? wrappedFrameIndex(frameIndex) : frameIndex
        return (Double(frame) + frameOffset) / Double(totalFrames)
    }

    func phase(frameIndex: Int) -> Double {
        Double.pi * 2.0 * normalizedLoopTime(frameIndex: frameIndex)
    }

    func wrappedFrameIndex(_ frameIndex: Int) -> Int {
        let total = totalFrames
        let remainder = frameIndex % total
        return remainder >= 0 ? remainder : remainder + total
    }

    func exportFrameIndices() -> Range<Int> {
        0..<totalFrames
    }

    func warmupFrameIndices(warmupLoops: Int) -> Range<Int> {
        let warmupFrames = min(ExportSettings.maximumWarmupLoops, max(0, warmupLoops)) * totalFrames
        return -warmupFrames..<0
    }

    var durationSeconds: Double {
        Double(totalFrames) / Double(fps)
    }
}
