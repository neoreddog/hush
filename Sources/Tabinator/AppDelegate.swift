import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var sliderView: CPULimitSliderView!
    private let controller = ThrottleController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = buildMenu()

        controller.onStatusChange = { [weak self] in self?.refreshMenu() }
        controller.start()
        refreshMenu()

        installSignalCleanup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        status.isEnabled = false
        status.tag = MenuTag.status
        menu.addItem(status)
        menu.addItem(.separator())

        sliderView = CPULimitSliderView { [weak self] percent in
            Settings.cpuLimitPercent = percent
            self?.controller.limitChanged()
            self?.refreshMenu()
        }
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        let login = NSMenuItem(
            title: "Start Automatically at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.tag = MenuTag.login
        menu.addItem(login)

        // Advanced ▸ Watched Process ▸ (running-process picker)
        let advancedItem = NSMenuItem(title: "Advanced", action: nil, keyEquivalent: "")
        let advancedMenu = NSMenu()
        let targetItem = NSMenuItem(title: "Watched Process", action: nil, keyEquivalent: "")
        let targetMenu = NSMenu()
        targetMenu.delegate = self
        targetItem.submenu = targetMenu
        advancedMenu.addItem(targetItem)
        advancedItem.submenu = advancedMenu
        menu.addItem(advancedItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Tabinator", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private enum MenuTag {
        static let status = 1
        static let login = 3
    }

    private func statusText() -> String {
        let name = Settings.targetProcessName
        if controller.throttlers.isEmpty {
            return "\(name) is not running"
        }
        return "Limiting \(name) to \(Settings.cpuLimitPercent)% CPU"
    }

    private func refreshMenu() {
        statusItem.menu?.item(withTag: MenuTag.status)?.title = statusText()
        sliderView.refresh()
        updateIcon()
    }

    /// Template (auto light/dark) gauge when idle; sea-green when limiting.
    private func updateIcon() {
        let active = !controller.throttlers.isEmpty
        let symbol = active ? "gauge.with.dots.needle.33percent" : "gauge.with.dots.needle.67percent"
        var image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Tabinator")
        if active {
            image = image?.withSymbolConfiguration(.init(paletteColors: [tabinatorAccent]))
            image?.isTemplate = false
        } else {
            image?.isTemplate = true
        }
        statusItem.button?.image = image
        statusItem.button?.toolTip = statusText()
    }

    // MARK: - Actions

    @objc private func setTarget(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        applyNewTarget(name)
    }

    @objc private func setCustomTarget(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Watched Process"
        alert.informativeText = "Enter the exact process name to watch for (case-insensitive)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = Settings.targetProcessName
        alert.accessoryView = field
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        applyNewTarget(name)
    }

    private func applyNewTarget(_ name: String) {
        guard name.caseInsensitiveCompare(Settings.targetProcessName) != .orderedSame else { return }
        Settings.targetProcessName = name
        controller.retarget()
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
            alert.messageText = "Could not update Start at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nNote: this only works when Tabinator is run from the Applications folder."
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

// MARK: - Watched Process submenu

extension AppDelegate: NSMenuDelegate {
    /// Rebuilds the Watched Process submenu each time it opens, listing
    /// running processes busiest-first.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let current = Settings.targetProcessName
        var listed = ProcessMonitor.runningProcessesByCPU().prefix(25).map(\.name)
        if !listed.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
            listed.insert(current, at: 0)
        }

        for name in listed {
            let item = NSMenuItem(title: name, action: #selector(setTarget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = name.caseInsensitiveCompare(current) == .orderedSame ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let other = NSMenuItem(title: "Other…", action: #selector(setCustomTarget(_:)), keyEquivalent: "")
        other.target = self
        menu.addItem(other)
    }
}
