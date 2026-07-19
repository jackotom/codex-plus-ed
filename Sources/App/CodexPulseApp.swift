import AppKit
import SwiftUI

@main
enum CodexPulseMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let coordinator = FirstLaunchCoordinator()
        application.delegate = coordinator
        withExtendedLifetime(coordinator) {
            application.run()
        }
    }
}

@MainActor
final class FirstLaunchCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let completionKey = "hasCompletedFirstLaunch"

    private let monitor = QuotaMonitor()
    private let statusPopover = NSPopover()

    private var statusItem: NSStatusItem?
    private var statusRefreshTimer: Timer?
    private var displayedStatusIcon: String?
    private var welcomeWindow: NSWindow?
    private var mainWindow: NSWindow?
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureMainMenu()
        configureStatusItem()
        configureStatusPopover()
        monitor.start()
        startStatusRefreshTimer()
        refreshStatusItem()

        if UserDefaults.standard.bool(forKey: Self.completionKey) {
            showMainWindow()
        } else {
            showWelcomeWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if let welcomeWindow, welcomeWindow.isVisible {
            present(window: welcomeWindow)
        } else {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        statusRefreshTimer?.invalidate()
        statusRefreshTimer = nil
        monitor.stop()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === mainWindow else { return true }
        sender.orderOut(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        if closingWindow === welcomeWindow {
            welcomeWindow = nil
            if !isTerminating {
                showMainWindow()
            }
        }
    }

    func showMainWindow() {
        statusPopover.performClose(nil)

        if mainWindow == nil {
            mainWindow = makeMainWindow()
        }
        if let mainWindow {
            present(window: mainWindow)
        }
    }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }

    func requestQuit() {
        guard !isTerminating else { return }
        isTerminating = true
        statusPopover.performClose(nil)
        monitor.stop()
        NSApplication.shared.terminate(nil)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "退出 Codex Pulse",
            action: #selector(quitFromMenu(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(toggleStatusPopover(_:))
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.toolTip = "Codex Pulse"
        }

        statusItem.isVisible = true
        self.statusItem = statusItem
    }

    private func configureStatusPopover() {
        let controller = NSHostingController(rootView: QuotaDashboardView(monitor: monitor))
        controller.sizingOptions = [.preferredContentSize]
        statusPopover.contentViewController = controller
        statusPopover.behavior = .transient
        statusPopover.animates = true
    }

    private func startStatusRefreshTimer() {
        let timer = Timer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(refreshStatusItem),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        statusRefreshTimer = timer
    }

    @objc
    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }

        let symbolName = statusIcon
        if displayedStatusIcon != symbolName {
            let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            image?.isTemplate = true
            button.image = image
            displayedStatusIcon = symbolName
        }

        button.title = menuBarValue
        button.toolTip = accessibleMenuBarValue
        button.setAccessibilityLabel(accessibleMenuBarValue)
    }

    @objc
    private func toggleStatusPopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if statusPopover.isShown {
            statusPopover.performClose(sender)
        } else {
            refreshStatusItem()
            statusPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc
    private func quitFromMenu(_ sender: Any?) {
        requestQuit()
    }

    private func showWelcomeWindow() {
        guard
            welcomeWindow == nil,
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }

        let view = FirstLaunchView { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.completionKey)
            self?.welcomeWindow?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "欢迎使用 Codex Pulse"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        welcomeWindow = window
        present(window: window)
    }

    private func makeMainWindow() -> NSWindow {
        let view = MainDashboardView(
            monitor: monitor,
            onHide: { [weak self] in self?.hideMainWindow() }
        )
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Pulse"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 820, height: 440)
        window.delegate = self

        let frameName = "CodexPulse.MainWindow.v5"
        if !window.setFrameUsingName(frameName) {
            window.center()
        }
        if window.contentLayoutRect.width < 820 || window.contentLayoutRect.height < 440 {
            window.setContentSize(NSSize(width: 920, height: 450))
            window.center()
        }
        window.setFrameAutosaveName(frameName)
        return window
    }

    private func present(window: NSWindow) {
        let application = NSApplication.shared
        application.unhide(nil)
        application.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
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
            ? "Codex 本周额度剩余 \(remaining)%，数据已过期"
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
        return "bolt.fill"
    }
}
