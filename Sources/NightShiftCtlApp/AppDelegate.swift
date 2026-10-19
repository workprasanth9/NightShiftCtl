import AppKit
import NightShiftKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let keepAwake = KeepAwake()
    private var nightShift: NightShift?
    private var publicIP: String?
    private var fetchingPublicIP = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        nightShift = try? NightShift()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        keepAwake.onChange = { [weak self] in self?.updateIcon() }
        updateIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keepAwake.stop(notify: false)
    }

    // MARK: Icon

    private func updateIcon() {
        let enabled = (try? nightShift?.status().enabled) ?? false
        let name: String
        if keepAwake.isActive { name = enabled ? "moon.zzz.fill" : "moon.zzz" }
        else { name = enabled ? "moon.stars.fill" : "moon.stars" }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "NightShiftCtl")
            ?? NSImage(systemSymbolName: "moon", accessibilityDescription: "NightShiftCtl")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "NightShiftCtl"
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        addNightShiftSection()
        menu.addItem(.separator())
        addKeepAwakeSection()
        menu.addItem(.separator())
        addToggleSection()
        menu.addItem(.separator())
        addActionsSection()
        menu.addItem(.separator())
        addNetworkSection()
        menu.addItem(.separator())
        addAppSection()
    }

    private func header(_ title: String) {
        if #available(macOS 14.0, *) {
            menu.addItem(.sectionHeader(title: title))
        } else {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    @discardableResult
    private func item(_ title: String, _ action: Selector?, key: String = "",
                      state: Bool? = nil, to target: NSMenu? = nil, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled && action != nil
        if let state { item.state = state ? .on : .off }
        (target ?? menu).addItem(item)
        return item
    }

    // MARK: Night Shift

    private func addNightShiftSection() {
        header("Night Shift")
        guard let ns = nightShift, let status = try? ns.status() else {
            item("Night Shift is not available on this Mac", nil, enabled: false)
            return
        }
        item("Night Shift", #selector(toggleNightShift), key: "n", state: status.enabled)

        let sliderItem = NSMenuItem()
        sliderItem.view = StrengthSliderView(value: status.strength) { [weak self] value in
            try? self?.nightShift?.setStrength(value)
        }
        menu.addItem(sliderItem)

        let scheduleItem = item("Schedule: \(scheduleTitle(status.schedule))", #selector(noop))
        let sub = NSMenu()
        sub.autoenablesItems = false
        item("Off", #selector(scheduleOff), state: status.schedule == .off, to: sub)
        item("Sunset to Sunrise", #selector(scheduleSunset), state: status.schedule == .sunsetToSunrise,
             to: sub, enabled: status.sunSchedulePermitted)
        let from = status.from?.description ?? "22:00"
        let to = status.to?.description ?? "07:00"
        var isCustom = false
        if case .custom = status.schedule { isCustom = true }
        item("Custom (\(from) to \(to))", #selector(scheduleCustomCurrent), state: isCustom, to: sub)
        sub.addItem(.separator())
        item("Set Custom Times...", #selector(scheduleCustomEdit), to: sub)
        scheduleItem.submenu = sub

        if let tt = NightShift.trueTone() {
            let text = tt.supported ? (tt.enabled ? "On" : "Off") : "Not supported"
            item("True Tone: \(text)", nil, enabled: false)
        }
    }

    private func scheduleTitle(_ schedule: ScheduleMode) -> String {
        switch schedule {
        case .off: return "Off"
        case .sunsetToSunrise: return "Sunset to Sunrise"
        case .custom(let from, let to): return "\(from) to \(to)"
        }
    }

    @objc private func noop() {}

    @objc private func toggleNightShift() {
        _ = try? nightShift?.toggle()
        updateIcon()
    }

    @objc private func scheduleOff() { try? nightShift?.setSchedule(.off) }
    @objc private func scheduleSunset() { try? nightShift?.setSchedule(.sunsetToSunrise) }

    @objc private func scheduleCustomCurrent() {
        guard let status = try? nightShift?.status() else { return }
        let from = status.from ?? ClockTime(hour: 22, minute: 0)!
        let to = status.to ?? ClockTime(hour: 7, minute: 0)!
        try? nightShift?.setSchedule(.custom(from: from, to: to))
    }

    @objc private func scheduleCustomEdit() {
        guard let status = try? nightShift?.status() else { return }
        let calendar = Calendar.current
        func date(_ t: ClockTime?) -> Date {
            calendar.date(bySettingHour: t?.hour ?? 22, minute: t?.minute ?? 0, second: 0, of: Date()) ?? Date()
        }
        func picker(_ value: Date) -> NSDatePicker {
            let p = NSDatePicker()
            p.datePickerStyle = .textFieldAndStepper
            p.datePickerElements = .hourMinute
            p.dateValue = value
            p.sizeToFit()
            return p
        }
        let fromPicker = picker(date(status.from))
        let toPicker = picker(date(status.to ?? ClockTime(hour: 7, minute: 0)))
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "From:"), fromPicker],
            [NSTextField(labelWithString: "To:"), toPicker],
        ])
        grid.rowSpacing = 8
        grid.frame = NSRect(x: 0, y: 0, width: 220, height: 60)

        let alert = NSAlert()
        alert.messageText = "Custom Night Shift Schedule"
        alert.informativeText = "Night Shift turns on and off automatically at these times."
        alert.accessoryView = grid
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let f = calendar.dateComponents([.hour, .minute], from: fromPicker.dateValue)
        let t = calendar.dateComponents([.hour, .minute], from: toPicker.dateValue)
        guard let from = ClockTime(hour: f.hour ?? 22, minute: f.minute ?? 0),
              let to = ClockTime(hour: t.hour ?? 7, minute: t.minute ?? 0), from != to else {
            showError("Start and end times must be different.")
            return
        }
        try? nightShift?.setSchedule(.custom(from: from, to: to))
    }

    // MARK: Keep Awake

    private static let durations: [(String, TimeInterval?)] = [
        ("15 Minutes", 15 * 60), ("30 Minutes", 30 * 60), ("1 Hour", 3600),
        ("2 Hours", 2 * 3600), ("4 Hours", 4 * 3600), ("8 Hours", 8 * 3600),
        ("Until Turned Off", nil),
    ]

    private func addKeepAwakeSection() {
        header("Keep Awake")
        let main = item("Keep Awake: \(keepAwake.statusText)", #selector(noop), state: keepAwake.isActive)
        let sub = NSMenu()
        sub.autoenablesItems = false
        for (index, entry) in Self.durations.enumerated() {
            let i = item(entry.0, #selector(startKeepAwake(_:)), to: sub)
            i.tag = index
        }
        sub.addItem(.separator())
        item("Turn Off", #selector(stopKeepAwake), to: sub, enabled: keepAwake.isActive)
        main.submenu = sub
    }

    @objc private func startKeepAwake(_ sender: NSMenuItem) {
        guard Self.durations.indices.contains(sender.tag) else { return }
        if !keepAwake.start(duration: Self.durations[sender.tag].1) {
            showError("macOS did not allow the Keep Awake assertion.")
        }
    }

    @objc private func stopKeepAwake() { keepAwake.stop() }

    // MARK: Toggles

    private func addToggleSection() {
        header("Toggles")
        item("Dark Mode", #selector(toggleDarkMode), state: SystemActions.isDarkMode)
        item("Hide Desktop Icons", #selector(toggleDesktopIcons), state: !SystemActions.desktopIconsVisible)
        item("Show Hidden Files in Finder", #selector(toggleHiddenFiles), state: SystemActions.hiddenFilesVisible)
    }

    @objc private func toggleDarkMode() {
        if let error = SystemActions.setDarkMode(!SystemActions.isDarkMode) {
            showError("Could not change Dark Mode. Allow NightShiftCtl to control System Events in System Settings > Privacy & Security > Automation.\n\n\(error)")
        }
    }

    @objc private func toggleDesktopIcons() {
        SystemActions.setDesktopIconsVisible(!SystemActions.desktopIconsVisible)
    }

    @objc private func toggleHiddenFiles() {
        SystemActions.setHiddenFilesVisible(!SystemActions.hiddenFilesVisible)
    }

    // MARK: Actions

    private func addActionsSection() {
        header("Actions")
        item("Lock Screen", #selector(lockScreen), key: "l")
        item("Empty Trash...", #selector(emptyTrash))
        item("Flush DNS Cache...", #selector(flushDNS))
    }

    @objc private func lockScreen() { SystemActions.lockScreen() }

    @objc private func emptyTrash() {
        let alert = NSAlert()
        alert.messageText = "Empty the Trash?"
        alert.informativeText = "All items in the Trash will be permanently deleted. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let error = SystemActions.emptyTrash() {
            showError("Could not empty the Trash. Allow NightShiftCtl to control Finder in System Settings > Privacy & Security > Automation.\n\n\(error)")
        }
    }

    @objc private func flushDNS() {
        NSApp.activate(ignoringOtherApps: true)
        if let error = SystemActions.flushDNS() {
            showError("Could not flush the DNS cache.\n\n\(error)")
        } else {
            notify("DNS cache flushed.")
        }
    }

    // MARK: Network

    private func addNetworkSection() {
        header("Network")
        let addresses = Network.localAddresses()
        if addresses.isEmpty {
            item("No network connection", nil, enabled: false)
        }
        for entry in addresses {
            let i = item("\(entry.interface): \(entry.address)", #selector(copyTitleValue(_:)))
            i.representedObject = entry.address
            i.toolTip = "Click to copy"
        }
        if let ip = publicIP {
            let i = item("Public: \(ip)", #selector(copyTitleValue(_:)))
            i.representedObject = ip
            i.toolTip = "Click to copy"
        } else {
            item(fetchingPublicIP ? "Looking up public IP..." : "Show Public IP", #selector(lookUpPublicIP),
                 enabled: !fetchingPublicIP)
        }
    }

    @objc private func copyTitleValue(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        SystemActions.copyToPasteboard(value)
    }

    @objc private func lookUpPublicIP() {
        fetchingPublicIP = true
        Network.fetchPublicIP { [weak self] ip in
            guard let self else { return }
            self.fetchingPublicIP = false
            if let ip {
                self.publicIP = ip
                SystemActions.copyToPasteboard(ip)
                self.notify("Public IP \(ip) copied to the clipboard.")
            } else {
                self.showError("Could not look up the public IP address.")
            }
        }
    }

    // MARK: App

    private func addAppSection() {
        if LoginItem.isSupported {
            item("Launch at Login", #selector(toggleLaunchAtLogin), state: LoginItem.isEnabled)
        }
        item("Night Shift Settings...", #selector(openDisplaySettings))
        item("About NightShiftCtl", #selector(showAbout))
        item("Quit NightShiftCtl", #selector(quit), key: "q")
    }

    @objc private func toggleLaunchAtLogin() {
        if let error = LoginItem.setEnabled(!LoginItem.isEnabled) {
            showError("Could not change Launch at Login.\n\n\(error)")
        }
    }

    @objc private func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: NightShiftCtlVersion.current,
            .credits: NSAttributedString(string: "Open source under the MIT license.\ngithub.com/workprasanth9/NightShiftCtl"),
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Feedback

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "NightShiftCtl"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func notify(_ message: String) {
        statusItem.button?.toolTip = message
        let alert = NSAlert()
        alert.messageText = "NightShiftCtl"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

/// Menu row with a label and a continuous slider for Night Shift strength.
final class StrengthSliderView: NSView {
    private let slider: NSSlider
    private let valueLabel = NSTextField(labelWithString: "")
    private let onChange: (Int) -> Void

    init(value: Int, onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        slider = NSSlider(value: Double(value), minValue: 0, maxValue: 100, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

        let label = NSTextField(labelWithString: "Warmth")
        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.stringValue = "\(value)"

        slider.target = self
        slider.action = #selector(changed)
        slider.isContinuous = true

        for view in [label, slider, valueLabel] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 6),
            valueLabel.widthAnchor.constraint(equalToConstant: 28),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func changed() {
        let value = Int(slider.doubleValue.rounded())
        valueLabel.stringValue = "\(value)"
        onChange(value)
    }
}
