// swift-tools-version: 5.9
import PackageDescription

/// Clean-room, platform-pure models for documenting the VWAR / G Band BLE surface.
///
/// CoreBluetooth intentionally lives in the app layer. This package stores observations and
/// computes evidence without assigning meaning to unknown UUIDs, opcodes, or payload bytes.
let package = Package(
    name: "VWARProtocol",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "VWARProtocol", targets: ["VWARProtocol"]),
        .executable(name: "vitae-vwar-capture", targets: ["VWARCollector"]),
    ],
    targets: [
        .target(name: "VWARProtocol"),
        .executableTarget(
            name: "VWARCollector",
            dependencies: ["VWARProtocol"]
        ),
        .testTarget(
            name: "VWARProtocolTests",
            dependencies: ["VWARProtocol"]
        ),
    ]
)
