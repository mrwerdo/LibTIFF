// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "LibTIFF",
    products: [
        .library(name: "LibTIFF", targets: ["LibTIFF"])
    ],
    dependencies: [
        .package(url: "https://github.com/mrwerdo/Geometry", from: "1.2.4")
    ],
    targets: [
        .target(name: "CLibTIFF", exclude: ["README", "VERSION", "ChangeLog", "COPYRIGHT"]),
        .target(name: "LibTIFF", dependencies: ["CLibTIFF", "Geometry"]),
        .testTarget(name: "LibTIFFTests", dependencies: ["LibTIFF"])
    ]
)
