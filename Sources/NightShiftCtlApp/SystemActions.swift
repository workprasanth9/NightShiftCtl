import AppKit
import Foundation

/// Mac toggles and actions. Each one prefers a direct method that needs no
/// permission prompt, and falls back to Apple events only when it has to.
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

    /// Runs AppleScript and returns an error message on failure (nil on success or cancel).
    static func appleScript(_ source: String) -> String? {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return nil }
        let number = error[NSAppleScript.errorNumber] as? Int ?? 0
        if number == -128 { return nil } // user cancelled
        let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
        if number == -1743 {
            return "\(message)\n\nOpen System Settings > Privacy & Security > Automation and turn on the switch for NightShiftCtl."
        }
        return message
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

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private typealias GetTheme = @convention(c) () -> Bool
    private typealias SetTheme = @convention(c) (Bool) -> Void

    private static var getTheme: GetTheme? {
        guard let skyLight, let sym = dlsym(skyLight, "SLSGetAppearanceThemeLegacy") else { return nil }
        return unsafeBitCast(sym, to: GetTheme.self)
    }

    private static var setTheme: SetTheme? {
        guard let skyLight else { return nil }
        let sym = dlsym(skyLight, "SLSSetAppearanceThemeNotifying") ?? dlsym(skyLight, "SLSSetAppearanceThemeLegacy")
        guard let sym else { return nil }
        return unsafeBitCast(sym, to: SetTheme.self)
    }

    /// True when Dark Mode can change without any permission prompt.
    static var canSetDarkModeDirectly: Bool { getTheme != nil && setTheme != nil }

    static var isDarkMode: Bool {
        if let getTheme { return getTheme() }
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// Uses the same window server call as the Appearance setting in System
    /// Settings, which applies instantly and needs no permission. Falls back to
    /// System Events (Automation prompt) if that call is not available.
    static func setDarkMode(_ dark: Bool) -> String? {
        if let setTheme {
            setTheme(dark)
            return nil
        }
        return appleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)")
    }

    // MARK: Finder

    static var desktopIconsVisible: Bool { finderBool("CreateDesktop", default: true) }
    static func setDesktopIconsVisible(_ visible: Bool) { setFinderBool("CreateDesktop", visible) }

    static var hiddenFilesVisible: Bool { finderBool("AppleShowAllFiles", default: false) }
    static func setHiddenFilesVisible(_ visible: Bool) { setFinderBool("AppleShowAllFiles", visible) }

    // MARK: Trash

    enum TrashResult: Equatable {
        case emptied(Int)
        case alreadyEmpty
        case failed(String)
    }

    static var trashURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Returns the number of items in the Trash, or nil when macOS does not let
    /// the app read the folder (it is privacy protected on recent macOS).
    static func trashItemCount() -> Int? {
        try? FileManager.default.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil).count
    }

    /// Empties the Trash directly with FileManager. If macOS blocks access to
    /// ~/.Trash, asks Finder instead (one time Automation prompt).
    static func emptyTrash() -> TrashResult {
        let fm = FileManager.default
        let items: [URL]
        do {
            items = try fm.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
        } catch {
            return emptyTrashWithFinder()
        }
        if items.isEmpty { return .alreadyEmpty }
        var removed = 0
        var failures: [String] = []
        for item in items {
            do {
                try fm.removeItem(at: item)
                removed += 1
            } catch {
                failures.append(item.lastPathComponent)
            }
        }
        if failures.isEmpty { return .emptied(removed) }
        // Locked or protected items: let Finder try the rest.
        if case .failed(let message) = emptyTrashWithFinder() {
            return .failed("Some items could not be deleted (\(failures.prefix(3).joined(separator: ", "))).\n\n\(message)")
        }
        return .emptied(items.count)
    }

    private static func emptyTrashWithFinder() -> TrashResult {
        if let error = appleScript("tell application \"Finder\" to empty trash") {
            return .failed(error)
        }
        return .emptied(0)
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
    /// `do shell script` runs inside the app, so no Automation permission is needed.
    static func flushDNS() -> String? {
        appleScript("do shell script \"/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder\" with administrator privileges")
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func openURL(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
