// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormFillAI",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "FormFillAICore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FormFillAI",
            dependencies: ["FormFillAICore"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("Carbon")]
        ),
        .executableTarget(
            name: "FormFillAISelfTest",
            dependencies: ["FormFillAICore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
