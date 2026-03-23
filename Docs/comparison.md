# ApplePy vs PyO3

ApplePy takes direct inspiration from [PyO3](https://pyo3.rs), adapting its patterns for Swift. Here's how they compare.

## Macro Comparison

| Concept | PyO3 (Rust) | ApplePy (Swift) |
|---------|-------------|-----------------|
| Functions | `#[pyfunction]` | `@PyFunction` |
| Classes | `#[pyclass]` | `@PyClass` |
| Methods | `#[pymethods]` | `@PyMethod` |
| Static methods | `#[staticmethod]` | `@PyStaticMethod` |
| Properties | `#[getter]` / `#[setter]` | `@PyProperty` |
| Module | `#[pymodule]` | `@PyModule` |
| Enums | Class-based | `@PyEnum` → `IntEnum` |

## Side by Side

=== "ApplePy (Swift)"

    ```swift
    import ApplePy
    @preconcurrency import ApplePyFFI

    @PyFunction
    func add(a: Int, b: Int) -> Int {
        a + b
    }

    @PyModule("mylib", functions: [add])
    func mylib() {}
    ```

=== "PyO3 (Rust)"

    ```rust
    use pyo3::prelude::*;

    #[pyfunction]
    fn add(a: i64, b: i64) -> i64 {
        a + b
    }

    #[pymodule]
    fn mylib(m: &Bound<'_, PyModule>) -> PyResult<()> {
        m.add_function(wrap_pyfunction!(add, m)?)?;
        Ok(())
    }
    ```

## Memory Safety

| Aspect | PyO3 | ApplePy |
|--------|------|---------|
| GIL enforcement | `'py` lifetime (compile-time) | `GILGuard: ~Copyable` (compile-time) |
| Object ownership | `Bound<'py, T>` | `PythonHandle` |
| Concurrency | `Send + ?Sync` bounds | `@PythonActor` global actor |
| Ref counting | Automatic via `Py<T>` | `PyBridge` ARC ↔ refcount |

## Build Tooling

| Aspect | PyO3 | ApplePy |
|--------|------|---------|
| Build tool | `maturin` | `applepy` CLI |
| Scaffold | `maturin new` | `applepy new` |
| Dev install | `maturin develop` | `applepy develop` |
| Wheel build | `maturin build` | `applepy build` |
| Publish | `maturin publish` | `applepy publish` |
| Package manager | Cargo | Swift Package Manager |

## Key Differences

!!! info "Platform"
    PyO3 is cross-platform (Linux, macOS, Windows). ApplePy targets macOS — its key advantage is direct access to Apple frameworks (CoreML, Metal, NaturalLanguage, Security, etc.).

!!! info "Language"
    Rust has zero-cost abstractions and no runtime. Swift has ARC and a rich standard library. Both have excellent type systems and compile-time safety.

!!! info "Ecosystem"
    PyO3 has a mature ecosystem with 15+ type conversion crates. ApplePy provides built-in conversions for primitives, collections, tuples, and optionals, with the entire Apple SDK as its "ecosystem".
