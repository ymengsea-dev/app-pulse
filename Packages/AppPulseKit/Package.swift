// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppPulseKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Platform", targets: ["Platform"]),
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Application", dependencies: ["Domain"]),
        .target(name: "Platform", dependencies: ["Domain"]),
        .target(name: "Presentation", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain"]),
        .testTarget(
            name: "PlatformTests",
            dependencies: ["Platform", "Domain"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Application", "Domain"]),
    ]
)
