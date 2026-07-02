import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var headerView: MenuHeaderView!
    private var sliderView: AllowanceSliderView!
    private var themeRowViews: [ThemeMenuRowView] = []
    private var themedTitleItems: [NSMenuItem] = []
    private let controller = ThrottleController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Fixed length so the menu bar doesn't reflow when the glyph
        // swaps between the static image and the live bars.
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
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

        headerView = MenuHeaderView()
        let headerItem = NSMenuItem()
        headerItem.view = headerView
        menu.addItem(headerItem)
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

        // Theme ▸ Hush on Ink / Mist / Plum, as a submenu. Each row is a
        // custom view rather than a plain action item, so clicking one
        // applies the theme live and leaves the submenu open — you can
        // flip through Ink/Mist/Plum without reopening the menu each time.
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        themeRowViews = []
        for theme in Brand.Theme.allCases {
            let row = ThemeMenuRowView(theme: theme) { [weak self] theme in
                guard let self else { return }
                Settings.theme = theme
                // Sets the appearance for the *next* time the menu opens —
                // an already-open NSMenu freezes its appearance for the
                // duration of tracking, so this alone won't repaint
                // anything live. The wash, headline, and slider tint are
                // applied directly below instead, since we own those colors.
                self.statusItem.menu?.appearance = theme.appearance
                self.headerView.applyTheme()
                self.sliderView.applyTheme()
                for row in self.themeRowViews { row.refresh() }
                self.restyleThemedTitles()
            }
            themeRowViews.append(row)
            let item = NSMenuItem()
            item.view = row
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Advanced ▸ Watched Process / Start at Login
        let advancedItem = NSMenuItem(title: "Advanced", action: nil, keyEquivalent: "")
        let advancedMenu = NSMenu()

        let targetItem = NSMenuItem(title: "Watched Process", action: nil, keyEquivalent: "")
        let targetMenu = NSMenu()
        targetMenu.delegate = self
        targetItem.submenu = targetMenu
        advancedMenu.addItem(targetItem)

        let animate = NSMenuItem(
            title: "Animate While Hushing",
            action: #selector(toggleMenuBarAnimation(_:)),
            keyEquivalent: ""
        )
        animate.target = self
        animate.state = Settings.menuBarAnimationEnabled ? .on : .off
        advancedMenu.addItem(animate)

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

        themedTitleItems = [themeItem, advancedItem, quit]
        restyleThemedTitles()

        menu.appearance = Settings.theme.appearance
        return menu
    }

    /// Native NSMenuItems draw their title in whatever color the system
    /// appearance dictates, and — like the header/slider colors — that's
    /// frozen for as long as the menu is tracking. Giving each an
    /// attributedTitle with an explicit color lets them repaint immediately
    /// when a theme is picked from the still-open submenu.
    private func restyleThemedTitles() {
        let color = Settings.theme.itemTextColor
        for item in themedTitleItems {
            item.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.font: NSFont.menuFont(ofSize: NSFont.systemFontSize), .foregroundColor: color]
            )
        }
    }

    /// Status copy speaks in outcomes, never mechanisms — no CPU, no
    /// processes, nothing alarmed.
    private var statusCopy: (headline: String, sub: String) {
        let target = Settings.targetProcessName
        if controller.throttlers.isEmpty {
            return ("All quiet right now.", "Hushing \(target).")
        }
        return ("Cooling things down.", "Hushing \(target).")
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        let copy = statusCopy

        headerView.update(headline: copy.headline, sub: copy.sub)

        sliderView.refresh()
        for row in themeRowViews { row.refresh() }

        statusItem.button?.toolTip = "Hush — \(copy.headline)"
        setIconAnimating(!controller.throttlers.isEmpty)
    }

    /// While actively hushing, the glyph becomes the live settling-bars
    /// animation from the brand guidelines; idle shows the static template
    /// dots. Reduced-motion users get the static active glyph instead.
    private func setIconAnimating(_ active: Bool) {
        guard let button = statusItem.button else { return }

        if active,
           Settings.menuBarAnimationEnabled,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            guard barsView == nil else { return }
            button.image = nil
            let bars = SettlingBarsView(frame: button.bounds)
            bars.autoresizingMask = [.width, .height]
            button.addSubview(bars)
            barsView = bars
        } else {
            barsView?.removeFromSuperview()
            barsView = nil
            button.image = active ? Brand.menuBarActive : Brand.menuBarIdle
        }
    }

    private var barsView: SettlingBarsView?

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

    @objc private func toggleMenuBarAnimation(_ sender: NSMenuItem) {
        Settings.menuBarAnimationEnabled.toggle()
        sender.state = Settings.menuBarAnimationEnabled ? .on : .off
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
