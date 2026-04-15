# 🍎 ApplePy

**Create native Python extensions in Swift.**

ApplePy lets you build `pip install`-able Python packages written entirely in Swift — with direct access to Apple frameworks like CoreML, Metal, NaturalLanguage, Security, and more. Powered by Swift macros for zero-boilerplate interop. Think [PyO3](https://pyo3.rs) for Swift.

```bash
pip install applepy-cli        # install the build tool
applepy new myproject           # scaffold a project
cd myproject && applepy develop # build & install
```

> **Version 1.0.0** — BSD-3-Clause

## Quick Example

```swift
import ApplePy

@PyFunction
func greet(name: String, greeting: String = "Hello") -> String {
    "\(greeting), \(name)! 🍎"
}

@PyClass
struct Counter {
    @PyProperty var count: Int = 0

    @PyMethod
    mutating func increment() { count += 1 }

    @PyMethod
    func value() -> Int { count }
}

@PyEnum
enum Color: Int {
    case red = 0
    case green = 1
    case blue = 2
}

@PyModule("mylib", types: [Counter.self], functions: [greet])
func mylib() {}
```

```python
>>> import mylib
>>> mylib.greet("World")
'Hello, World! 🍎'
>>> mylib.greet("World", "Hi")
'Hi, World! 🍎'
>>> c = mylib.Counter(10)
>>> c.increment()
>>> c.value()
11
>>> mylib.Color.red
<Color.red: 0>
```

## Features

### Macros
| Macro | Purpose |
|-------|---------|
| `@PyFunction` | Expose top-level functions (with default argument support) |
| `@PyClass` | Expose structs/classes as Python types |
| `@PyMethod` | Mark instance methods for Python |
| `@PyStaticMethod` | Mark static methods for Python |
| `@PyProperty` | Expose stored properties with getters/setters |
| `@PyEnum` | Swift enum → Python `IntEnum` or class hierarchy (with associated values) |
| `@PyModule` | Generate `PyInit_` module entry point |

### Type System
| Swift | Python | Direction |
|-------|--------|-----------|
| `Int`, `Double`, `Float`, `Bool` | `int`, `float`, `bool` | ↔ |
| `String` | `str` | ↔ |
| `[T]` | `list` | ↔ |
| `[K: V]` | `dict` | ↔ |
| `Set<T>` | `set` | ↔ |
| `Optional<T>` | `None` / value | ↔ |
| `PyTuple2<A,B>`, `PyTuple3<A,B,C>` | `tuple` | ↔ |
| `[UInt8]` / `Data` | `bytes` | → (copy) |

### Safety & Runtime
| Feature | Details |
|---------|---------|
| **`GILGuard: ~Copyable`** | Compile-time GIL scope enforcement — can't escape `withGIL` |
| **`PythonHandle`** | Lightweight GIL token for protocol compatibility |
| **`@PythonActor`** | Global actor for Swift concurrency integration |
| **`PyBridged` / `PyBridge`** | ARC ↔ refcount memory bridge with debug assertions |
| **`PythonException`** | Captures Python error state as Swift `Error` |
| **`PyExceptionType`** | Create custom Python exception types at runtime |
| **`PyExceptionMapping`** | Protocol to route Swift errors to specific Python exceptions |

### Tooling
| Tool | Purpose |
|------|---------|
| SPM Build Plugin | Auto-detects Python via `pkg-config` |
| SPM Bundle Plugin | Renames `.dylib` to CPython-compatible `.so` |
| `applepy-pack.py` | PEP 427 wheel packaging |
| `applepy-stubs.py` | Type stub (`.pyi`) generation |

## vs PyO3

| Dimension | PyO3 (Rust) | ApplePy (Swift) |
|-----------|-------------|-----------------|
| Macros | `#[pyfunction]`, `#[pyclass]`, `#[pymethods]` | `@PyFunction`, `@PyClass`, `@PyMethod`, `@PyEnum` |
| Memory safety | `'py` lifetimes (compile-time) | `GILGuard: ~Copyable` (compile-time) |
| Type conversions | 15+ crate integrations | Primitives, collections, tuples, sets |
| Async | `pyo3-async-runtimes` | v1.1 (planned) |
| Build tool | `maturin` | SPM plugins + manual scripts |
| Enums | Class-based | `IntEnum` + class hierarchy |

## Getting Started

The fastest way to start a new ApplePy project is with the CLI:

```bash
# Install the CLI (pick one)
pip install applepy-cli
uv pip install applepy-cli
```

Then create your project:

```bash
applepy new myproject
cd myproject
applepy develop
python myproject/examples/demo.py
# → Hello, World! 🍎
```

The CLI handles everything: project scaffolding, Swift compilation, and packaging. See [`applepy-cli` on PyPI](https://pypi.org/project/applepy-cli/) for all options.

### Manual Setup (SPM)

If you prefer to set things up manually, add ApplePy as a Swift package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/jagtesh/ApplePy.git", from: "1.0.0"),
]
```

## Documentation

| Doc | Description |
|-----|-------------|
| [Getting Started](https://jagtesh.github.io/ApplePy/getting-started/) | 5-minute quickstart |
| [Macros Reference](https://jagtesh.github.io/ApplePy/guide/macros/) | `@PyFunction`, `@PyClass`, `@PyMethod`, `@PyModule` |
| [Type Conversion](https://jagtesh.github.io/ApplePy/guide/type-conversion/) | Swift ↔ Python type mapping |
| [Memory Management](https://jagtesh.github.io/ApplePy/guide/memory-management/) | ARC ↔ refcount bridge |
| [Building & Packaging](https://jagtesh.github.io/ApplePy/guide/building/) | SPM, plugins, wheels |

## Roadmap

| Feature | Target |
|---------|--------|
| Async/Await ↔ Asyncio bridge | v1.1 |
| Exception chaining / traceback | v1.1 |
| Free-threaded Python 3.14t | v1.2 |
| Ecosystem type bridges (Foundation.Date, Codable) | Future |

## Acknowledgements

Taking inspiration from [PyO3](https://pyo3.rs), ApplePy's macro system has been adapted to Swift 6.0 — including the `@PyModule` peer-macro pattern, compile-time GIL safety via `~Copyable`, and the `names: prefixed(_applepy_)` approach for global-scope macro hygiene.

## License

BSD-3-Clause © Jagtesh Chadha — see [LICENSE](LICENSE).
