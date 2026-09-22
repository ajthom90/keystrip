// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeystripCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "KeystripCore", targets: ["KeystripCore"]),
    ],
    targets: [
        .target(name: "KeystripCore"),
        .testTarget(
            name: "KeystripCoreTests",
            dependencies: ["KeystripCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
