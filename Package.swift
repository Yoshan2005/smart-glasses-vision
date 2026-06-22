// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SmartGlassesVision",
    platforms: [
        .iOS(.v18)
    ],
    dependencies: [
        // Reactive sensor data pipeline
        .package(url: "https://github.com/ReactiveX/RxSwift.git", exact: "6.10.2"),
        // Resilient network layer for emergency dispatch
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.12.0"),
    ],
    targets: [
        .target(
            name: "SmartGlassesVision",
            dependencies: [
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "Alamofire", package: "Alamofire"),
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
