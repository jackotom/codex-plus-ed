import SwiftUI

struct PrimaryQuotaCard: View {
    let remainingPercent: Int
    let resetsAt: Date?
    let resetCredits: Int?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(remainingPercent == 0 ? "本周额度已用完" : "本周额度")
                    .font(.system(size: 13, weight: .semibold))

                Text(QuotaFormatting.resetText(resetsAt))
                    .font(.system(size: 12, weight: remainingPercent == 0 ? .semibold : .regular))
                    .foregroundStyle(remainingPercent == 0 ? Color.primary : Color.secondary)

                if let resetCredits {
                    Text("额外额度 ×\(resetCredits)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if remainingPercent <= 20 {
                    Label(
                        remainingPercent == 0 ? "额度已用完" : "额度偏低",
                        systemImage: remainingPercent == 0 ? "xmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(remainingPercent) / 100)
                    .stroke(quotaColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(remainingPercent)%")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 82, height: 82)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("本周额度")
            .accessibilityValue("剩余 \(remainingPercent)%, \(QuotaFormatting.resetText(resetsAt))")
        }
        .padding(14)
        .frame(minHeight: 104)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    private var quotaColor: Color {
        switch remainingPercent {
        case 51...: .accentColor
        case 21...50: .orange
        default: .red
        }
    }
}

struct QuotaBucketCard: View {
    let bucket: RateLimitBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(displayName)
                .accessibilityLabel(displayName)

            ForEach(Array(windows.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider()
                        .accessibilityHidden(true)
                }
                QuotaWindowRow(window: item)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    private var displayName: String {
        bucket.limitName ?? bucket.limitId
    }

    private var windows: [RateLimitWindow] {
        [bucket.primary, bucket.secondary]
            .compactMap { $0 }
            .sorted {
                ($0.windowDurationMinutes ?? .max) < ($1.windowDurationMinutes ?? .max)
            }
    }
}

private struct QuotaWindowRow: View {
    let window: RateLimitWindow

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(QuotaFormatting.windowLabel(window.windowDurationMinutes))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(window.remainingPercent)% 剩余")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                        Capsule()
                            .fill(progressColor)
                            .frame(width: proxy.size.width * Double(window.remainingPercent) / 100)
                    }
                }
                .frame(height: 6)

                Text(QuotaFormatting.resetText(window.resetsAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(QuotaFormatting.windowLabel(window.windowDurationMinutes))
        .accessibilityValue("剩余 \(window.remainingPercent)%, \(QuotaFormatting.resetText(window.resetsAt))")
    }

    private var progressColor: Color {
        switch window.remainingPercent {
        case 51...: .accentColor
        case 21...50: .orange
        default: .red
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(message)
    }
}

struct QuotaUnavailableCard: View {
    let symbol: String
    let title: String
    let message: String
    var isLoading = false
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let retry {
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private enum QuotaFormatting {
    static func windowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "额度窗口" }
        if minutes >= 1_440, minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440) 天额度"
        }
        if minutes >= 60, minutes.isMultiple(of: 60) {
            return "\(minutes / 60) 小时额度"
        }
        return "\(minutes) 分钟额度"
    }

    static func resetText(_ date: Date?) -> String {
        guard let date else { return "重置时间未知" }
        let time = date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(Locale(identifier: "zh_CN"))
        )
        if Calendar.current.isDateInToday(date) {
            return "今天 \(time) 重置"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "明天 \(time) 重置"
        }
        let day = date.formatted(
            Date.FormatStyle().month(.defaultDigits).day(.defaultDigits)
                .locale(Locale(identifier: "zh_CN"))
        )
        return "\(day) \(time) 重置"
    }
}
