import AppKit
import NightShiftKit

/// First launch window: explains where the app lives and says thank you.
final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let shownKey = "WelcomeShownVersion"

    static var shouldShowOnLaunch: Bool {
        UserDefaults.standard.string(forKey: shownKey) == nil
    }

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to NightShiftCtl"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
        window.contentView = makeContent()
        window.center()
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        UserDefaults.standard.set(NightShiftCtlVersion.current, forKey: Self.shownKey)
    }

    private func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
                       color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.preferredMaxLayoutWidth = 400
        return field
    }

    private func makeContent() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = label("NightShiftCtl lives in your menu bar", size: 17, weight: .semibold)
        let where1 = label("Look for the moon icon near the clock at the top right of the screen. Click it for Night Shift, Keep Awake, Dark Mode and the other toggles. There is no Dock icon.")
        let notch = label("On a MacBook with a notch, a full menu bar can hide some icons behind the notch. If you do not see the moon, quit a few menu bar apps, or hold Command and drag the moon icon to the right.",
                          size: 12, color: .secondaryLabelColor)
        let thanks = label("Thank you for installing NightShiftCtl! If it makes your day a little easier, please star the project on GitHub and share it with a Mac admin friend. It really helps.",
                           size: 12)

        let star = NSButton(title: "Star on GitHub", target: self, action: #selector(openRepository))
        star.bezelStyle = .rounded
        let done = NSButton(title: "Got It", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        let buttons = NSStackView(views: [star, done])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [icon, title, where1, notch, thanks, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 30, bottom: 24, right: 30)
        stack.setCustomSpacing(18, after: thanks)
        for field in [where1, notch, thanks] { field.alignment = .center }
        return stack
    }

    @objc private func openRepository() {
        SystemActions.openURL(NightShiftCtlLinks.repositoryURL)
    }

    @objc private func closeWindow() {
        window?.close()
    }
}
