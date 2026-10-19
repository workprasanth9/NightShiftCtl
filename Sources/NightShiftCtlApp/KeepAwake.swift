import Foundation
import IOKit.pwr_mgt

/// Prevents idle sleep with a public IOKit power assertion.
final class KeepAwake {
    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private(set) var endDate: Date?
    private(set) var isActive = false
    var onChange: (() -> Void)?

    /// Starts keeping the Mac awake. A nil duration means until turned off.
    @discardableResult
    func start(duration: TimeInterval?) -> Bool {
        stop(notify: false)
        let reason = "NightShiftCtl Keep Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        guard result == kIOReturnSuccess else { return false }
        isActive = true
        if let duration {
            endDate = Date().addingTimeInterval(duration)
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.stop()
            }
        } else {
            endDate = nil
        }
        onChange?()
        return true
    }

    func stop(notify: Bool = true) {
        timer?.invalidate()
        timer = nil
        if isActive {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
        endDate = nil
        if notify { onChange?() }
    }

    var statusText: String {
        guard isActive else { return "Off" }
        guard let endDate else { return "On until turned off" }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = remaining >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        let left = formatter.string(from: remaining.rounded(.up)) ?? ""
        let time = DateFormatter.localizedString(from: endDate, dateStyle: .none, timeStyle: .short)
        return "On until \(time) (\(left) left)"
    }
}
