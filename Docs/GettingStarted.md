# Getting Started with ApplePy

Build Python extension modules in Swift — write idiomatic Swift, import from Python.

## Quick Example

```swift
import ApplePy

@PyFunction
func greet(name: String) -> String {
    return "Hello, \(name)! 🍎"
}

@PyClass
struct Counter {
    var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    @PyMethod
    func increment() { count += 1 }

    @PyMethod
    func value() -> Int { count }
}

#pymodule("mylib", types: [Counter.self], functions: [greet])
```

```python
import mylib

print(mylib.greet("World"))
# → Hello, World! 🍎

c = mylib.Counter(10)
c.increment()
print(c.value())  # → 11
```

## Prerequisites

- **Swift 6.0+** (for macro support)
- **Python 3.13+** (with development headers)
- **macOS 13+** or Linux

## Setup

### 1. Create a new Swift package

```bash
mkdir mylib && cd mylib
swift package init --type library --name mylib
```

### 2. Add ApplePy dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/example/ApplePy.git", from: "0.1.0"),
],
targets: [
    .target(name: "mylib", dependencies: ["ApplePy"]),
]
```

### 3. Write your extension

Create `Sources/mylib/mylib.swift` with your `@PyFunction`s, `@PyClass`es, and `#pymodule`.

### 4. Build

```bash
PKG_CONFIG_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')/pkgconfig \
  swift build
```

### 5. Bundle for Python

Use the build scripts in `Examples/` as reference, or the `applepy-pack.py` tool:

```bash
python3 Tools/applepy-pack.py --name mylib --version 0.1.0 --so dist/mylib.so
pip install dist/mylib-*.whl
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `PKG_CONFIG_PATH` | Points to Python's pkgconfig directory for build-time header/lib detection |
| `DYLD_LIBRARY_PATH` | Points to Python's lib directory (macOS runtime) |
| `PYTHONHOME` | Points to Python's prefix (needed for non-system Python, e.g., mise) |

## Next Steps

- [Macros Reference](Macros.md) — `@PyFunction`, `@PyClass`, `@PyMethod`, `#pymodule`
- [Type Conversion](TypeConversion.md) — how Swift types map to Python types
- [Memory Management](MemoryManagement.md) — ARC ↔ refcount bridge
- [Building & Packaging](BuildingAndPackaging.md) — SPM plugins, wheel packaging
