// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodorni",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomodorni", targets: ["Pomodorni"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "Pomodorni",
            path: "Pomodorni",
            exclude: ["Info.plist", "Assets"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodorniTests",
            dependencies: ["Pomodorni"],
            path: "PomodorniTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodorniSnapshotTests",
            dependencies: [
                "Pomodorni",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "PomodorniSnapshotTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
