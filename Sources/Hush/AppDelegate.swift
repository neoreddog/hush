import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var sliderView: AllowanceSliderView!
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

        let sub = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        sub.isEnabled = false
        sub.tag = MenuTag.statusSub
        menu.addItem(sub)
        menu.addItem(.separator())

        sliderView = AllowanceSliderView { [weak self] percent in
            Settings.cpuLimitPercent = percent
            self?.controller.limitChanged()
            self?.refreshMenu()
        }
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        // Advanced ▸ Watched Process / Start at Login
        let advancedItem = NSMenuItem(title: "Advanced", action: nil, keyEquivalent: "")
        let advancedMenu = NSMenu()

        let targetItem = NSMenuItem(title: "Watched Process", action: nil, keyEquivalent: "")
        let targetMenu = NSMenu()
        targetMenu.delegate = self
        targetItem.submenu = targetMenu
        advancedMenu.addItem(targetItem)

        let login = NSMenuItem(
            title: "Start Automatically at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        advancedMenu.addItem(login)

        advancedItem.submenu = advancedMenu
        menu.addItem(advancedItem)

        let quit = NSMenuItem(title: "Quit Hush", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private enum MenuTag {
        static let status = 1
        static let statusSub = 2
    }

    /// Status copy speaks in outcomes, never mechanisms — no CPU, no
    /// processes, nothing alarmed.
    private var statusCopy: (headline: String, sub: String) {
        if controller.throttlers.isEmpty {
            return ("All quiet.", "Nothing running hot right now.")
        }
        return ("Working on it.", "Something was working overtime. Hush is keeping it settled.")
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        let copy = statusCopy

        menu.item(withTag: MenuTag.status)?.attributedTitle = NSAttributedString(
            string: copy.headline,
            attributes: [.font: Brand.display(ofSize: 19), .foregroundColor: NSColor.labelColor]
        )
        menu.item(withTag: MenuTag.statusSub)?.attributedTitle = NSAttributedString(
            string: copy.sub,
            attributes: [
                .font: NSFont.menuFont(ofSize: NSFont.systemFontSize(for: .small)),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )

        sliderView.refresh()

        let active = !controller.throttlers.isEmpty
        statusItem.button?.image = active ? Brand.menuBarActive : Brand.menuBarIdle
        statusItem.button?.toolTip = "Hush — \(copy.headline)"
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
            alert.messageText = "Hush couldn't set itself to start at login."
            alert.informativeText = "\(error.localizedDescription)\n\nThis works once Hush is in the Applications folder."
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
