# NightShiftCtl

[![CI](https://github.com/workprasanth9/NightShiftCtl/actions/workflows/ci.yml/badge.svg)](https://github.com/workprasanth9/NightShiftCtl/actions/workflows/ci.yml)
![macOS](https://img.shields.io/badge/macOS-12%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

`nightshift` is a small, dependency free command line tool that controls macOS
Night Shift: turn it on or off, set the warmth, and manage the schedule from
Terminal, scripts, or your MDM.

## Why

Night Shift only lives in System Settings. There is no `defaults` key you can
write and no configuration profile payload for it, so Mac admins have no clean
way to set a baseline, and power users cannot script it. `nightshift` talks to
the same system service the Settings pane uses, so changes apply instantly and
stick.

## Features

- `on`, `off`, `toggle` Night Shift instantly
- Read or set the color temperature strength from 0 to 100
- Schedule: sunset to sunrise, custom times (`22:00 07:00` or `10pm 7am`), or off
- `status` in plain text or `--json` for scripts and inventory
- Read only True Tone status
- Ready to use Jamf Pro extension attribute and policy scripts
- Single small binary with no dependencies, Apple Silicon and Intel

## Install

### From source

```bash
git clone https://github.com/workprasanth9/NightShiftCtl.git
cd NightShiftCtl
swift build -c release
sudo install -m 755 "$(swift build -c release --show-bin-path)/nightshift" /usr/local/bin/nightshift
```

Xcode Command Line Tools are enough to build for your own Mac's architecture.
For a universal (arm64 and x86_64) binary, install Xcode and run
`./Scripts/build-release.sh --universal`. Every CI run also uploads a universal
build as an artifact.

### Requirements

- macOS 12 Monterey or later (tested on macOS 26)
- A Mac that supports Night Shift

## Usage

```text
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
```

### Examples

```bash
$ nightshift status
Night Shift: off
Strength:    50
Schedule:    off

$ nightshift schedule 10pm 7am
Schedule: custom, 22:00 to 07:00

$ nightshift strength 70
Strength: 70

$ nightshift status --json
{
  "enabled" : false,
  "from" : "22:00",
  "schedule" : "custom 22:00-07:00",
  "strength" : 70,
  "sunSchedulePermitted" : true,
  "to" : "07:00"
}
```

Exit codes: `0` success, `1` the system refused or Night Shift is unavailable,
`2` invalid arguments.

`schedule sunset` needs Location Services enabled for
System Services > Setting time zone, the same requirement System Settings has.

## Jamf and MDM deployment

Night Shift settings belong to each user, so the tool must run in the logged in
user's session. Jamf policies and most MDM scripts run as root, which would
change root's settings (or nothing at all). Wrap calls like this:

```bash
USER=$(stat -f%Su /dev/console)
launchctl asuser "$(id -u "$USER")" sudo -u "$USER" /usr/local/bin/nightshift status
```

The `Jamf/` folder has ready to use samples:

| File | Purpose |
| --- | --- |
| `Jamf/EA-NightShiftStatus.sh` | Extension attribute, reports `on \| strength 50 \| schedule sunset-to-sunrise` |
| `Jamf/Policy-SetNightShift.sh` | Policy script, parameter 4 is the schedule, parameter 5 is the strength |

Suggested rollout:

1. Build or download the binary and package it to `/usr/local/bin/nightshift`
   (for example with `pkgbuild --root`), then upload it to Jamf Pro.
2. Deploy the package with a policy.
3. Add `Jamf/Policy-SetNightShift.sh` as a script, and run it at login or once per
   user to set a baseline such as `sunset` and `40`.
4. Add the extension attribute to see adoption in inventory and build smart groups.

Because this cannot be enforced by a profile, users can still change Night Shift
afterwards. Re-run the policy at login if you need to keep a baseline.

## How it works and caveats

macOS has no public API for Night Shift. `nightshift` loads Apple's **private**
`CoreBrightness.framework` at runtime with `dlopen` and talks to its
`CBBlueLightClient` class through the Objective-C runtime, the same client System
Settings uses. Nothing is linked against private symbols at build time, and the
tool checks that every method it needs exists before calling it.

Please keep in mind:

- Private frameworks are undocumented and can change in any macOS release. If
  Apple changes `CBBlueLightClient`, the tool reports an error instead of
  crashing, but it may need an update.
- This approach is not allowed in the Mac App Store. It is intended for admins,
  scripts, and personal use.
- True Tone support is read only.

## Development

```bash
swift build             # debug build
swift build -c release  # release build
swift test              # unit tests (needs Xcode, XCTest is not in Command Line Tools)
./Scripts/check-text.sh # style check used by CI
```

Project layout:

- `Sources/CBlueLight`: small Objective-C bridge to CoreBrightness
- `Sources/NightShiftKit`: Swift API (status, on/off, strength, schedule, parsing)
- `Sources/nightshift`: the command line tool
- `Tests/NightShiftKitTests`: unit tests for parsing and conversions

## Contributing

Issues and pull requests are welcome. If a macOS update breaks something,
please open an issue with your macOS version and the output of
`nightshift status`.

## License

MIT, see [LICENSE](LICENSE).
