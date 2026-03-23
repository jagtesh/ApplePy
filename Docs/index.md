---
hide:
  - navigation
---

# 🍎 ApplePy

**Create native Python extensions in Swift.**

ApplePy lets you build `pip install`-able Python packages written entirely in Swift — with direct access to Apple frameworks like CoreML, Metal, NaturalLanguage, Security, and more.

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } **Get started in 30 seconds**

    ---

    ```bash
    pip install applepy-cli
    applepy new myproject
    cd myproject && applepy develop
    ```

    [:octicons-arrow-right-24: Quickstart](quickstart.md)

-   :material-language-swift:{ .lg .middle } **Write Swift, import from Python**

    ---

    ```swift
    @PyFunction
    func hello(name: String) -> String {
        "Hello, \(name)! 🍎"
    }
    ```

    [:octicons-arrow-right-24: Macros Reference](guide/macros.md)

-   :material-apple:{ .lg .middle } **Access Apple frameworks**

    ---

    CoreML, Metal, NaturalLanguage, Security — any framework available in Swift is now available from Python.

    [:octicons-arrow-right-24: Examples](examples/index.md)

-   :fontawesome-brands-python:{ .lg .middle } **pip install & publish**

    ---

    Build wheels, publish to PyPI. Your users just `pip install` — no Swift toolchain needed at runtime.

    [:octicons-arrow-right-24: Building & Packaging](guide/building.md)

</div>

## Quick Example

=== "Swift"

    ```swift
    import ApplePy
    @preconcurrency import ApplePyFFI

    @PyFunction
    func greet(name: String, greeting: String = "Hello") -> String {
        "\(greeting), \(name)! 🍎"
    }

    @PyModule("mylib", functions: [greet])
    func mylib() {}
    ```

=== "Python"

    ```python
    >>> import mylib
    >>> mylib.greet("World")
    'Hello, World! 🍎'
    >>> mylib.greet("World", "Hi")
    'Hi, World! 🍎'
    ```

## Features

| Macro | Purpose |
|-------|---------|
| `@PyFunction` | Expose top-level functions (with default argument support) |
| `@PyClass` | Expose structs/classes as Python types |
| `@PyMethod` | Mark instance methods for Python |
| `@PyStaticMethod` | Mark static methods for Python |
| `@PyProperty` | Expose stored properties with getters/setters |
| `@PyEnum` | Swift enum → Python `IntEnum` or class hierarchy |
| `@PyModule` | Generate `PyInit_` module entry point |

## Type Conversions

| Swift | Python | Direction |
|-------|--------|-----------|
| `Int`, `Double`, `Float`, `Bool` | `int`, `float`, `bool` | ↔ |
| `String` | `str` | ↔ |
| `[T]` | `list` | ↔ |
| `[K: V]` | `dict` | ↔ |
| `Set<T>` | `set` | ↔ |
| `Optional<T>` | `None` / value | ↔ |
| `PyTuple2<A,B>`, `PyTuple3<A,B,C>` | `tuple` | ↔ |

## vs PyO3

| Dimension | PyO3 (Rust) | ApplePy (Swift) |
|-----------|-------------|-----------------|
| Macros | `#[pyfunction]`, `#[pyclass]` | `@PyFunction`, `@PyClass` |
| Memory safety | `'py` lifetimes | `GILGuard: ~Copyable` |
| Build tool | `maturin` | `applepy` CLI |
| Platform | Cross-platform | macOS (Apple frameworks) |
| Enums | Class-based | `IntEnum` + class hierarchy |

[:octicons-arrow-right-24: Full comparison](comparison.md)
