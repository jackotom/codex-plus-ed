import AppKit
import SwiftUI

struct FirstLaunchView: View {
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)

                    Text("Codex Pulse")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Text("随时掌握 Codex 额度")
                        .font(.system(size: 28, weight: .semibold))

                    Text("剩余额度、重置时间和连接状态，都在菜单栏里一眼看清。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    featureRow(
                        symbol: "menubar.rectangle",
                        title: "状态栏实时显示",
                        detail: "不用打开 Codex，也能看到本周剩余额度。"
                    )
                    featureRow(
                        symbol: "arrow.clockwise",
                        title: "秒级自动更新",
                        detail: "后台顺序刷新，数据变化及时可见。"
                    )
                    featureRow(
                        symbol: "calendar.badge.clock",
                        title: "重置时间清楚可见",
                        detail: "5 小时与 7 天额度分别展示，不会混淆。"
                    )
                }

                Label("只通过本机 Codex 读取额度，不读取、不保存登录凭据。", systemImage: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

                Button(action: onComplete) {
                    Text("开始使用")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 280, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 44)
            .padding(.top, 32)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
        .frame(width: 520, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.09, green: 0.75, blue: 0.88))
                .frame(width: 30, height: 30)
                .background(Color(red: 0.03, green: 0.11, blue: 0.3), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    FirstLaunchView(onComplete: {})
}
