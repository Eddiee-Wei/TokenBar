import Darwin
import Foundation

public actor CodexAppServerClient {
    public var executable: String
    public var timeoutSeconds: TimeInterval

    private let clientVersion: String
    private let language: AppLanguage
    private var connection: AppServerConnection?
    private var initializationTask: Task<Void, Error>?
    private var isInitialized = false
    private var nextRequestID = 1
    private var lineBuffer = Data()
    private var stderrBuffer = Data()
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var timeoutTasks: [Int: Task<Void, Never>] = [:]
    private var updateContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    public init(
        executable: String = "codex",
        timeoutSeconds: TimeInterval = 8,
        clientVersion: String? = nil,
        language: AppLanguage = .english
    ) {
        self.executable = executable
        self.timeoutSeconds = timeoutSeconds
        self.language = language
        self.clientVersion = clientVersion
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "development"
    }

    public func readRateLimits() async throws -> CodexRateLimitResponse {
        try await request(method: "account/rateLimits/read", params: nil)
    }

    public func readUsage() async throws -> CodexUsageResponse {
        try await request(method: "account/usage/read", params: nil)
    }

    public func rateLimitUpdates() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream { continuation in
            updateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeUpdateContinuation(id) }
            }
        }
    }

    public func stop() {
        stopConnection(reason: .unavailable(strings.text(
            "Codex app-server stopped.",
            "Codex app-server 已停止。"
        )))
        for continuation in updateContinuations.values {
            continuation.finish()
        }
        updateContinuations.removeAll()
    }

    private func request<T: Decodable & Equatable & Sendable>(
        method: String,
        params: Any?
    ) async throws -> T {
        try await ensureInitialized()
        let line = try await requestLine(method: method, params: params)
        return try decodeJSONRPCResponse(
            line: line,
            stderr: stderrText,
            method: method,
            language: language
        )
    }

    private func ensureInitialized() async throws {
        if isInitialized { return }
        if let initializationTask {
            return try await initializationTask.value
        }

        let task = Task { [weak self] in
            guard let self else {
                throw ProviderError.unavailable("The Codex app-server client was released.")
            }
            let params: [String: Any] = [
                "clientInfo": [
                    "name": "tokenbar",
                    "title": "TokenBar",
                    "version": self.clientVersion
                ],
                "capabilities": ["experimentalApi": true]
            ]
            let line = try await self.requestLine(method: "initialize", params: params, requestID: 0)
            try decodeJSONRPCAcknowledgement(
                line: line,
                method: "initialize",
                language: self.language
            )
            try await self.sendNotification(method: "initialized", params: [:])
            await self.completeInitialization()
        }
        initializationTask = task

        do {
            try await task.value
        } catch {
            initializationTask = nil
            stopConnection(reason: normalized(error))
            throw error
        }
    }

    private func completeInitialization() {
        isInitialized = true
        initializationTask = nil
    }

    private func requestLine(
        method: String,
        params: Any?,
        requestID explicitID: Int? = nil
    ) async throws -> Data {
        let connection = try ensureConnection()
        let requestID = explicitID ?? nextRequestID
        if explicitID == nil {
            nextRequestID += 1
        }
        let payload = try jsonLine(id: requestID, method: method, params: params)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[requestID] = continuation
                timeoutTasks[requestID] = Task { [weak self] in
                    let timeout = await self?.timeoutSeconds ?? 8
                    try? await Task.sleep(for: .seconds(timeout))
                    guard !Task.isCancelled else { return }
                    await self?.requestTimedOut(requestID, method: method)
                }

                do {
                    try connection.write(payload)
                } catch {
                    pending.removeValue(forKey: requestID)
                    timeoutTasks.removeValue(forKey: requestID)?.cancel()
                    continuation.resume(throwing: ProviderError.commandFailed(strings.text(
                        "Unable to write to Codex app-server: \(error.localizedDescription)",
                        "无法写入 Codex app-server：\(error.localizedDescription)"
                    )))
                    stopConnection(reason: .commandFailed(strings.text(
                        "The Codex app-server connection closed.",
                        "Codex app-server 连接已断开。"
                    )))
                }
            }
        } onCancel: {
            Task { await self.cancelRequest(requestID) }
        }
    }

    private func sendNotification(method: String, params: Any?) throws {
        let connection = try ensureConnection()
        try connection.write(jsonLine(id: nil, method: method, params: params))
    }

    private func ensureConnection() throws -> AppServerConnection {
        if let connection, connection.process.isRunning {
            return connection
        }

        let connectionID = UUID()
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable, "app-server", "--stdio"]
        process.environment = mergedEnvironment()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let connection = AppServerConnection(
            id: connectionID,
            process: process,
            stdin: stdin,
            stdout: stdout,
            stderr: stderr
        )

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.receiveStdout(data, connectionID: connectionID) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.receiveStderr(data, connectionID: connectionID) }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { await self?.connectionTerminated(connectionID: connectionID, status: status) }
        }

        do {
            try process.run()
        } catch {
            connection.clearHandlers()
            throw ProviderError.commandFailed(
                strings.text(
                    "Unable to start `\(executable) app-server`. Confirm that Codex is installed and signed in.",
                    "无法启动 `\(executable) app-server`。请确认 Codex CLI 已安装并已登录。"
                )
            )
        }

        self.connection = connection
        lineBuffer.removeAll(keepingCapacity: true)
        stderrBuffer.removeAll(keepingCapacity: true)
        return connection
    }

    private func receiveStdout(_ data: Data, connectionID: UUID) {
        guard connection?.id == connectionID else { return }
        lineBuffer.append(data)
        let newline = Data([0x0A])

        while let range = lineBuffer.range(of: newline) {
            let line = lineBuffer.subdata(in: lineBuffer.startIndex..<range.lowerBound)
            lineBuffer.removeSubrange(lineBuffer.startIndex..<range.upperBound)
            guard !line.isEmpty else { continue }
            handleJSONLine(line)
        }
    }

    private func receiveStderr(_ data: Data, connectionID: UUID) {
        guard connection?.id == connectionID else { return }
        stderrBuffer.append(data)
        let maximumBytes = 32 * 1024
        if stderrBuffer.count > maximumBytes {
            stderrBuffer.removeFirst(stderrBuffer.count - maximumBytes)
        }
    }

    private func handleJSONLine(_ line: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else {
            return
        }

        if let id = (object["id"] as? NSNumber)?.intValue,
           let continuation = pending.removeValue(forKey: id) {
            timeoutTasks.removeValue(forKey: id)?.cancel()
            continuation.resume(returning: line)
            return
        }

        if object["method"] as? String == "account/rateLimits/updated" {
            for continuation in updateContinuations.values {
                continuation.yield()
            }
        }
    }

    private func requestTimedOut(_ id: Int, method: String) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        timeoutTasks.removeValue(forKey: id)?.cancel()
        let suffix = stderrText.isEmpty ? "" : " \(stderrText)"
        let error = ProviderError.commandFailed(strings.text(
            "Timed out waiting for Codex app-server method \(method).\(suffix)",
            "等待 Codex app-server 的 \(method) 响应超时。\(suffix)"
        ))
        continuation.resume(throwing: error)
        stopConnection(reason: error)
    }

    private func cancelRequest(_ id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        timeoutTasks.removeValue(forKey: id)?.cancel()
        continuation.resume(throwing: CancellationError())
    }

    private func connectionTerminated(connectionID: UUID, status: Int32) {
        guard connection?.id == connectionID else { return }
        let detail = stderrText
        let suffix = detail.isEmpty ? "" : strings.text(": \(detail)", "：\(detail)")
        stopConnection(reason: .commandFailed(strings.text(
            "Codex app-server exited with status \(status)\(suffix)",
            "Codex app-server 已退出（状态码 \(status)）\(suffix)"
        )))
    }

    private func stopConnection(reason: ProviderError) {
        let activeConnection = connection
        connection = nil
        isInitialized = false
        initializationTask?.cancel()
        initializationTask = nil
        lineBuffer.removeAll(keepingCapacity: false)

        for task in timeoutTasks.values { task.cancel() }
        timeoutTasks.removeAll()
        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: reason)
        }

        activeConnection?.terminate()
    }

    private func removeUpdateContinuation(_ id: UUID) {
        updateContinuations.removeValue(forKey: id)
    }

    private var stderrText: String {
        String(decoding: stderrBuffer, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalized(_ error: Error) -> ProviderError {
        if let error = error as? ProviderError { return error }
        if error is CancellationError {
            return .unavailable(strings.text(
                "The Codex app-server request was cancelled.",
                "Codex app-server 请求已取消。"
            ))
        }
        return .commandFailed(error.localizedDescription)
    }

    private var strings: TokenBarStrings { TokenBarStrings(language) }
}

private final class AppServerConnection: @unchecked Sendable {
    let id: UUID
    let process: Process
    let stdin: Pipe
    let stdout: Pipe
    let stderr: Pipe
    private let writeLock = NSLock()

    init(id: UUID, process: Process, stdin: Pipe, stdout: Pipe, stderr: Pipe) {
        self.id = id
        self.process = process
        self.stdin = stdin
        self.stdout = stdout
        self.stderr = stderr
    }

    func write(_ data: Data) throws {
        writeLock.lock()
        defer { writeLock.unlock() }
        try stdin.fileHandleForWriting.write(contentsOf: data)
    }

    func clearHandlers() {
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
    }

    func terminate() {
        clearHandlers()
        try? stdin.fileHandleForWriting.close()
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { [process] in
            if process.isRunning {
                Darwin.kill(pid, SIGKILL)
            }
        }
    }
}

private func jsonLine(id: Int?, method: String, params: Any?) throws -> Data {
    var object: [String: Any] = ["method": method]
    if let id { object["id"] = id }
    if let params { object["params"] = params }
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return data + Data([0x0A])
}

private func decodeJSONRPCAcknowledgement(
    line: Data,
    method: String,
    language: AppLanguage
) throws {
    let strings = TokenBarStrings(language)
    let rpc = try JSONDecoder().decode(CodexRPCAcknowledgement.self, from: line)
    if let error = rpc.error {
        throw ProviderError.commandFailed(strings.text(
            "Codex app-server method \(method) failed: \(error.message)",
            "Codex app-server \(method) 调用失败：\(error.message)"
        ))
    }
    guard rpc.result != nil else {
        throw ProviderError.invalidResponse(strings.text(
            "Codex app-server did not acknowledge \(method).",
            "Codex app-server 没有确认 \(method)。"
        ))
    }
}

private func decodeJSONRPCResponse<T: Decodable & Equatable & Sendable>(
    line: Data,
    stderr: String,
    method: String,
    language: AppLanguage
) throws -> T {
    let strings = TokenBarStrings(language)
    let rpc = try JSONDecoder().decode(CodexRPCResponse<T>.self, from: line)
    if let result = rpc.result { return result }
    if let error = rpc.error {
        throw ProviderError.commandFailed(strings.text(
            "Codex app-server method \(method) failed: \(error.message)",
            "Codex app-server \(method) 调用失败：\(error.message)"
        ))
    }
    if !stderr.isEmpty {
        throw ProviderError.commandFailed(strings.text(
            "Codex app-server returned no \(method) result: \(stderr)",
            "Codex app-server 没有返回 \(method)：\(stderr)"
        ))
    }
    throw ProviderError.invalidResponse(strings.text(
        "Codex app-server returned no JSON-RPC response for \(method).",
        "Codex app-server 没有返回 \(method) 的 JSON-RPC 响应。"
    ))
}

private func mergedEnvironment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let additions = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "\(NSHomeDirectory())/.local/bin"
    ]
    let currentPath = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
    environment["PATH"] = (currentPath + additions)
        .reduce(into: [String]()) { paths, path in
            if !paths.contains(path) { paths.append(path) }
        }
        .joined(separator: ":")
    return environment
}
