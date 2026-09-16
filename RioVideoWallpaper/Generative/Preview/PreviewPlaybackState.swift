import Foundation

struct PreviewSeekRequest: Equatable {
    let id: UUID
    let frameIndex: Int

    init(frameIndex: Int, id: UUID = UUID()) {
        self.id = id
        self.frameIndex = frameIndex
    }
}

struct PreviewPlaybackState {
    private var isPlaying = true
    private var isSuspended = false
    private var frameOffset = 0
    private var startTime = 0.0
    private var appliedSeekID: UUID?

    func frame(at time: Double, clock: RenderClock) -> Int {
        guard isPlaying, !isSuspended else { return frameOffset }
        let elapsed = max(0, time - startTime) * Double(clock.fps)
        guard elapsed.isFinite, elapsed < Double(Int.max - frameOffset - 1) else {
            return frameOffset
        }
        return frameOffset + Int(elapsed.rounded(.down))
    }

    mutating func reset(at time: Double) {
        frameOffset = 0
        startTime = time
    }

    mutating func rebase(at time: Double, clock: RenderClock) {
        frameOffset = clock.wrappedFrameIndex(frame(at: time, clock: clock))
        startTime = time
    }

    mutating func setPlaying(_ playing: Bool, at time: Double, clock: RenderClock) {
        guard isPlaying != playing else { return }
        frameOffset = frame(at: time, clock: clock)
        startTime = time
        isPlaying = playing
    }

    mutating func setSuspended(_ suspended: Bool, at time: Double, clock: RenderClock) {
        guard isSuspended != suspended else { return }
        frameOffset = frame(at: time, clock: clock)
        startTime = time
        isSuspended = suspended
    }

    @discardableResult
    mutating func apply(_ request: PreviewSeekRequest?, at time: Double, clock: RenderClock) -> Bool {
        guard let request, request.id != appliedSeekID else { return false }
        appliedSeekID = request.id
        frameOffset = clock.wrappedFrameIndex(request.frameIndex)
        startTime = time
        return true
    }
}

final class PreviewRenderJob: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func checkCancellation() throws {
        lock.lock()
        let isCancelled = cancelled
        lock.unlock()
        if isCancelled { throw CancellationError() }
    }
}
