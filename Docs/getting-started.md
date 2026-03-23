# Getting Started with ApplePy

Create native Python extension modules in Swift — write idiomatic Swift, `pip install`, import from Python.

## Quick Start (Recommended)

The fastest way to get started is with the CLI:

```bash
# Install (pick one)
pip install applepy-cli
uv pip install applepy-cli
```

```bash
# Create, build, and run
applepy new myproject
cd myproject
applepy develop
python myproject/examples/demo.py
# → Hello, World! 🍎
```

That's it! The CLI scaffolds a complete project with Swift source, `pyproject.toml`, and a demo script.

## What Gets Generated

```
myproject/
├── pyproject.toml              # pip metadata
├── setup.py                    # custom build_ext → swift build
├── README.md
├── myproject/
│   ├── __init__.py             # loads compiled .so, re-exports functions
│   └── examples/demo.py        # starter example
└── swift/
    ├── Package.swift           # SPM package, depends on ApplePy
    └── Sources/MyProject/
        └── MyProject.swift      # @PyFunction + @PyModule starter
```

## The Generated Swift Code

```swift
import ApplePy
@preconcurrency import ApplePyFFI

@PyFunction
func hello(name: String = "World") -> String {
    return "Hello, \(name)! 🍎"
}

@PyModule("myproject", functions: [
    hello,
])
func myproject() {}
```

```python
>>> import myproject
>>> myproject.hello("World")
'Hello, World! 🍎'
>>> myproject.hello("ApplePy")
'Hello, ApplePy! 🍎'
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `applepy new <name>` | Scaffold a new project |
| `applepy develop` | Build Swift + install into current environment |
| `applepy build` | Build a distributable wheel (`.whl`) |
| `applepy publish` | Publish to PyPI (`--test` for TestPyPI) |

### `applepy new` Options

```bash
applepy new myproject                          # GitHub ApplePy dependency (default)
applepy new myproject --local                  # local ApplePy checkout (for development)
applepy new myproject --applepy-path ../ApplePy # explicit local path
applepy new myproject -d "My description"      # set project description
```

## Prerequisites

- **Swift 6.0+** (for macro support)
- **Python 3.10+** (with development headers)
- **macOS** (Apple frameworks require macOS)

## Manual Setup (Advanced)

If you prefer not to use the CLI, add ApplePy as a Swift package dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/jagtesh/ApplePy.git", from: "1.0.0"),
],
targets: [
    .target(name: "mylib", dependencies: [
        .product(name: "ApplePy", package: "ApplePy"),
        .product(name: "ApplePyClient", package: "ApplePy"),
    ]),
]
```

Build with:
```bash
PKG_CONFIG_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBPC"))') \
  swift build
```

## Real-World Examples

| Package | Framework | Install |
|---------|-----------|---------|
| [swiftkeychain](https://github.com/jagtesh/swiftkeychain) | macOS Security (Keychain) | `pip install swiftkeychain` |
| [pynatural](https://github.com/jagtesh/pynatural) | NaturalLanguage (NLP) | `pip install pynatural` |
| [pycoreml](https://github.com/jagtesh/pycoreml) | CoreML (ML inference) | `pip install pycoreml` |

## Next Steps

- [Macros Reference](Macros.md) — `@PyFunction`, `@PyClass`, `@PyMethod`, `@PyModule`
- [Type Conversion](TypeConversion.md) — how Swift types map to Python types
- [Memory Management](MemoryManagement.md) — ARC ↔ refcount bridge
- [Building & Packaging](BuildingAndPackaging.md) — SPM plugins, wheel packaging
