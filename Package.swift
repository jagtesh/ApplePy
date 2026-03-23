// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ApplePy",
    products: [
        .library(name: "ApplePy", targets: ["ApplePy"]),
        .library(name: "ApplePyClient", targets: ["ApplePyClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // ── CPython FFI Bindings ─────────────────────────────────────
        .systemLibrary(
            name: "ApplePyFFI",
            pkgConfig: "python3",
            providers: [
                .brew(["python3"]),
                .apt(["python3-dev"]),
            ]
        ),

        // ── Core Library (types, GIL, memory bridge) ────────────────
        .target(
            name: "ApplePy",
            dependencies: ["ApplePyFFI", "ApplePyClient"],
            path: "Sources/ApplePy"
        ),

        // ── Macro Plugin (macro implementations + entry point) ────
        .macro(
            name: "ApplePyMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/ApplePyMacros"
        ),

        // ── Macro Declarations (thin target users import) ───────────
        .target(
            name: "ApplePyClient",
            dependencies: ["ApplePyMacros"],
            path: "Sources/ApplePyClient"
        ),

        // ── Tests ───────────────────────────────────────────────────
        .testTarget(
            name: "ApplePyTests",
            dependencies: [
                "ApplePy",
                "ApplePyClient",
                "ApplePyMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

        // ── Plugins ─────────────────────────────────────────────────
        .plugin(
            name: "ApplePyBuild",
            capability: .buildTool(),
            path: "Plugins/ApplePyBuild"
        ),

        .plugin(
            name: "ApplePyBundle",
            capability: .command(
                intent: .custom(verb: "applepy-bundle", description: "Bundle a Swift extension as a Python-importable .so"),
                permissions: [.writeToPackageDirectory(reason: "Copy the built .so to dist/")]
            ),
            path: "Plugins/ApplePyBundle"
        ),
    ]
)
