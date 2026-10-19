import AppKit
import Foundation

/// Mac toggles and actions that use public, documented mechanisms only
/// (defaults, AppleScript, IOKit), with no special entitlements.
enum SystemActions {
    // MARK: Helpers

    @discardableResult
    static func run(_ path: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return -1 }
        task.waitUntilExit()
        return task.terminationStatus
    }

    /// Runs AppleScript and returns an error message on failure.
    static func appleScript(_ source: String) -> String? {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -128 { return nil } // user cancelled
            return error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
        }
        return nil
    }

    static func finderBool(_ key: String, default value: Bool) -> Bool {
        CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        guard let raw = CFPreferencesCopyAppValue(key as CFString, "com.apple.finder" as CFString) else {
            return value
        }
        if let b = raw as? Bool { return b }
        if let s = raw as? String { return ["1", "yes", "true"].contains(s.lowercased()) }
        if let n = raw as? NSNumber { return n.boolValue }
        return value
    }

    static func setFinderBool(_ key: String, _ value: Bool) {
        run("/usr/bin/defaults", ["write", "com.apple.finder", key, "-bool", value ? "true" : "false"])
        run("/usr/bin/killall", ["Finder"])
    }

    // MARK: Appearance

    static var isDarkMode: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// Uses System Events, the supported way to change appearance. macOS asks for
    /// Automation permission the first time.
    static func setDarkMode(_ dark: Bool) -> String? {
        appleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)")
    }

    // MARK: Finder

    static var desktopIconsVisible: Bool { finderBool("CreateDesktop", default: true) }
    static func setDesktopIconsVisible(_ visible: Bool) { setFinderBool("CreateDesktop", visible) }

    static var hiddenFilesVisible: Bool { finderBool("AppleShowAllFiles", default: false) }
    static func setHiddenFilesVisible(_ visible: Bool) { setFinderBool("AppleShowAllFiles", visible) }

    static func emptyTrash() -> String? {
        appleScript("tell application \"Finder\" to empty trash")
    }

    // MARK: Lock screen

    private typealias LockFunction = @convention(c) () -> Void

    private static var lockFunction: LockFunction? {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(symbol, to: LockFunction.self)
    }

    static var canLockDirectly: Bool { lockFunction != nil }

    /// Locks the screen the same way the Lock Screen menu item does. Falls back
    /// to sleeping the display, which locks when a password is required on wake.
    static func lockScreen() {
        if let lock = lockFunction {
            lock()
        } else {
            run("/usr/bin/pmset", ["displaysleepnow"])
        }
    }

    // MARK: Network

    /// Flushes the DNS cache. macOS shows its standard administrator prompt.
    static func flushDNS() -> String? {
        appleScript("do shell script \"/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder\" with administrator privileges")
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
