import AppKit
import SwiftUI

@MainActor
struct MainDashboardView: View {
    let monitor: QuotaMonitor
    let onHide: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isStale {
                        ErrorBanner(message: "数据已过期，正在重新连接")
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            weeklyQuotaCard
                                .frame(minWidth: 280, idealWidth: 310, maxWidth: 330)
                            detailCard
                                .frame(minWidth: 420, maxWidth: .infinity)
                        }

                        VStack(spacing: 16) {
                            weeklyQuotaCard
                            detailCard
                        }
                    }
                }
                .frame(maxWidth: 1_040)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)
        }
        .frame(minWidth: 820, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Pulse")
                    .font(.system(size: 18, weight: .semibold))
                Text("Codex 额度实时监控")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let planName {
                Text(planName)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel("套餐 \(planName)")
            }

            Label(connectionText, systemImage: connectionSymbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(connectionColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(connectionColor.opacity(0.10), in: Capsule())

            Spacer(minLength: 16)

            Button {
                monitor.refreshNow()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(monitor.isRefreshing)
            .help("立即刷新")

            Button(action: onHide) {
                Label("隐藏到状态栏", systemImage: "menubar.rectangle")
            }
            .buttonStyle(.bordered)
            .help("隐藏主界面，顶部额度继续更新")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var weeklyQuotaCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("本周额度")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("每秒更新")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let window = monitor.snapshot?.primaryWindow {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(.quaternary, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: Double(window.remainingPercent) / 100)
                            .stroke(
                                quotaColor(window.remainingPercent),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(window.remainingPercent)%")
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.8)
                            Text("剩余")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 122, height: 122)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("本周额度")
                    .accessibilityValue("剩余 \(window.remainingPercent)%, \(QuotaFormatting.resetText(window.resetsAt))")

                    Text(QuotaFormatting.resetText(window.resetsAt))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()

                    if let credits = monitor.snapshot?.resetCredits, credits > 0 {
                        Label("可额外重置 \(credits) 次", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if window.remainingPercent <= 20 {
                        Label(
                            window.remainingPercent == 0 ? "额度已用完" : "额度偏低",
                            systemImage: window.remainingPercent == 0
                                ? "xmark.circle.fill"
                                : "exclamationmark.circle.fill"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                unavailableHero
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("隐藏后仍在菜单栏持续更新", systemImage: "menubar.rectangle")
                    .font(.system(size: 11, weight: .medium))
                Label("只读取本机 Codex 的额度数据", systemImage: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("其他额度")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                if let updatedText {
                    Text(updatedText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if monitor.snapshot == nil {
                detailUnavailable
            } else if detailBuckets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("当前没有其他独立额度")
                        .font(.system(size: 13, weight: .medium))
                    Text("本周剩余额度以左侧为准")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(detailBuckets) { bucket in
                        QuotaBucketCard(bucket: bucket)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    private var unavailableHero: some View {
        VStack(spacing: 10) {
            if monitor.connectionState == .connecting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(connectionStateTitle)
                .font(.system(size: 13, weight: .semibold))
            Text("请确认本机已登录 Codex")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var detailUnavailable: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("正在读取额度…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private var detailBuckets: [RateLimitBucket] {
        guard let snapshot = monitor.snapshot else { return [] }

        let primaryBucketID = snapshot.primaryBucket?.id
        let primaryWindow = snapshot.primaryWindow

        return snapshot.buckets
            .compactMap { bucket -> RateLimitBucket? in
                var primary = bucket.primary
                var secondary = bucket.secondary

                if bucket.id == primaryBucketID {
                    if primary == primaryWindow {
                        primary = nil
                    } else if secondary == primaryWindow {
                        secondary = nil
                    }
                }

                guard primary != nil || secondary != nil else { return nil }
                return RateLimitBucket(
                    id: bucket.id,
                    limitName: bucket.limitName,
                    planType: bucket.planType,
                    primary: primary,
                    secondary: secondary
                )
            }
            .sorted {
                displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending
            }
    }

    private var planName: String? {
        guard let plan = monitor.snapshot?.primaryBucket?.planType?
            .trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty
        else { return nil }
        return plan.localizedCapitalized
    }

    private var updatedText: String? {
        guard let date = monitor.snapshot?.fetchedAt else { return nil }
        return "更新于 \(date.formatted(date: .omitted, time: .shortened))"
    }

    private var isStale: Bool {
        guard let snapshot = monitor.snapshot else { return false }
        return monitor.connectionState != .connected
            || monitor.lastError != nil
            || Date().timeIntervalSince(snapshot.fetchedAt) > 2.5
    }

    private var connectionText: String {
        switch monitor.connectionState {
        case .connected: "实时"
        case .connecting: "连接中"
        case .disconnected: "未连接"
        case .unavailable: "暂不可用"
        }
    }

    private var connectionStateTitle: String {
        switch monitor.connectionState {
        case .connecting, .connected: "正在连接 Codex…"
        case .disconnected: "无法连接 Codex"
        case .unavailable: "额度暂不可用"
        }
    }

    private var connectionSymbol: String {
        switch monitor.connectionState {
        case .connected: "checkmark.circle.fill"
        case .connecting: "arrow.clockwise"
        case .disconnected: "wifi.slash"
        case .unavailable: "exclamationmark.circle.fill"
        }
    }

    private var connectionColor: Color {
        switch monitor.connectionState {
        case .connected: .green
        case .connecting: .blue
        case .disconnected: .secondary
        case .unavailable: .orange
        }
    }

    private func quotaColor(_ remainingPercent: Int) -> Color {
        switch remainingPercent {
        case 51...: .accentColor
        case 21...50: .orange
        default: .red
        }
    }

    private func displayName(_ bucket: RateLimitBucket) -> String {
        bucket.limitName ?? bucket.limitId
    }
}
