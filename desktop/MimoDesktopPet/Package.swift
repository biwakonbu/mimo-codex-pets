// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MimoDesktopPet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MimoDesktopPet", targets: ["MimoDesktopPet"]),
        .library(name: "MimoDesktopPetCore", targets: ["MimoDesktopPetCore"])
    ],
    targets: [
        .target(
            name: "MimoDesktopPetCore"
        ),
        .executableTarget(
            name: "MimoDesktopPet",
            dependencies: ["MimoDesktopPetCore"]
        ),
        .testTarget(
            name: "MimoDesktopPetCoreTests",
            dependencies: ["MimoDesktopPetCore"]
        )
    ]
)
