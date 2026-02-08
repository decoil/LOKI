// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LOKI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LOKI", targets: ["LOKI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ggml-org/llama.cpp.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LOKI",
            dependencies: [
                .product(name: "llama", package: "llama.cpp"),
            ],
            path: "LOKI",
            exclude: ["Info.plist", "LOKI.entitlements"]
        ),
        .testTarget(
            name: "LOKITests",
            dependencies: ["LOKI"],
            path: "LOKITests"
        ),
    ]
)
