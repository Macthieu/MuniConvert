// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MuniConvert",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MuniConvert",
            targets: ["MuniConvert"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MuniConvert",
            path: "Sources/MuniConvert"
        )
    ]
)
