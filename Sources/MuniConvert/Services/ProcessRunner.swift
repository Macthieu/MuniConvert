// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct ProcessResult {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

final class ProcessRunner {
    private let stateQueue = DispatchQueue(label: "com.municonvert.process-runner")
    private var activeProcess: Process?

    func run(executableURL: URL, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stateQueue.sync {
            activeProcess = process
        }

        do {
            try process.run()
        } catch {
            clearActiveProcess()
            throw MuniConvertError.processLaunchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        clearActiveProcess()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ProcessResult(
            terminationStatus: process.terminationStatus,
            standardOutput: stdout,
            standardError: stderr
        )
    }

    func terminateRunningProcess() {
        stateQueue.sync {
            guard let process = activeProcess else {
                return
            }
            if process.isRunning {
                process.terminate()
            }
        }
    }

    private func clearActiveProcess() {
        stateQueue.sync {
            activeProcess = nil
        }
    }
}
