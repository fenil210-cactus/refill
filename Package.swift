// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Refill",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Refill", targets: ["Refill"]),
        .library(name: "RefillCore", targets: ["RefillCore"]),
    ],
    targets: [
        .target(name: "RefillCore"),
        .executableTarget(name: "Refill", dependencies: ["RefillCore"]),
        .testTarget(name: "RefillCoreTests", dependencies: ["RefillCore"]),
    ]
)
