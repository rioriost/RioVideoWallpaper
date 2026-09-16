import Foundation

enum ExportFileTransaction {
    static func write(
        to outputURL: URL,
        operation: (URL) async throws -> Void
    ) async throws -> URL {
        try Task.checkCancellation()
        let stagingURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent(".\(outputURL.lastPathComponent).\(UUID().uuidString).partial.mp4")
        defer { try? FileManager.default.removeItem(at: stagingURL) }
        try await operation(stagingURL)
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath: outputURL.path) {
            _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: stagingURL)
        } else {
            try FileManager.default.moveItem(at: stagingURL, to: outputURL)
        }
        return outputURL
    }
}
