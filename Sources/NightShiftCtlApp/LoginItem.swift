import Foundation
import ServiceManagement

/// Launch at login through SMAppService (macOS 13 and later).
enum LoginItem {
    static var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    static func setEnabled(_ enabled: Bool) -> String? {
        guard #available(macOS 13.0, *) else { return "Launch at login needs macOS 13 or later." }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
