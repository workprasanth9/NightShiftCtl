import CBlueLight
import Foundation

public enum NightShiftError: Error, CustomStringConvertible {
    case unavailable
    case unsupported
    case operationFailed(String)

    public var description: String {
        switch self {
        case .unavailable:
            return "CoreBrightness or CBBlueLightClient could not be loaded on this Mac."
        case .unsupported:
            return "This Mac does not support Night Shift."
        case .operationFailed(let what):
            return "CoreBrightness refused the request: \(what)."
        }
    }
}

/// Thin Swift wrapper around the private CBBlueLightClient.
public struct NightShift {
    public init() throws {
        guard nsc_load() else { throw NightShiftError.unavailable }
        guard nsc_supported() else { throw NightShiftError.unsupported }
    }

    public func status() throws -> NightShiftStatus {
        var raw = NSCStatus()
        guard nsc_get_status(&raw) else { throw NightShiftError.operationFailed("read status") }
        var strength: Float = 0
        _ = nsc_get_strength(&strength)
        return NightShiftStatus(
            enabled: raw.enabled,
            active: raw.active,
            available: raw.available,
            sunSchedulePermitted: raw.sunSchedulePermitted,
            mode: raw.mode,
            from: ClockTime(hour: Int(raw.fromHour), minute: Int(raw.fromMinute)),
            to: ClockTime(hour: Int(raw.toHour), minute: Int(raw.toMinute)),
            strength: Strength.toPercent(strength),
            disableFlags: raw.disableFlags
        )
    }

    public func setEnabled(_ enabled: Bool) throws {
        guard nsc_set_enabled(enabled) else {
            throw NightShiftError.operationFailed(enabled ? "turn on" : "turn off")
        }
    }

    @discardableResult
    public func toggle() throws -> Bool {
        let next = !(try status().enabled)
        try setEnabled(next)
        return next
    }

    public func setStrength(_ percent: Int) throws {
        guard nsc_set_strength(Strength.toFloat(percent)) else {
            throw NightShiftError.operationFailed("set strength")
        }
    }

    public func setSchedule(_ schedule: ScheduleMode) throws {
        if case .custom(let from, let to) = schedule {
            guard nsc_set_schedule(Int32(from.hour), Int32(from.minute),
                                   Int32(to.hour), Int32(to.minute)) else {
                throw NightShiftError.operationFailed("set custom schedule")
            }
        }
        guard nsc_set_mode(schedule.rawMode) else {
            throw NightShiftError.operationFailed("set schedule mode")
        }
    }

    public static func trueTone() -> TrueToneStatus? {
        var supported = false, available = false, enabled = false
        guard nsc_truetone_status(&supported, &available, &enabled) else { return nil }
        return TrueToneStatus(supported: supported, available: available, enabled: enabled)
    }
}
