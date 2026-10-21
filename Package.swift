// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "TrackboardCore", targets: ["TrackboardCore"])]
var targets: [Target] = [
    .target(name: "TrackboardCore"),
    .testTarget(name: "TrackboardCoreTests", dependencies: ["TrackboardCore"])
]

#if os(macOS)
products.append(.executable(name: "Trackboard", targets: ["Trackboard"]))
targets += [
    .target(
        name: "InputMethodBridge",
        publicHeadersPath: "include",
        cSettings: [.unsafeFlags(["-fobjc-arc"])],
        linkerSettings: [.linkedFramework("InputMethodKit"), .linkedFramework("Carbon")]
    ),
    .target(
        name: "TrackboardMac",
        dependencies: ["TrackboardCore", "InputMethodBridge"],
        linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("Vision")]
    ),
    .executableTarget(name: "Trackboard", dependencies: ["TrackboardMac"]),
    .testTarget(name: "TrackboardMacTests", dependencies: ["TrackboardMac"])
]
#endif

let package = Package(
    name: "Trackboard",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
