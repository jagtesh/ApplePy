# Macros Reference

ApplePy provides 4 macros for exposing Swift code to Python.

## `@PyFunction`

Exposes a top-level Swift function as a Python callable.

```swift
@PyFunction
func greet(name: String) -> String {
    return "Hello, \(name)!"
}
```

**Generates:**
- `@_cdecl("_applepy_greet")` wrapper that unpacks Python args, calls `greet`, converts return value
- `_applepy_methoddef_greet` — a `PyMethodDef` constant for module registration

**Supported features:**
- Multiple parameters (any `FromPyObject` type)
- Return types (`IntoPyObject` conforming)
- `Void` return (returns Python `None`)
- `throws` (converts to Python `RuntimeError`)

## `@PyClass`

Exposes a Swift `struct` or `class` as a Python type.

```swift
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

    @PyMethod("__repr__")
    func __repr__() -> String { "Counter(\(count))" }
}
```

**Generates:**
- Box class (for value types) or uses the class directly (for reference types)
- `_Counter_PyObject` struct (PyObject + Swift pointer layout)
- `tp_new` / `tp_init` / `tp_dealloc` slot functions
- Method table from `@PyMethod`-annotated methods
- `PyType_Spec` with all slots
- `Counter.registerType(in:)` helper for module registration

**Struct vs Class:**
- **Structs** are boxed in a heap-allocated wrapper (copy semantics preserved)
- **Classes** are stored directly via `Unmanaged<T>` (reference semantics)

## `@PyMethod`

Marks a method inside a `@PyClass` for Python exposure. This is a **marker macro** — the actual code generation happens in `@PyClass`, which reads `@PyMethod` attributes.

```swift
@PyMethod           // exposed as method_name() in Python
func methodName() { }

@PyMethod("__repr__")  // exposed as __repr__ (dunder method)
func repr() -> String { }
```

**Supported dunder methods:**
- `__repr__` → `tp_repr` slot
- `__str__` → `tp_str` slot (planned)
- `__eq__`, `__hash__` (planned)
- `__len__`, `__getitem__` (planned)

## `#pymodule`

Generates the `PyInit_<name>` entry point that CPython calls when you `import` the module.

```swift
#pymodule("mylib", types: [Counter.self], functions: [greet])
```

**Parameters:**
- `name` — Python module name (must match the `.so` filename)
- `types` — array of `@PyClass` types to register
- `functions` — array of `@PyFunction` functions to include in the method table

**Generates:**
- Module method table (from `@PyFunction` method defs)
- `PyModuleDef` (global)
- `@_cdecl("PyInit_mylib")` function
