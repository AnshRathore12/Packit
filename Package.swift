// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Packit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Packit",
            targets: ["Packit"]
        )
    ],
    targets: [
        .target(
            name: "Packit"
        ),
        .testTarget(
            name: "PackitTests",
            dependencies: ["Packit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
