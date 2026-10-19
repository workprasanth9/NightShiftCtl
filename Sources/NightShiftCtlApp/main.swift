import AppKit

if CommandLine.arguments.contains("--self-test") {
    SelfTest.run()
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--run-action") {
    let name = CommandLine.arguments.indices.contains(index + 1) ? CommandLine.arguments[index + 1] : ""
    exit(SelfTest.runAction(name))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
