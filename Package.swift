// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NightShiftCtl",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "nightshift", targets: ["nightshift"]),
        .library(name: "NightShiftKit", targets: ["NightShiftKit"]),
    ],
    targets: [
        .target(
            name: "CBlueLight",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .target(name: "NightShiftKit", dependencies: ["CBlueLight"]),
        .executableTarget(name: "nightshift", dependencies: ["NightShiftKit"]),
        .testTarget(name: "NightShiftKitTests", dependencies: ["NightShiftKit"]),
    ]
)
