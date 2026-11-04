// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Amnesia",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Amnesia", targets: ["Amnesia"])
    ],
    targets: [
        .executableTarget(
            name: "Amnesia",
            path: "macos/Sources/Amnesia"
        )
    ]
)
