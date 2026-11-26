// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpeakKlierly",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(
            name: "SpeakKlierly",
            path: "Sources/SpeakKlierly"
        )
    ]
)
