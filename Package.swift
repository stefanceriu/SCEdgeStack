// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SCEdgeStack",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SCEdgeStack", targets: ["SCEdgeStack"])
    ],
    targets: [
        .target(
            name: "StackGeometry",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SCEdgeStack",
            dependencies: ["StackGeometry"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StackGeometryTests",
            dependencies: ["StackGeometry"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SCEdgeStackTests",
            dependencies: ["SCEdgeStack"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
