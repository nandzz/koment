// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Koment",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.20.0")
    ],
    targets: [
        .target(
            name: "KomentCore",
            path: "Sources/KomentCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Koment",
            dependencies: [
                "KomentCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Koment",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "MCPServer",
            dependencies: ["KomentCore"],
            path: "Sources/MCPServer",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "KomentMCP",
            dependencies: ["MCPServer"],
            path: "Sources/KomentMCP",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KomentCoreTests",
            dependencies: ["KomentCore"],
            path: "Tests/KomentCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MCPServerTests",
            dependencies: ["MCPServer", "KomentCore"],
            path: "Tests/MCPServerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KomentTests",
            dependencies: ["Koment", "KomentCore"],
            path: "Tests/KomentTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
