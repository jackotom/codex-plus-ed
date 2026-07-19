import AppKit
import SwiftUI

@main
@MainActor
struct CodexPulseApp: App {
    @NSApplicationDelegateAdaptor(FirstLaunchCoordinator.self) private var firstLaunchCoordinator
    @State private var monitor = QuotaMonitor()

    var body: some Scene {
        MenuBarExtra {
            QuotaDashboardView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                Text(menuBarValue)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .leading)
            }
            .accessibilityLabel(accessibleMenuBarValue)
            .onAppear {
                monitor.start()
            }
            .onDisappear {
                monitor.stop()
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Codex Pulse") {
                    firstLaunchCoordinator.requestQuit()
                }
                .keyboardShortcut("q")
            }
        }
    }

    private var menuBarValue: String {
        if let remaining = monitor.snapshot?.primaryWindow?.remainingPercent {
            return isStale ? "\(remaining)% !" : "\(remaining)%"
        }
        return monitor.connectionState == .connecting ? "…" : "--"
    }

    private var accessibleMenuBarValue: String {
        guard let remaining = monitor.snapshot?.primaryWindow?.remainingPercent else {
            return monitor.connectionState == .connecting ? "Codex 额度正在加载" : "Codex 额度暂不可用"
        }
        if remaining == 0 {
            return "Codex 本周额度已用完"
        }
        return isStale
            ? "Codex 本周额度剩余 \(remaining)%, 数据已过期"
            : "Codex 本周额度剩余 \(remaining)%"
    }

    private var isStale: Bool {
        guard let snapshot = monitor.snapshot else { return false }
        return monitor.connectionState != .connected
            || monitor.lastError != nil
            || Date().timeIntervalSince(snapshot.fetchedAt) > 2.5
    }

    private var statusIcon: String {
        if monitor.snapshot == nil, monitor.connectionState != .connecting {
            return "bolt.slash"
        }
        return "bolt"
    }
}

@MainActor
final class FirstLaunchCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let completionKey = "hasCompletedFirstLaunch"

    private var window: NSWindow?
    private var didOfferWelcome = false
    private var allowsTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        showIfNeeded()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        allowsTermination ? .terminateNow : .terminateCancel
    }

    func requestQuit() {
        allowsTermination = true
        NSApplication.shared.terminate(nil)
    }

    func showIfNeeded() {
        guard
            !didOfferWelcome,
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
            !UserDefaults.standard.bool(forKey: Self.completionKey)
        else { return }
        didOfferWelcome = true

        let view = FirstLaunchView { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.completionKey)
            self?.window?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "欢迎使用 Codex Pulse"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
