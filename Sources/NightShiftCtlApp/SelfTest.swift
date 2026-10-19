import AppKit
import NightShiftKit

/// `NightShiftCtl --self-test` prints what the app can see, without changing anything.
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
        print("Dark Mode: \(SystemActions.isDarkMode)")
        print("Desktop icons visible: \(SystemActions.desktopIconsVisible)")
        print("Hidden files visible: \(SystemActions.hiddenFilesVisible)")
        print("Direct screen lock available: \(SystemActions.canLockDirectly)")
        print("Launch at login supported: \(LoginItem.isSupported), enabled: \(LoginItem.isEnabled)")
        for entry in Network.localAddresses() {
            print("IP \(entry.interface): \(entry.address)")
        }
        let keepAwake = KeepAwake()
        let started = keepAwake.start(duration: 5)
        print("Keep Awake assertion: \(started ? "ok" : "failed")")
        keepAwake.stop()
    }
}
