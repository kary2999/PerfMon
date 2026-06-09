// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PerfMon",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SensorKit"),
        .executableTarget(
            name: "PerfMonApp",
            dependencies: ["SensorKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(name: "SensorKitTests", dependencies: ["SensorKit"]),
    ],
    swiftLanguageModes: [.v5]
)
