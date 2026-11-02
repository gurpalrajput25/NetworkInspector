// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetworkInspector",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "NetworkInspector",
            targets: ["NetworkInspector"]
        ),
        .library(
            name: "NetworkInspectorCore",
            targets: ["NetworkInspectorCore"]
        ),
        .library(
            name: "NetworkInspectorURLSession",
            targets: ["NetworkInspectorURLSession"]
        ),
        .library(
            name: "NetworkInspectorAlamofire",
            targets: ["NetworkInspectorAlamofire"]
        ),
        .library(
            name: "NetworkInspectorUI",
            targets: ["NetworkInspectorUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0")
    ],
    targets: [
        .target(
            name: "NetworkInspectorCore",
            dependencies: []
        ),
        .target(
            name: "NetworkInspectorPrivacy",
            dependencies: ["NetworkInspectorCore"]
        ),
        .target(
            name: "NetworkInspectorStorage",
            dependencies: ["NetworkInspectorCore", "NetworkInspectorPrivacy"]
        ),
        .target(
            name: "NetworkInspectorAnalytics",
            dependencies: ["NetworkInspectorCore"]
        ),
        .target(
            name: "NetworkInspectorIntegrations",
            dependencies: ["NetworkInspectorCore", "NetworkInspectorPrivacy"]
        ),
        .target(
            name: "NetworkInspectorURLSession",
            dependencies: ["NetworkInspectorCore", "NetworkInspectorPrivacy", "NetworkInspectorStorage"]
        ),
        .target(
            name: "NetworkInspectorAlamofire",
            dependencies: [
                "NetworkInspectorCore",
                "NetworkInspectorPrivacy",
                "NetworkInspectorStorage",
                .product(name: "Alamofire", package: "Alamofire")
            ]
        ),
        .target(
            name: "NetworkInspectorUI",
            dependencies: [
                "NetworkInspectorCore",
                "NetworkInspectorPrivacy",
                "NetworkInspectorStorage",
                "NetworkInspectorAnalytics",
                "NetworkInspectorIntegrations"
            ]
        ),
        .target(
            name: "NetworkInspector",
            dependencies: [
                "NetworkInspectorCore",
                "NetworkInspectorPrivacy",
                "NetworkInspectorStorage",
                "NetworkInspectorAnalytics",
                "NetworkInspectorIntegrations",
                "NetworkInspectorURLSession",
                "NetworkInspectorUI"
            ]
        ),
        .testTarget(
            name: "NetworkInspectorCoreTests",
            dependencies: ["NetworkInspectorCore"]
        ),
        .testTarget(
            name: "NetworkInspectorPrivacyTests",
            dependencies: ["NetworkInspectorPrivacy", "NetworkInspectorCore"]
        ),
        .testTarget(
            name: "NetworkInspectorStorageTests",
            dependencies: ["NetworkInspectorStorage", "NetworkInspectorCore", "NetworkInspectorPrivacy"]
        ),
        .testTarget(
            name: "NetworkInspectorAnalyticsTests",
            dependencies: ["NetworkInspectorAnalytics", "NetworkInspectorCore"]
        ),
        .testTarget(
            name: "NetworkInspectorCaptureTests",
            dependencies: ["NetworkInspectorURLSession", "NetworkInspectorCore", "NetworkInspectorStorage"]
        )
    ]
)

