// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DayTrace",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DayTrace", targets: ["DayTrace"])
    ],
    targets: [
        .executableTarget(
            name: "DayTrace",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
