// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacBootSound",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacBootSound", targets: ["MacBootSound"]),
        .executable(name: "MacBootSoundPlayer", targets: ["MacBootSoundPlayer"])
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "MacBootSoundPlayer",
            dependencies: ["Shared"],
            path: "Sources/MacBootSoundPlayer"
        ),
        .executableTarget(
            name: "MacBootSound",
            dependencies: ["Shared"],
            path: "Sources/MacBootSound"
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests/SharedTests"
        )
    ]
)
