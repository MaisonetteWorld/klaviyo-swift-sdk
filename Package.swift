// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "Klaviyo",
    products: [
        .library(
            name: "Klaviyo",
            targets: ["Klaviyo"]),
    ],
    targets: [
        .target(
            name: "Klaviyo",
            dependencies: [],
            path: "Source/",
            exclude: [
                "Supporting Files/Info.plist"
            ],
            sources: [
                "Klaviyo.swift",
                "ReachabilitySwift.swift"
            ]
        )
    ]
)
