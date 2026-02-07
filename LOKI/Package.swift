// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LOKI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LOKICore", targets: ["LOKICore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ggml-org/llama.cpp.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LOKICore",
            dependencies: [
                .product(name: "llama", package: "llama.cpp"),
            ],
            path: "LOKI/Core"
        ),
        .testTarget(
            name: "LOKITests",
            dependencies: ["LOKICore"],
            path: "LOKITests"
        ),
    ]
)
