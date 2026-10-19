import Foundation

/// A wall clock time used by the Night Shift schedule.
public struct ClockTime: Equatable, CustomStringConvertible, Sendable {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Parses "HH:MM", "H:MM", "HHMM" or "H" (24 hour clock), plus an optional
    /// "am"/"pm" suffix such as "10pm" or "7:30am".
    public init?(parsing text: String) {
        var s = text.trimmingCharacters(in: .whitespaces).lowercased()
        var meridiem: String?
        for suffix in ["am", "pm"] where s.hasSuffix(suffix) {
            meridiem = suffix
            s = String(s.dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        var hourText = s
        var minuteText = "0"
        if let colon = s.firstIndex(of: ":") {
            hourText = String(s[..<colon])
            minuteText = String(s[s.index(after: colon)...])
            guard minuteText.count == 2 else { return nil }
        } else if s.count == 4, meridiem == nil {
            hourText = String(s.prefix(2))
            minuteText = String(s.suffix(2))
        }
        guard !hourText.isEmpty, hourText.count <= 2,
              hourText.allSatisfy(\.isNumber), minuteText.allSatisfy(\.isNumber),
              var hour = Int(hourText), let minute = Int(minuteText) else { return nil }
        if let meridiem {
            guard (1...12).contains(hour) else { return nil }
            if meridiem == "am" { hour = hour == 12 ? 0 : hour }
            else { hour = hour == 12 ? 12 : hour + 12 }
        }
        self.init(hour: hour, minute: minute)
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }
}

/// How Night Shift is scheduled.
public enum ScheduleMode: Equatable, Sendable {
    case off
    case sunsetToSunrise
    case custom(from: ClockTime, to: ClockTime)

    public var rawMode: Int32 {
        switch self {
        case .off: return 0
        case .sunsetToSunrise: return 1
        case .custom: return 2
        }
    }

    public var label: String {
        switch self {
        case .off: return "off"
        case .sunsetToSunrise: return "sunset-to-sunrise"
        case .custom(let from, let to): return "custom \(from)-\(to)"
        }
    }
}

/// A snapshot of the current Night Shift state.
public struct NightShiftStatus: Equatable, Sendable {
    public var enabled: Bool
    public var active: Bool
    public var available: Bool
    public var sunSchedulePermitted: Bool
    public var mode: Int32
    public var from: ClockTime?
    public var to: ClockTime?
    /// Warmth from 0 to 100.
    public var strength: Int
    public var disableFlags: UInt64

    public var schedule: ScheduleMode {
        switch mode {
        case 1: return .sunsetToSunrise
        case 2:
            if let from, let to { return .custom(from: from, to: to) }
            return .off
        default: return .off
        }
    }
}

/// True Tone state (read only).
public struct TrueToneStatus: Equatable, Sendable {
    public var supported: Bool
    public var available: Bool
    public var enabled: Bool
}

/// Converts a user facing strength (0 to 100) to the 0.0 to 1.0 float CoreBrightness uses.
public enum Strength {
    public static func parse(_ text: String) -> Int? {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasSuffix("%") { s.removeLast() }
        guard let value = Int(s), (0...100).contains(value) else { return nil }
        return value
    }

    public static func toFloat(_ percent: Int) -> Float {
        Float(min(max(percent, 0), 100)) / 100.0
    }

    public static func toPercent(_ value: Float) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }
}
