import AVFoundation
import Foundation

protocol ExportWriterState: AnyObject {
    var status: AVAssetWriter.Status { get }
    var error: Error? { get }
}

extension AVAssetWriter: ExportWriterState {}

enum ExportWriterWait {
    static func untilReady(
        writer: ExportWriterState,
        isReady: () -> Bool,
        checkCancellation: () throws -> Void = { try Task.checkCancellation() },
        wait: () -> Void = { Thread.sleep(forTimeInterval: 0.01) }
    ) throws {
        while true {
            try checkCancellation()
            guard writer.status == .writing else { throw ExportError.writerFailed(writer.error) }
            if isReady() { return }
            wait()
        }
    }

    static func finish(
        writer: ExportWriterState,
        start: (@escaping @Sendable () -> Void) -> Void,
        checkCancellation: () throws -> Void = { try Task.checkCancellation() }
    ) throws {
        try checkCancellation()
        let completion = DispatchSemaphore(value: 0)
        start { completion.signal() }
        while completion.wait(timeout: .now() + 0.01) == .timedOut {
            try checkCancellation()
            if writer.status == .failed || writer.status == .cancelled {
                throw ExportError.writerFailed(writer.error)
            }
        }
        try checkCancellation()
        guard writer.status == .completed else { throw ExportError.writerFailed(writer.error) }
    }
}
