import Foundation
import Observation

@MainActor
@Observable
final class QuotaMonitor {
    private(set) var snapshot: QuotaSnapshot?
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var lastError: String?
    private(set) var isRefreshing = false

    private let service: CodexQuotaService
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var isRunning = false

    init(service: CodexQuotaService = CodexQuotaService()) {
        self.service = service
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        requestRefresh()
    }

    func refreshNow() {
        guard refreshTask == nil else { return }
        timerTask?.cancel()
        timerTask = nil
        requestRefresh()
    }

    func stop() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        connectionState = .disconnected
        Task { await service.disconnect() }
    }

    private func requestRefresh() {
        guard refreshTask == nil else { return }

        connectionState = snapshot == nil ? .connecting : connectionState
        isRefreshing = true
        refreshTask = Task { [weak self, service] in
            let result: Result<QuotaSnapshot, Error>
            do {
                result = .success(try await service.fetchSnapshot())
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else { return }
            self?.finishRefresh(result)
        }
    }

    private func finishRefresh(_ result: Result<QuotaSnapshot, Error>) {
        refreshTask = nil
        isRefreshing = false
        switch result {
        case let .success(snapshot):
            self.snapshot = snapshot
            connectionState = .connected
            lastError = nil
        case let .failure(error):
            if let error = error as? CodexQuotaError {
                switch error {
                case .invalidResponse, .invalidQuota, .serverError:
                    connectionState = .unavailable
                case .executableUnavailable, .disconnected, .timedOut:
                    connectionState = .disconnected
                }
            } else {
                connectionState = .disconnected
            }
            lastError = (error as? LocalizedError)?.errorDescription ?? "额度暂时不可用"
        }

        if isRunning {
            timerTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.timerTask = nil
                self?.requestRefresh()
            }
        }
    }
}
