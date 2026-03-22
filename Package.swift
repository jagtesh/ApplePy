// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ApplePy",
    platforms: [.macOS(.v13)],
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

        // ── Macro Logic (importable regular library) ────────────────
        .target(
            name: "ApplePyMacroCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
            path: "Sources/ApplePyMacroCore"
        ),

        // ── Macro Plugin (thin wrapper, re-exports core) ────────────
        .macro(
            name: "ApplePyMacros",
            dependencies: [
                "ApplePyMacroCore",
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
                "ApplePyMacroCore",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
