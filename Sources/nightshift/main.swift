import Foundation
import NightShiftKit

let version = NightShiftCtlVersion.current

let usage = """
nightshift \(version): control macOS Night Shift from the command line

USAGE:
  nightshift status [--json]          Show Night Shift state, strength and schedule
  nightshift on                       Turn Night Shift on now
  nightshift off                      Turn Night Shift off now
  nightshift toggle                   Flip the current state
  nightshift strength [0-100]         Show or set the color temperature warmth
  nightshift schedule                 Show the current schedule
  nightshift schedule sunset          Schedule from sunset to sunrise
  nightshift schedule <from> <to>     Custom schedule, for example 22:00 07:00 or 10pm 7am
  nightshift schedule off             Disable the schedule
  nightshift truetone [--json]        Show True Tone status (read only)
  nightshift version                  Print the version
  nightshift help                     Show this help

Settings apply to the user running the command. Run it as the logged in user.
"""

enum ExitCode: Int32 { case ok = 0, failure = 1, usage = 2 }

func fail(_ message: String, _ code: ExitCode = .failure) -> Never {
    FileHandle.standardError.write(Data(("nightshift: " + message + "\n").utf8))
    exit(code.rawValue)
}

func jsonString(_ dict: [String: Any]) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

func printStatus(_ s: NightShiftStatus, json: Bool) {
    if json {
        var dict: [String: Any] = [
            "enabled": s.enabled,
            "strength": s.strength,
            "schedule": s.schedule.label,
            "sunSchedulePermitted": s.sunSchedulePermitted,
        ]
        if case .custom(let from, let to) = s.schedule {
            dict["from"] = from.description
            dict["to"] = to.description
        }
        print(jsonString(dict))
        return
    }
    print("Night Shift: \(s.enabled ? "on" : "off")")
    print("Strength:    \(s.strength)")
    print("Schedule:    \(s.schedule.label)")
}

func printSchedule(_ s: NightShiftStatus) {
    switch s.schedule {
    case .off: print("Schedule: off")
    case .sunsetToSunrise: print("Schedule: sunset to sunrise")
    case .custom(let from, let to): print("Schedule: custom, \(from) to \(to)")
    }
}

func client() -> NightShift {
    do { return try NightShift() } catch { fail("\(error)") }
}

func run(_ args: [String]) {
    guard let command = args.first?.lowercased() else {
        print(usage)
        return
    }
    let rest = Array(args.dropFirst())
    let json = rest.contains("--json")

    do {
        switch command {
        case "help", "-h", "--help":
            print(usage)
        case "version", "-v", "--version":
            print(version)
        case "status":
            printStatus(try client().status(), json: json)
        case "on", "enable":
            try client().setEnabled(true)
            print("Night Shift: on")
        case "off", "disable":
            try client().setEnabled(false)
            print("Night Shift: off")
        case "toggle":
            let now = try client().toggle()
            print("Night Shift: \(now ? "on" : "off")")
        case "strength", "temp", "temperature":
            let ns = client()
            if let value = rest.first {
                guard let percent = Strength.parse(value) else {
                    fail("strength must be a whole number from 0 to 100", .usage)
                }
                try ns.setStrength(percent)
                print("Strength: \(percent)")
            } else {
                print("Strength: \(try ns.status().strength)")
            }
        case "schedule":
            let ns = client()
            guard let sub = rest.first?.lowercased() else {
                printSchedule(try ns.status())
                return
            }
            let schedule: ScheduleMode
            switch sub {
            case "off", "none", "disable":
                schedule = .off
            case "sunset", "sun", "sunset-to-sunrise", "auto":
                guard try ns.status().sunSchedulePermitted else {
                    fail("sunset to sunrise needs Location Services enabled for System Services > Setting time zone")
                }
                schedule = .sunsetToSunrise
            case "custom":
                guard rest.count >= 3 else { fail("usage: nightshift schedule custom <from> <to>", .usage) }
                schedule = try parseCustom(rest[1], rest[2])
            default:
                guard rest.count >= 2 else { fail("usage: nightshift schedule <from> <to>", .usage) }
                schedule = try parseCustom(rest[0], rest[1])
            }
            try ns.setSchedule(schedule)
            printSchedule(try ns.status())
        case "truetone", "true-tone":
            guard let tt = NightShift.trueTone() else { fail("True Tone status is not available on this Mac") }
            if json {
                print(jsonString(["supported": tt.supported, "available": tt.available, "enabled": tt.enabled]))
            } else {
                print("True Tone: \(tt.supported ? (tt.enabled ? "on" : "off") : "not supported")")
            }
        default:
            fail("unknown command '\(command)'. Run 'nightshift help'.", .usage)
        }
    } catch {
        fail("\(error)")
    }
}

func parseCustom(_ fromText: String, _ toText: String) throws -> ScheduleMode {
    guard let from = ClockTime(parsing: fromText) else { fail("could not read time '\(fromText)'", .usage) }
    guard let to = ClockTime(parsing: toText) else { fail("could not read time '\(toText)'", .usage) }
    guard from != to else { fail("start and end times must differ", .usage) }
    return .custom(from: from, to: to)
}

run(Array(CommandLine.arguments.dropFirst()))
