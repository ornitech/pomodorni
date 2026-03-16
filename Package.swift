// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "Pomodoro",
            path: "Pomodoro",
            exclude: ["Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodoroTests",
            dependencies: ["Pomodoro"],
            path: "PomodoroTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodoroSnapshotTests",
            dependencies: [
                "Pomodoro",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "PomodoroSnapshotTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
