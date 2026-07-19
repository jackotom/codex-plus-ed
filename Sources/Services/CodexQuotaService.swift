import Foundation

actor CodexQuotaService {
    private let executableURL: URL
    private let requestTimeout: Duration
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var readerTask: Task<Void, Never>?
    private var connectTask: Task<Void, Error>?
    private var pending: [Int64: CheckedContinuation<JSONValue, Error>] = [:]
    private var nextRequestID: Int64 = 1
    private var generation = 0
    private var initialized = false

    init(executableURL: URL? = nil, requestTimeout: Duration = .seconds(8)) {
        self.executableURL = executableURL ?? Self.findCodexExecutable()
        self.requestTimeout = requestTimeout
    }

    func fetchSnapshot() async throws -> QuotaSnapshot {
        try await ensureConnected()
        let response: RateLimitsResponse = try await request(
            method: "account/rateLimits/read",
            params: .null
        )
        return try response.snapshot(fetchedAt: Date())
    }

    static func decodeSnapshot(from responseData: Data, fetchedAt: Date = Date()) throws -> QuotaSnapshot {
        do {
            return try JSONDecoder()
                .decode(RateLimitsResponse.self, from: responseData)
                .snapshot(fetchedAt: fetchedAt)
        } catch let error as CodexQuotaError {
            throw error
        } catch {
            throw CodexQuotaError.invalidResponse
        }
    }

    func disconnect() {
        closeConnection(error: CodexQuotaError.disconnected)
    }

    private func ensureConnected() async throws {
        if initialized, process?.isRunning == true { return }

        if let connectTask {
            try await connectTask.value
            return
        }

        let task = Task { try await establishConnection() }
        connectTask = task
        do {
            try await task.value
            connectTask = nil
        } catch {
            connectTask = nil
            closeConnection(error: error)
            throw error
        }
    }

    private func establishConnection() async throws {
        closeConnection(error: CodexQuotaError.disconnected)

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CodexQuotaError.executableUnavailable
        }

        generation &+= 1
        let currentGeneration = generation
        self.process = process
        input = inputPipe.fileHandleForWriting
        output = outputPipe.fileHandleForReading

        process.terminationHandler = { [weak self] _ in
            Task { await self?.processExited(generation: currentGeneration) }
        }
        startReader(outputPipe.fileHandleForReading, generation: currentGeneration)

        let _: InitializeResponse = try await request(
            method: "initialize",
            params: .object([
                "clientInfo": .object([
                    "name": .string("codex-pulse"),
                    "title": .string("Codex Pulse"),
                    "version": .string("1.0.0")
                ]),
                "capabilities": .object([
                    "experimentalApi": .bool(true)
                ])
            ])
        )
        try sendNotification(method: "initialized")
        initialized = true
    }

    private func request<Response: Decodable & Sendable>(
        method: String,
        params: JSONValue
    ) async throws -> Response {
        guard process?.isRunning == true else {
            throw CodexQuotaError.disconnected
        }

        let id = nextRequestID
        nextRequestID &+= 1
        let request = RPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request) + Data([0x0A])
        let timeout = requestTimeout

        let result = try await withThrowingTaskGroup(of: JSONValue.self) { group in
            group.addTask {
                try await self.sendAndAwait(id: id, data: data)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CodexQuotaError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw CodexQuotaError.invalidResponse
            }
            return first
        }

        do {
            return try JSONDecoder().decode(Response.self, from: JSONEncoder().encode(result))
        } catch {
            throw CodexQuotaError.invalidResponse
        }
    }

    private func sendAndAwait(id: Int64, data: Data) async throws -> JSONValue {
        guard process?.isRunning == true, let input else {
            throw CodexQuotaError.disconnected
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do {
                    try input.write(contentsOf: data)
                } catch {
                    pending.removeValue(forKey: id)?.resume(throwing: CodexQuotaError.disconnected)
                }
            }
        } onCancel: {
            Task { await self.cancelRequest(id) }
        }
    }

    private func sendNotification(method: String) throws {
        guard process?.isRunning == true, let input else {
            throw CodexQuotaError.disconnected
        }
        let data = try JSONEncoder().encode(RPCNotification(method: method)) + Data([0x0A])
        do {
            try input.write(contentsOf: data)
        } catch {
            throw CodexQuotaError.disconnected
        }
    }

    private func startReader(_ handle: FileHandle, generation: Int) {
        readerTask = Task.detached { [weak self] in
            var line = Data()
            do {
                for try await byte in handle.bytes {
                    if byte == 0x0A {
                        if !line.isEmpty {
                            await self?.receive(line, generation: generation)
                            line.removeAll(keepingCapacity: true)
                        }
                    } else {
                        line.append(byte)
                    }
                }
                if !line.isEmpty {
                    await self?.receive(line, generation: generation)
                }
                await self?.readerEnded(generation: generation)
            } catch {
                await self?.readerEnded(generation: generation)
            }
        }
    }

    private func receive(_ data: Data, generation: Int) {
        guard generation == self.generation else { return }

        guard
            let value = try? JSONDecoder().decode(JSONValue.self, from: data),
            case let .object(object) = value
        else {
            closeConnection(error: CodexQuotaError.invalidResponse)
            return
        }

        guard let id = object["id"]?.integerValue else {
            return
        }
        guard let continuation = pending.removeValue(forKey: id) else {
            return
        }

        if case let .object(error)? = object["error"], let code = error["code"]?.integerValue {
            continuation.resume(throwing: CodexQuotaError.serverError(code: code))
        } else if let result = object["result"] {
            continuation.resume(returning: result)
        } else {
            continuation.resume(throwing: CodexQuotaError.invalidResponse)
        }
    }

    private func cancelRequest(_ id: Int64) {
        pending.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func processExited(generation: Int) {
        guard generation == self.generation else { return }
        closeConnection(error: CodexQuotaError.disconnected)
    }

    private func readerEnded(generation: Int) {
        guard generation == self.generation else { return }
        closeConnection(error: CodexQuotaError.disconnected)
    }

    private func closeConnection(error: Error) {
        generation &+= 1
        initialized = false
        readerTask?.cancel()
        readerTask = nil
        try? input?.close()
        try? output?.close()
        input = nil
        output = nil

        let runningProcess = process
        process = nil
        runningProcess?.terminationHandler = nil
        if runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }

        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    static func findCodexExecutable(candidates: [URL]? = nil) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let searchCandidates = candidates ?? [
            URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
            home.appendingPathComponent(".local/bin/codex")
        ]
        return searchCandidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
            ?? URL(fileURLWithPath: "/usr/bin/codex")
    }
}

enum CodexQuotaError: LocalizedError, Equatable {
    case executableUnavailable
    case disconnected
    case invalidResponse
    case invalidQuota(String)
    case serverError(code: Int64)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .executableUnavailable: "找不到本机 Codex"
        case .disconnected: "Codex 连接已断开"
        case .invalidResponse: "Codex 返回了无法识别的数据"
        case let .invalidQuota(reason): "额度数据不可用：\(reason)"
        case let .serverError(code): "Codex 暂时无法读取额度（\(code)）"
        case .timedOut: "Codex 响应超时"
        }
    }
}

private struct RPCRequest: Encodable {
    let id: Int64
    let method: String
    let params: JSONValue
}

private struct RPCNotification: Encodable {
    let method: String
}

private struct InitializeResponse: Decodable, Sendable {
    let userAgent: String
    let platformFamily: String
    let platformOs: String
    let codexHome: String
}

private struct RateLimitsResponse: Decodable, Sendable {
    let rateLimits: RawBucket
    let rateLimitsByLimitId: [String: RawBucket]?
    let rateLimitResetCredits: ResetCredits?

    func snapshot(fetchedAt: Date) throws -> QuotaSnapshot {
        let source: [(String, RawBucket)]
        if let rateLimitsByLimitId, !rateLimitsByLimitId.isEmpty {
            source = rateLimitsByLimitId.sorted { $0.key < $1.key }
        } else {
            source = [(rateLimits.limitId ?? "codex", rateLimits)]
        }

        let buckets = try source.map { key, raw in
            try raw.validated(fallbackID: key)
        }
        guard !buckets.isEmpty else {
            throw CodexQuotaError.invalidQuota("没有额度项目")
        }
        guard buckets.contains(where: { $0.primary != nil || $0.secondary != nil }) else {
            throw CodexQuotaError.invalidQuota("没有可用额度窗口")
        }
        if let count = rateLimitResetCredits?.availableCount, count < 0 {
            throw CodexQuotaError.invalidQuota("重置次数错误")
        }
        return QuotaSnapshot(
            buckets: buckets,
            resetCredits: rateLimitResetCredits?.availableCount,
            fetchedAt: fetchedAt
        )
    }
}

private struct ResetCredits: Decodable, Sendable {
    let availableCount: Int
}

private struct RawBucket: Decodable, Sendable {
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: RawWindow?
    let secondary: RawWindow?

    func validated(fallbackID: String) throws -> RateLimitBucket {
        let id = limitId ?? fallbackID
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexQuotaError.invalidQuota("项目编号为空")
        }
        if let limitId, limitId != fallbackID {
            throw CodexQuotaError.invalidQuota("项目编号不一致")
        }
        return RateLimitBucket(
            id: id,
            limitName: limitName,
            planType: planType,
            primary: try primary?.validated(),
            secondary: try secondary?.validated()
        )
    }
}

private struct RawWindow: Decodable, Sendable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int64?

    func validated() throws -> RateLimitWindow {
        guard (0...100).contains(usedPercent) else {
            throw CodexQuotaError.invalidQuota("百分比超出范围")
        }
        if let windowDurationMins, windowDurationMins <= 0 {
            throw CodexQuotaError.invalidQuota("周期长度错误")
        }
        if let resetsAt, resetsAt <= 0 {
            throw CodexQuotaError.invalidQuota("重置时间错误")
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            windowDurationMinutes: windowDurationMins,
            resetsAt: resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

private enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    var integerValue: Int64? {
        if case let .integer(value) = self { value } else { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}
