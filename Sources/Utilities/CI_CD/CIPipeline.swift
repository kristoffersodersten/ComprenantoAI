import Foundation

enum PipelineError: Error {
    case processError(String)
    case executionError(Int32)
    case outputError(String)
}

@available(macOS 10.15.4, *)
actor CIPipeline {
    
    func setupPipeline() async throws {
        let actions = ["build", "test", "deploy"]
        
        for action in actions {
            do {
                let result = try await runFastlaneAction(action)
                if result != 0 {
                    throw PipelineError.executionError(result)
                }
            } catch {
                await handleFailure(for: action, with: error)
                throw error
            }
        }
        
        print("✅ CI/CD pipeline completed successfully!")
    }

    private func runFastlaneAction(_ action: String) async throws -> Int32 {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        // FIXED: Replaced `URL(string:)` with `URL(fileURLWithPath:)`
        let executablePath = "/usr/bin/env"
        let executableURL = URL(fileURLWithPath: executablePath)
        
        task.executableURL = executableURL
        task.arguments = ["fastlane", action]
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading

            task.terminationHandler = { process in
                do {
                    try outputHandle.close()
                    try errorHandle.close()
                } catch {
                    continuation.resume(throwing: PipelineError.outputError(
                        "Failed to close pipes: \(error.localizedDescription)"
                    ))
                    return
                }

                if process.terminationStatus == 0 {
                    continuation.resume(returning: process.terminationStatus)
                } else {
                    continuation.resume(throwing: PipelineError.executionError(process.terminationStatus))
                }
            }

            do {
                try task.run()

                // FIXED: Ensure async tasks are correctly awaited
                Task.detached { [weak self] in
                    do {
                        try await self?.handleOutput(handle: outputHandle, prefix: "📤 Output")
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                Task.detached { [weak self] in
                    do {
                        try await self?.handleOutput(handle: errorHandle, prefix: "🚨 Error")
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: PipelineError.processError(
                    "❌ Failed to run task: \(error.localizedDescription)"
                ))
            }
        }
    }

    // FIXED: Ensure compatibility with Swift versions
    private func handleOutput(handle: FileHandle, prefix: String) async throws {
        for try await line in handle.bytes.lines {
            await MainActor.run { print("\(prefix): \(line)") }
        }
    }

    private func handleFailure(for action: String, with error: Error) {
        let message: String
        if case PipelineError.executionError(let code) = error {
            message = "🚨 \(action.capitalized) failed with exit code \(code)!"
        } else {
            message = "❌ \(action.capitalized) failed with error: \(error.localizedDescription)"
        }
        print(message)
    }
}
