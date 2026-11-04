import Foundation

enum EngineClientError: LocalizedError {
    case helperMissing
    case invalidResponse(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperMissing:
            return "Amnesia helper를 찾을 수 없습니다. 앱을 다시 빌드해 주세요."
        case .invalidResponse(let detail):
            return "엔진 응답을 읽을 수 없습니다. \(detail)"
        case .launchFailed(let detail):
            return "엔진을 실행할 수 없습니다. \(detail)"
        }
    }
}

struct EngineClient {
    private let decoder = JSONDecoder()

    func state() async throws -> BridgeState {
        try await run(command: "state", payload: [:], as: BridgeState.self)
    }

    func action(command: String, payload: [String: Any]) async throws -> ActionResult {
        try await run(command: command, payload: payload, as: ActionResult.self)
    }

    private func helperURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["AMNESIA_HELPER"],
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        if let bundled = Bundle.main.url(forResource: "amnesia-helper", withExtension: nil) {
            return bundled
        }
        throw EngineClientError.helperMissing
    }

    private func run<T: Decodable>(
        command: String,
        payload: [String: Any],
        as type: T.Type
    ) async throws -> T {
        let executable = try helperURL()
        let input = try JSONSerialization.data(withJSONObject: payload)

        return try await Task.detached(priority: .userInitiated) {
            try runSynchronously(
                executable: executable,
                command: command,
                input: input,
                decoder: decoder,
                as: type
            )
        }.value
    }

    private func runSynchronously<T: Decodable>(
        executable: URL,
        command: String,
        input: Data,
        decoder: JSONDecoder,
        as type: T.Type
    ) throws -> T {
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("amnesia-bridge-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: temporary,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: temporary) }
            let outputURL = temporary.appendingPathComponent("stdout.json")
            let errorURL = temporary.appendingPathComponent("stderr.txt")
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            FileManager.default.createFile(atPath: errorURL.path, contents: nil)
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)
            defer {
                try? outputHandle.close()
                try? errorHandle.close()
            }

            let process = Process()
            let inputPipe = Pipe()
            process.executableURL = executable
            process.arguments = [command]
            process.standardOutput = outputHandle
            process.standardError = errorHandle
            process.standardInput = inputPipe

            do {
                try process.run()
            } catch {
                throw EngineClientError.launchFailed(error.localizedDescription)
            }

            inputPipe.fileHandleForWriting.write(input)
            try? inputPipe.fileHandleForWriting.close()

            process.waitUntilExit()
            try? outputHandle.close()
            try? errorHandle.close()
            let output = try Data(contentsOf: outputURL)
            let errorOutput = try Data(contentsOf: errorURL)

            do {
                return try decoder.decode(type, from: output)
            } catch {
                let stderr = String(data: errorOutput, encoding: .utf8) ?? ""
                let stdout = String(data: output.prefix(2_000), encoding: .utf8) ?? ""
                throw EngineClientError.invalidResponse(
                    [stderr, stdout, error.localizedDescription]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                )
            }
    }
}
