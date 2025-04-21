// swift-tools-version:5.10.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rocket",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Rocket",
            targets: ["Rocket"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "Rocket",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "RocketTests",
            dependencies: ["Rocket"],
            path: "Tests")
    ],
    swiftLanguageVersions: [.v5]
) 