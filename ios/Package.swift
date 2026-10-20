// swift-tools-version:6.0
// Only for `swift test`: builds api/, flows/Flows.swift, result/Verdict.swift and settings/Settings.swift (Foundation and Security,
// no UIKit) on a Mac, so the tests run without Xcode or a device. The app itself builds from project.yml.
import PackageDescription

let package = Package(
    name: "UnicoReference",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "UnicoReference",
            path: ".",
            exclude: ["test"],
            sources: ["api/Unico.swift", "flows/Flows.swift", "result/Verdict.swift", "settings/Settings.swift"]
        ),
        .testTarget(name: "UnicoReferenceTests", dependencies: ["UnicoReference"], path: "test"),
    ]
)
