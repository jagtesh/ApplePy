# 🍎 ApplePy

**Write Python extension modules in Swift.**

ApplePy lets you write Python-importable modules using native Swift code, powered by Swift macros for zero-boilerplate interop. Think [PyO3](https://pyo3.rs) for Swift.

> **Current version: 0.1.0-alpha** — Core functionality complete, working toward v1.0.

## Quick Example

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

## Current Progress

### ✅ Complete
| Feature | Status |
|---------|--------|
| `@PyFunction` — expose Swift functions | ✅ Working |
| `@PyClass` — expose structs/classes as Python types | ✅ Working |
| `@PyMethod` — mark methods for Python | ✅ Working |
| `@PyEnum` — Swift enum → Python `IntEnum` | ✅ Working |
| `#pymodule` — generate module entry point | ✅ Working |
| Type conversions (Int, String, Bool, Float, Array, Dict, Optional) | ✅ Working |
| ARC ↔ Python refcount bridge | ✅ Working |
| GIL management (`withGIL`, `allowThreads`) | ✅ Working |
| Error bridging (Swift `throws` → Python `RuntimeError`) | ✅ Working |
| `@PythonActor` (global actor) | ✅ Working |
| SPM build & bundle plugins | ✅ Working |
| PEP 427 wheel packaging | ✅ Working |
| Type stub generation (`.pyi`) | ✅ Working |
| 15 unit tests passing | ✅ |

### 🔧 v1.0 In Progress
| Feature | Status |
|---------|--------|
| `@PyProperty` — getter/setter | Planned |
| Static/class methods | Planned |
| `~Copyable` PythonHandle (compile-time GIL safety) | Planned |
| Variant enums (associated values → class hierarchy) | Planned |
| Custom exception types | Planned |
| Set/Tuple type conversions | Planned |

### 🔮 Post-v1.0
| Feature | Target |
|---------|--------|
| Async/Await ↔ Asyncio bridge | v1.1 |
| Exception chaining / traceback | v1.1 |
| Free-threaded Python 3.14t | TBD |
| Ecosystem type bridges (Foundation.Date, Codable) | Future |

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

BSD-3-Clause — see [LICENSE](LICENSE).
