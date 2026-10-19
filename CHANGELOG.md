# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-19

### Added
- NightShiftCtl.app, a menu bar app built on the shared NightShiftKit library.
- Night Shift toggle, warmth slider, and schedule picker with a custom times editor.
- True Tone status in the menu.
- Keep Awake with durations from 15 minutes to 8 hours, or until turned off (IOKit assertion).
- Dark Mode, Hide Desktop Icons, and Show Hidden Files toggles.
- Lock Screen, Empty Trash (with confirmation), and Flush DNS (admin prompt) actions.
- Local IP addresses and on demand public IP lookup, click to copy.
- Launch at Login on macOS 13 and later.
- App icon, `Scripts/build-app.sh`, and `Scripts/build-app-pkg.sh` that builds an
  installer placing the app in /Applications and the CLI in /usr/local/bin.
- `--self-test` flag for read only diagnostics.
- CI now builds the app and installer and uploads them as artifacts.

### Changed
- The CLI and app share one version number from NightShiftKit.

### Not included
- Do Not Disturb / Focus control, since macOS offers no reliable public API for it.

## [1.0.0] - 2026-10-19

### Added
- `nightshift` command line tool for macOS Night Shift.
- `on`, `off` and `toggle` commands.
- `strength` command to read or set warmth from 0 to 100.
- `schedule` command: sunset to sunrise, custom times (24 hour or am/pm), or off.
- `status` command with human readable and `--json` output.
- Read only `truetone` status command.
- Jamf Pro extension attribute and policy script samples.
- GitHub Actions CI that builds and tests on macOS.
