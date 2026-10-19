// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NightShiftCtl",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "nightshift", targets: ["nightshift"]),
        .executable(name: "NightShiftCtlApp", targets: ["NightShiftCtlApp"]),
        .library(name: "NightShiftKit", targets: ["NightShiftKit"]),
    ],
    targets: [
        .target(
            name: "CBlueLight",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .target(name: "NightShiftKit", dependencies: ["CBlueLight"]),
        .executableTarget(name: "nightshift", dependencies: ["NightShiftKit"]),
        .executableTarget(
            name: "NightShiftCtlApp",
            dependencies: ["NightShiftKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(name: "NightShiftKitTests", dependencies: ["NightShiftKit"]),
    ]
)
