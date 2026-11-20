// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChronoTatamiCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [.library(name: "ChronoTatamiCore", targets: ["ChronoTatamiCore"])],
    targets: [
        .target(name: "ChronoTatamiCore"),
        .testTarget(name: "ChronoTatamiCoreTests", dependencies: ["ChronoTatamiCore"],
                    resources: [.copy("Fixtures")]),
    ]
)
