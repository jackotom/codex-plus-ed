import AppKit
import SwiftUI

@MainActor
struct QuotaDashboardView: View {
    let monitor: QuotaMonitor

    var body: some View {
        VStack(spacing: 12) {
            header
            content
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 336)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = monitor.snapshot {
            snapshotContent(snapshot)
        } else {
            emptyContent
        }
    }

    @ViewBuilder
    private func snapshotContent(_ snapshot: QuotaSnapshot) -> some View {
        if isStale {
            ErrorBanner(message: "数据已过期，正在重新连接")
        }

        if let window = snapshot.primaryWindow {
            PrimaryQuotaCard(
                remainingPercent: window.remainingPercent,
                resetsAt: window.resetsAt,
                resetCredits: snapshot.resetCredits
            )
        } else {
            QuotaUnavailableCard(
                symbol: "questionmark.circle",
                title: "额度暂不可用",
                message: "Codex 未返回可支持的额度数据",
                retry: { monitor.refreshNow() }
            )
        }

        if !displayBuckets.isEmpty {
            details
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if monitor.connectionState == .connecting {
            QuotaUnavailableCard(
                symbol: unavailableSymbol,
                title: emptyStateTitle,
                message: emptyStateMessage,
                isLoading: true,
                retry: nil
            )
        } else {
            QuotaUnavailableCard(
                symbol: unavailableSymbol,
                title: emptyStateTitle,
                message: emptyStateMessage,
                retry: { monitor.refreshNow() }
            )
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("额度明细")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(displayBuckets) { bucket in
                        QuotaBucketCard(bucket: bucket)
                    }
                }
            }
            .frame(height: detailsHeight)
        }
    }

    private var detailsHeight: CGFloat {
        let windowCount = displayBuckets.reduce(0) { count, bucket in
            count + [bucket.primary, bucket.secondary].compactMap { $0 }.count
        }
        return min(max(CGFloat(displayBuckets.count * 44 + windowCount * 56), 140), 220)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Codex Pulse")
                .font(.system(size: 13, weight: .semibold))

            if let plan = monitor.snapshot?.primaryBucket?.planType {
                Text(plan.localizedCapitalized)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel("套餐 \(plan)")
            }

            Spacer()

            Button {
                (NSApplication.shared.delegate as? FirstLaunchCoordinator)?.showMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("打开主界面")
            .accessibilityLabel("打开主界面")

            Button {
                monitor.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(monitor.isRefreshing)
            .help("立即刷新")
            .accessibilityLabel("立即刷新")
        }
        .frame(minHeight: 28)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: footerSymbol)
                .foregroundStyle(footerColor)
                .accessibilityHidden(true)
            Text(footerText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Button {
                monitor.stop()
                (NSApplication.shared.delegate as? FirstLaunchCoordinator)?.requestQuit()
            } label: {
                Image(systemName: "power")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("退出 Codex Pulse")
            .accessibilityLabel("退出 Codex Pulse")
        }
        .overlay(alignment: .top) {
            Divider()
                .offset(y: -6)
                .accessibilityHidden(true)
        }
    }

    private var displayBuckets: [RateLimitBucket] {
        guard let snapshot = monitor.snapshot else { return [] }
        let primaryID = snapshot.primaryBucket?.id
        return snapshot.buckets
            .filter { $0.primary != nil || $0.secondary != nil }
            .sorted { lhs, rhs in
                if lhs.id == primaryID { return true }
                if rhs.id == primaryID { return false }
                return (lhs.limitName ?? lhs.limitId).localizedStandardCompare(rhs.limitName ?? rhs.limitId) == .orderedAscending
            }
    }

    private var isStale: Bool {
        guard let snapshot = monitor.snapshot else { return false }
        return monitor.connectionState != .connected
            || monitor.lastError != nil
            || Date().timeIntervalSince(snapshot.fetchedAt) > 2.5
    }

    private var footerText: String {
        if monitor.connectionState == .connected, !isStale {
            return "实时"
        }
        guard let date = monitor.snapshot?.fetchedAt else {
            switch monitor.connectionState {
            case .connecting: return "连接中"
            case .connected: return "读取中"
            case .disconnected: return "已断开"
            case .unavailable: return "不可用"
            }
        }
        return "更新于 \(date.formatted(date: .omitted, time: .shortened))"
    }

    private var footerSymbol: String {
        if monitor.connectionState == .connected, !isStale {
            return "checkmark.circle.fill"
        }
        return monitor.connectionState == .connecting ? "arrow.clockwise" : "exclamationmark.circle.fill"
    }

    private var footerColor: Color {
        if monitor.connectionState == .connected, !isStale { return .green }
        return monitor.connectionState == .connecting ? .secondary : .orange
    }

    private var unavailableSymbol: String {
        monitor.connectionState == .unavailable ? "questionmark.circle" : "wifi.slash"
    }

    private var emptyStateTitle: String {
        switch monitor.connectionState {
        case .connecting, .connected: return "正在连接 Codex…"
        case .disconnected: return "无法连接 Codex"
        case .unavailable: return "额度暂不可用"
        }
    }

    private var emptyStateMessage: String {
        switch monitor.connectionState {
        case .connecting, .connected: return "首次读取可能需要几秒"
        case .disconnected: return "请确认本机已登录 Codex"
        case .unavailable: return "Codex 未返回可支持的额度数据"
        }
    }

}
