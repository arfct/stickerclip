// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "StickerKit",
    platforms: [.iOS(.v18)],
    products: [.library(name: "StickerKit", targets: ["StickerKit"])],
    targets: [
        .target(name: "StickerKit"),
        .testTarget(name: "StickerKitTests", dependencies: ["StickerKit"]),
    ],
    swiftLanguageModes: [.v6]
)
