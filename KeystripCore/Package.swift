// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeystripCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "KeystripCore", targets: ["KeystripCore"]),
        .executable(name: "keystrip-check", targets: ["keystrip-check"]),
    ],
    targets: [
        .target(name: "KeystripCore"),
        .executableTarget(name: "keystrip-check", dependencies: ["KeystripCore"]),
        .testTarget(
            name: "KeystripCoreTests",
            dependencies: ["KeystripCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
