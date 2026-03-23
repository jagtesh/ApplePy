# Type Conversion

ApplePy automatically converts between Swift and Python types using two protocols:

```swift
protocol FromPyObject {
    static func fromPython(_ obj: PyObjectPtr, py: PythonHandle) throws -> Self
}

protocol IntoPyObject {
    func intoPython(py: PythonHandle) -> PyObjectPtr
}
```

## Type Mapping

| Swift Type | Python Type | Direction |
|-----------|-------------|-----------|
| `Int` | `int` | ↔ |
| `Double` | `float` | ↔ |
| `Float` | `float` | ↔ (loses precision) |
| `Bool` | `bool` | ↔ |
| `String` | `str` | ↔ |
| `Array<T>` | `list` | ↔ (elements must conform) |
| `Dictionary<K,V>` | `dict` | ↔ (keys/values must conform) |
| `Optional<T>` | `T` or `None` | ↔ |

## CPython APIs Used

| Conversion | CPython Function |
|-----------|-----------------|
| Swift `Int` → Python | `PyLong_FromLongLong` |
| Python → Swift `Int` | `PyLong_AsLongLong` |
| Swift `Double` → Python | `PyFloat_FromDouble` |
| Python → Swift `Double` | `PyFloat_AsDouble` |
| Swift `Bool` → Python | `PyBool_FromLong` |
| Python → Swift `Bool` | `PyObject_IsTrue` |
| Swift `String` → Python | `PyUnicode_FromString` |
| Python → Swift `String` | `PyUnicode_AsUTF8` |
| Swift `Array` → Python | `PyList_New` + `PyList_SetItem` |
| Python → Swift `Array` | `PyList_Size` + `PyList_GetItem` |

## Error Handling

If a type conversion fails, a `PythonConversionError` is thrown:

```swift
enum PythonConversionError: Error {
    case typeMismatch(expected: String, got: String)
    case overflow(value: String, targetType: String)
    case nullPointer
    case pythonError
}
```

In macro-generated code, these are caught and converted to Python `TypeError` or `RuntimeError`.

## Adding Custom Types

Conform your type to `FromPyObject` and/or `IntoPyObject`:

```swift
extension MyType: FromPyObject {
    static func fromPython(_ obj: PyObjectPtr, py: PythonHandle) throws -> MyType {
        // Extract fields from Python object
    }
}

extension MyType: IntoPyObject {
    func intoPython(py: PythonHandle) -> PyObjectPtr {
        // Create and return a Python object
    }
}
```
