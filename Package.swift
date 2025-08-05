// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "xcede",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", .upToNextMajor(from: "5.0.2"))
    ],
    targets: [
        .executableTarget(
            name: "xcede-dap",
            dependencies: [
                .product(name: "SwiftyJSON", package: "SwiftyJSON")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
