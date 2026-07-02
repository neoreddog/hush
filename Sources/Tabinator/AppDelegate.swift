import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = ThrottleController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "gauge.with.dots.needle.33percent",
            accessibilityDescription: "Tabinator"
        )
        statusItem.menu = buildMenu()

        controller.onStatusChange = { [weak self] in self?.refreshMenu() }
        controller.start()

        installSignalCleanup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        status.tag = MenuTag.status
        menu.addItem(status)
        menu.addItem(.separator())

        let limitItem = NSMenuItem(title: "CPU Limit", action: nil, keyEquivalent: "")
        let limitMenu = NSMenu()
        for percent in [5, 10, 20, 30, 40, 50, 75] {
            let item = NSMenuItem(
                title: "\(percent)%",
                action: #selector(setLimit(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = percent
            item.state = percent == Settings.cpuLimitPercent ? .on : .off
            limitMenu.addItem(item)
        }
        limitItem.submenu = limitMenu
        limitItem.tag = MenuTag.limit
        menu.addItem(limitItem)

        let login = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.tag = MenuTag.login
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Tabinator", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private enum MenuTag {
        static let status = 1
        static let limit = 2
        static let login = 3
    }

    private func statusText() -> String {
        let pids = controller.throttlers.keys.sorted()
        if pids.isEmpty {
            return "Watching for \u{201C}\(Settings.targetProcessName)\u{201D}"
        }
        let list = pids.map(String.init).joined(separator: ", ")
        return "Throttling PID \(list) to \(Settings.cpuLimitPercent)%"
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        menu.item(withTag: MenuTag.status)?.title = statusText()
        if let limitMenu = menu.item(withTag: MenuTag.limit)?.submenu {
            for item in limitMenu.items {
                item.state = item.tag == Settings.cpuLimitPercent ? .on : .off
            }
        }
        statusItem.button?.image = NSImage(
            systemSymbolName: controller.throttlers.isEmpty
                ? "gauge.with.dots.needle.33percent"
                : "gauge.with.dots.needle.67percent",
            accessibilityDescription: "Tabinator"
        )
    }

    // MARK: - Actions

    @objc private func setLimit(_ sender: NSMenuItem) {
        Settings.cpuLimitPercent = sender.tag
        controller.limitChanged()
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nNote: this only works when running from the built Tabinator.app bundle."
            alert.runModal()
        }
        sender.state = service.status == .enabled ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Cleanup on kill

    /// Ensure a SIGTERM/SIGINT (e.g. `kill`, logout) still resumes any
    /// process we currently have stopped.
    private func installSignalCleanup() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.controller.stop()
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private var signalSources: [DispatchSourceSignal] = []
}
