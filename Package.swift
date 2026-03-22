// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ApplyPy",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ApplyPy", targets: ["ApplyPy"]),
        .library(name: "ApplyPyClient", targets: ["ApplyPyClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // ── CPython FFI Bindings ─────────────────────────────────────
        .systemLibrary(
            name: "ApplyPyFFI",
            pkgConfig: "python3",
            providers: [
                .brew(["python3"]),
                .apt(["python3-dev"]),
            ]
        ),

        // ── Core Library (types, GIL, memory bridge) ────────────────
        .target(
            name: "ApplyPy",
            dependencies: ["ApplyPyFFI", "ApplyPyClient"],
            path: "Sources/ApplyPy"
        ),

        // ── Macro Implementations (SwiftSyntax-based) ───────────────
        .macro(
            name: "ApplyPyMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/ApplyPyMacros"
        ),

        // ── Macro Declarations (thin target users import) ───────────
        .target(
            name: "ApplyPyClient",
            dependencies: ["ApplyPyMacros"],
            path: "Sources/ApplyPyClient"
        ),

        // ── Tests ───────────────────────────────────────────────────
        .testTarget(
            name: "ApplyPyTests",
            dependencies: [
                "ApplyPy",
                "ApplyPyClient",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
