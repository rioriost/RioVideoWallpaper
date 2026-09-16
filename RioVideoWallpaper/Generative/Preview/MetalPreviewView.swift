//
//  MetalPreviewView.swift
//  RioVideoWallpaper
//

import MetalKit
import QuartzCore
import SwiftUI

struct MetalPreviewView: NSViewRepresentable {
    var clearColor: MTLClearColor
    var parameters: RenderParameters
    var seed: UInt64
    var exportSettings: ExportSettings
    var isPlaying: Bool
    var seekRequest: PreviewSeekRequest?

    init(
        parameters: RenderParameters,
        seed: UInt64,
        exportSettings: ExportSettings,
        isPlaying: Bool = true,
        seekRequest: PreviewSeekRequest? = nil,
        clearColor: MTLClearColor = GenerativeRenderStyle.backgroundColor
    ) {
        self.parameters = parameters
        self.seed = seed
        self.exportSettings = exportSettings
        self.isPlaying = isPlaying
        self.seekRequest = seekRequest
        self.clearColor = clearColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.clearColor = clearColor
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        context.coordinator.update(
            parameters: parameters,
            seed: seed,
            exportSettings: exportSettings,
            isPlaying: isPlaying,
            seekRequest: seekRequest
        )
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        view.clearColor = clearColor
        context.coordinator.attach(to: view)
        context.coordinator.update(
            parameters: parameters,
            seed: seed,
            exportSettings: exportSettings,
            isPlaying: isPlaying,
            seekRequest: seekRequest
        )
    }

    static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
        view.isPaused = true
        view.delegate = nil
        coordinator.detach()
    }
}

extension MetalPreviewView {
    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private let worker: PreviewRenderWorker?
        private let renderingQueue = DispatchQueue(label: "RioVideoWallpaper.preview", qos: .userInitiated)
        private var renderingJob: PreviewRenderJob?
        private var renderRevision = 0
        private var parameters = RenderParameters.fieldLines(.feasibilityStudyDefault)
        private var seed: UInt64 = 1
        private var exportSettings = ExportSettings.standard
        private var isPlaying = true
        private var playback = PreviewPlaybackState()
        private weak var view: MTKView?
        private weak var observedWindow: NSWindow?
        private var windowObservers: [NSObjectProtocol] = []

        override init() {
            device = MTLCreateSystemDefaultDevice()
            commandQueue = device?.makeCommandQueue()
            if let device, let commandQueue {
                worker = PreviewRenderWorker(device: device, commandQueue: commandQueue)
            } else {
                worker = nil
            }
            super.init()
            playback.reset(at: CACurrentMediaTime())
        }

        deinit {
            renderingJob?.cancel()
            removeWindowObservers()
        }

        func attach(to view: MTKView) {
            self.view = view
            refreshWindowObserversIfNeeded()
            updatePausedState(redrawPausedFrame: false)
        }

        func detach() {
            invalidateRendering()
            renderingJob = nil
            view = nil
            observedWindow = nil
            removeWindowObservers()
        }

        func update(
            parameters: RenderParameters,
            seed: UInt64,
            exportSettings: ExportSettings,
            isPlaying: Bool,
            seekRequest: PreviewSeekRequest?
        ) {
            let now = CACurrentMediaTime()
            if seed != self.seed ||
                parameters != self.parameters ||
                exportSettings.fps != self.exportSettings.fps ||
                exportSettings.loopSeconds != self.exportSettings.loopSeconds ||
                exportSettings.warmupLoops != self.exportSettings.warmupLoops {
                invalidateRendering()
                playback.reset(at: now)
            }
            self.parameters = parameters
            self.seed = seed
            self.exportSettings = exportSettings
            self.isPlaying = isPlaying
            let clock = RenderClock(fps: exportSettings.fps, loopSeconds: exportSettings.loopSeconds)
            playback.setPlaying(isPlaying, at: now, clock: clock)
            if playback.apply(seekRequest, at: now, clock: clock) {
                invalidateRendering()
            }
            updatePausedState(redrawPausedFrame: true)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            guard Thread.isMainThread else {
                DispatchQueue.main.async { [weak self, weak view] in
                    if let view { self?.mtkView(view, drawableSizeWillChange: size) }
                }
                return
            }
            guard self.view === view else { return }
            let clock = RenderClock(fps: exportSettings.fps, loopSeconds: exportSettings.loopSeconds)
            playback.rebase(at: CACurrentMediaTime(), clock: clock)
            invalidateRendering()
        }

        private func invalidateRendering() {
            renderRevision &+= 1
            renderingJob?.cancel()
        }

        func draw(in view: MTKView) {
            guard Thread.isMainThread else {
                DispatchQueue.main.async { [weak self, weak view] in
                    if let view { self?.draw(in: view) }
                }
                return
            }
            guard self.view === view else { return }
            refreshWindowObserversIfNeeded()
            guard isVisibleForRendering(view) else {
                updatePausedState(redrawPausedFrame: false)
                return
            }

            guard renderingJob == nil, let worker else { return }
            let clock = RenderClock(fps: exportSettings.fps, loopSeconds: exportSettings.loopSeconds)
            let request = PreviewRenderWorker.Request(
                parameters: parameters, seed: seed, settings: exportSettings,
                frameIndex: playback.frame(at: CACurrentMediaTime(), clock: clock),
                size: view.drawableSize, revision: renderRevision
            )
            guard request.size.width >= 2, request.size.height >= 2 else { return }
            let job = PreviewRenderJob()
            renderingJob = job
            renderingQueue.async { [weak self, weak view] in
                let result = Result { try worker.render(request, job: job) }
                DispatchQueue.main.async {
                    guard let self, let view, self.view === view, self.renderingJob === job else { return }
                    self.renderingJob = nil
                    guard request.revision == self.renderRevision else {
                        if self.isVisibleForRendering(view) { view.draw() }
                        return
                    }
                    guard self.isVisibleForRendering(view) else { return }
                    let clock = RenderClock(fps: self.exportSettings.fps, loopSeconds: self.exportSettings.loopSeconds)
                    if !self.isPlaying && request.frameIndex != self.playback.frame(at: CACurrentMediaTime(), clock: clock) {
                        view.draw()
                        return
                    }
                    do {
                        let (renderer, texture) = try result.get()
                        guard let command = self.commandQueue?.makeCommandBuffer(),
                              let pass = view.currentRenderPassDescriptor,
                              let drawable = view.currentDrawable else { return }
                        try renderer.present(texture, descriptor: pass, commandBuffer: command)
                        command.addCompletedHandler { [weak self, weak view] buffer in
                            guard let error = buffer.error else { return }
                            DispatchQueue.main.async {
                                guard let self, let view, self.view === view,
                                      self.renderRevision == request.revision else { return }
                                self.invalidateRendering()
                                view.isPaused = true
                                NSLog("Generative preview presentation failed: %@", error.localizedDescription)
                            }
                        }
                        command.present(drawable)
                        command.commit()
                    } catch {
                        self.invalidateRendering()
                        view.isPaused = true
                        NSLog("Generative preview rendering failed: %@", error.localizedDescription)
                    }
                }
            }
        }

        private final class PreviewRenderWorker {
            // Mutable render state belongs to renderingQueue; presentation precedes the next queued job.
            struct Request {
                var parameters: RenderParameters
                var seed: UInt64
                var settings: ExportSettings
                var frameIndex: Int
                var size: CGSize
                var revision: Int
            }

            private let device: MTLDevice
            private let commandQueue: MTLCommandQueue
            private var renderer: GenerativeRenderSession?
            private var revision: Int?

            init(device: MTLDevice, commandQueue: MTLCommandQueue) {
                self.device = device
                self.commandQueue = commandQueue
            }

            func render(_ request: Request, job: PreviewRenderJob) throws -> (GenerativeRenderSession, MTLTexture) {
                try job.checkCancellation()
                if renderer == nil { renderer = try GenerativeRenderSession(device: device) }
                guard let renderer else { throw RenderEncodingError.textureCreationFailed }
                if revision != request.revision {
                    renderer.reset()
                    revision = request.revision
                }
                let texture = try renderer.render(
                    parameters: request.parameters, seed: request.seed, frameIndex: request.frameIndex,
                    settings: request.settings, drawableSize: request.size, commandQueue: commandQueue,
                    checkCancellation: job.checkCancellation
                )
                return (renderer, texture)
            }
        }

        private func refreshWindowObserversIfNeeded() {
            guard let view, observedWindow !== view.window else {
                return
            }

            removeWindowObservers()
            observedWindow = view.window

            guard let window = view.window else {
                return
            }

            let notificationCenter = NotificationCenter.default
            let notifications: [Notification.Name] = [
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification
            ]

            windowObservers = notifications.map { name in
                notificationCenter.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.updatePausedState(redrawPausedFrame: false)
                }
            }
        }

        private func removeWindowObservers() {
            let notificationCenter = NotificationCenter.default
            for observer in windowObservers {
                notificationCenter.removeObserver(observer)
            }
            windowObservers.removeAll()
        }

        private func updatePausedState(redrawPausedFrame: Bool) {
            guard let view else {
                return
            }

            let shouldRenderContinuously = isPlaying && isVisibleForRendering(view)
            let clock = RenderClock(fps: exportSettings.fps, loopSeconds: exportSettings.loopSeconds)
            playback.setSuspended(!isVisibleForRendering(view), at: CACurrentMediaTime(), clock: clock)
            view.isPaused = !shouldRenderContinuously
            view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60

            if redrawPausedFrame, view.isPaused, isVisibleForRendering(view) {
                view.draw()
            }
        }

        private func isVisibleForRendering(_ view: MTKView) -> Bool {
            guard let window = view.window else {
                return true
            }

            return window.isVisible &&
                !window.isMiniaturized &&
                window.occlusionState.contains(.visible)
        }
    }
}
