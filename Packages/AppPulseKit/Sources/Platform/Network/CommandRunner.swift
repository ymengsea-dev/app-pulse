import Foundation

/// Runs a short-lived command and returns its output, stopping it if it runs too long.
struct CommandRunner: Sendable {
    func run(_ path: String, arguments: [String], timeoutSeconds: Double) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                nonisolated(unsafe) let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
                    if process.isRunning { process.terminate() }
                }

                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    continuation.resume(returning: String(decoding: data, as: UTF8.self))
                } else {
                    continuation.resume(throwing: PlatformError.commandFailed(status: process.terminationStatus))
                }
            }
        }
    }
}
