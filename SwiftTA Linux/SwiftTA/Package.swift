// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "SwiftTA",
    dependencies: [
        .package(path: "../Cgl"),
        .package(path: "../Cglfw"),
        .package(path: "../Czlib"),
        .package(path: "../Ctypes"),
    ],
    targets: [
        .target(
            name: "SwiftTA",
            path: ".",
            exclude: [
                "../../Common/MetalOneTextureTntDrawable.swift",
                "../../Common/MetalRenderer.swift",
                "../../Common/MetalTiledTntDrawable.swift",
                "../../Common/OpenglCore3Renderer.swift",
                "../../Common/Utility+Metal.swift",
                "../../Common/UnitScript+CobDecompile.swift",
            ],
            sources: ["main.swift", "../../Common"]
        )
    ]
)

