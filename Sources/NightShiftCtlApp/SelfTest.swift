import AppKit
import NightShiftKit

/// Diagnostics for support and testing.
/// `NightShiftCtl --self-test` prints what the app can see without changing anything.
/// `NightShiftCtl --run-action <name>` runs one menu action's code path from Terminal.
enum SelfTest {
    static func run() {
        print("NightShiftCtl \(NightShiftCtlVersion.current) self test (read only)")
        if let ns = try? NightShift(), let s = try? ns.status() {
            print("Night Shift: \(s.enabled ? "on" : "off"), strength \(s.strength), schedule \(s.schedule.label)")
        } else {
            print("Night Shift: unavailable")
        }
        if let tt = NightShift.trueTone() {
            print("True Tone: supported \(tt.supported), enabled \(tt.enabled)")
        } else {
            print("True Tone: unavailable")
        }
        print("Dark Mode: \(SystemActions.isDarkMode) (direct switch available: \(SystemActions.canSetDarkModeDirectly))")
        print("Desktop icons visible: \(SystemActions.desktopIconsVisible)")
        print("Hidden files visible: \(SystemActions.hiddenFilesVisible)")
        if let count = SystemActions.trashItemCount() {
            print("Trash: readable, \(count) item(s)")
        } else {
            print("Trash: not readable directly, Empty Trash will ask Finder")
        }
        print("Direct screen lock available: \(SystemActions.canLockDirectly)")
        print("Launch at login supported: \(LoginItem.isSupported), enabled: \(LoginItem.isEnabled)")
        for entry in Network.localAddresses() {
            print("IP \(entry.interface): \(entry.address)")
        }
        let keepAwake = KeepAwake()
        let started = keepAwake.start(duration: 5)
        print("Keep Awake assertion: \(started ? "ok" : "failed")")
        keepAwake.stop()
        let script = SystemActions.appleScript("do shell script \"/usr/bin/true\"")
        print("In app shell script (used by Flush DNS): \(script == nil ? "ok" : script!)")
    }

    static func runAction(_ name: String) -> Int32 {
        switch name {
        case "dark-mode":
            let before = SystemActions.isDarkMode
            if let error = SystemActions.setDarkMode(!before) { print("error: \(error)"); return 1 }
            Thread.sleep(forTimeInterval: 1)
            print("Dark Mode: \(before) -> \(SystemActions.isDarkMode)")
            return SystemActions.isDarkMode != before ? 0 : 1
        case "desktop-icons":
            let before = SystemActions.desktopIconsVisible
            SystemActions.setDesktopIconsVisible(!before)
            print("Desktop icons visible: \(before) -> \(SystemActions.desktopIconsVisible)")
            return SystemActions.desktopIconsVisible != before ? 0 : 1
        case "hidden-files":
            let before = SystemActions.hiddenFilesVisible
            SystemActions.setHiddenFilesVisible(!before)
            print("Hidden files visible: \(before) -> \(SystemActions.hiddenFilesVisible)")
            return SystemActions.hiddenFilesVisible != before ? 0 : 1
        case "trash-count":
            print(SystemActions.trashItemCount().map { "Trash: \($0) item(s)" } ?? "Trash: not readable")
            return 0
        case "public-ip":
            var done = false
            Network.fetchPublicIP { ip in print("Public IP: \(ip ?? "lookup failed")"); done = true }
            while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
            return 0
        default:
            print("Unknown action. Use dark-mode, desktop-icons, hidden-files, trash-count or public-ip.")
            return 2
        }
    }
}
