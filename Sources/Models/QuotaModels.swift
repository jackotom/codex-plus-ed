import Foundation

enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case unavailable
}

struct RateLimitWindow: Equatable, Sendable {
    let usedPercent: Int
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    var remainingPercent: Int { 100 - usedPercent }
}

struct RateLimitBucket: Identifiable, Equatable, Sendable {
    let id: String
    let limitName: String?
    let planType: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?

    var limitId: String { id }

    var longestWindow: RateLimitWindow? {
        [primary, secondary]
            .compactMap { $0 }
            .max { ($0.windowDurationMinutes ?? 0) < ($1.windowDurationMinutes ?? 0) }
    }
}

struct QuotaSnapshot: Equatable, Sendable {
    let buckets: [RateLimitBucket]
    let resetCredits: Int?
    let fetchedAt: Date

    var primaryBucket: RateLimitBucket? {
        buckets.first { $0.id == "codex" } ?? buckets.first
    }

    var primaryWindow: RateLimitWindow? {
        primaryBucket?.longestWindow
    }
}
