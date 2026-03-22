# 🍎 ApplePy

**Write Python extension modules in Swift.**

ApplePy is a Swift framework that lets you write Python-importable modules using native Swift code, powered by Swift macros for zero-boilerplate interop.

## Why ApplePy?

|  | Python (C extension) | Cython | PyO3 (Rust) | **ApplePy (Swift)** |
|--|---------------------|--------|-------------|---------------------|
| Language | C | Cython/C | Rust | **Swift** |
| Memory | Manual | Manual | Safe | **ARC (automatic)** |
| Macros | N/A | N/A | `#[pyfunction]` | **`@PyFunction`** |
| IDE Support | ⚠️ | ⚠️ | ✅ | **✅** |
| Apple Platform | ✅ | ⚠️ | ⚠️ | **✅ Native** |

## Quick Start

```swift
import ApplePy

@PyFunction
func greet(name: String) -> String {
    "Hello, \(name)! 🍎"
}

@PyClass
struct Counter {
    var count: Int = 0

    @PyMethod
    func increment() { count += 1 }

    @PyMethod
    func value() -> Int { count }
}

#pymodule("mylib", types: [Counter.self], functions: [greet])
```

```python
>>> import mylib
>>> mylib.greet("World")
'Hello, World! 🍎'
>>> c = mylib.Counter(10)
>>> c.increment()
>>> c.value()
11
```

## Features

- ✅ **`@PyFunction`** — Expose Swift functions to Python
- ✅ **`@PyClass`** — Expose Swift structs/classes as Python types
- ✅ **`@PyMethod`** — Mark methods for Python exposure
- ✅ **`#pymodule`** — Generate the module entry point
- ✅ **Automatic type conversion** — Int, String, Bool, Float, Array, Dict, Optional
- ✅ **ARC ↔ Refcount bridge** — Safe memory management across runtimes
- ✅ **GIL management** — `PythonHandle.withGIL` and `allowThreads`
- ✅ **Error bridging** — Swift `throws` → Python `RuntimeError`
- ✅ **Wheel packaging** — Build `.whl` files for `pip install`
- ✅ **SPM plugins** — Build and bundle commands
- ✅ **Type stubs** — `.pyi` generation for IDE autocomplete

## Requirements

- Swift 6.0+ (macOS 13+)
- Python 3.13+ (with development headers)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/example/ApplePy.git", from: "0.1.0"),
]
```

## Documentation

| Doc | Description |
|-----|-------------|
| [Getting Started](Docs/GettingStarted.md) | 5-minute quickstart |
| [Macros Reference](Docs/Macros.md) | `@PyFunction`, `@PyClass`, `@PyMethod`, `#pymodule` |
| [Type Conversion](Docs/TypeConversion.md) | Swift ↔ Python type mapping |
| [Memory Management](Docs/MemoryManagement.md) | ARC ↔ refcount bridge |
| [Building & Packaging](Docs/BuildingAndPackaging.md) | SPM, plugins, wheels |

## License

MIT
