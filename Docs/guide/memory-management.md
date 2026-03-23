# Memory Management

ApplePy bridges two memory management systems:
- **Swift**: Automatic Reference Counting (ARC)
- **Python**: Manual reference counting (`Py_INCREF` / `Py_DECREF`)

## How It Works

When Python wraps a Swift object, neither runtime "knows" about the other's refcount. Instead:

1. **Python creates a wrapper**: `tp_new` allocates a `PyObject`
2. **Swift object stored**: `tp_init` calls `Unmanaged.passRetained()` → ARC count +1
3. **Python uses the object**: Python refcount tracks Python references
4. **Python deallocates**: `tp_dealloc` calls `Unmanaged.release()` → ARC count -1

The key invariant: **the `Unmanaged.passRetained()` in `tp_init` is balanced by `Unmanaged.release()` in `tp_dealloc`**.

## PyBridged Protocol

```swift
protocol PyBridged {
    associatedtype Box: AnyObject
    static func box(_ value: Self) -> Box
    static func unbox(_ box: Box) -> Self
}
```

- **Structs**: Boxed in `PyObjectBox<T>` (heap-allocated wrapper with copy semantics)
- **Classes**: Box IS the class itself (zero-overhead)

## PyBridge Helpers

```swift
// tp_init: store a Swift value
PyBridge.store(myCounter, in: pyObject)

// Method wrapper: access the Swift value
let counter = PyBridge.load(Counter.self, from: pyObject)

// tp_dealloc: release
PyBridge.release(Counter.self, from: pyObject)
```

## Debug Assertions

In `DEBUG` builds, ApplePy checks:
- Python refcount ≥ 1 when accessing (`assertPyAlive`)
- Swift pointer is non-nil when loading (`assertSwiftAlive`)

## GIL Considerations

All Python object access **must** happen while holding the GIL:

```swift
PythonHandle.withGIL { py in
    // Safe to use Python objects here
    let result = myValue.intoPython(py: py)
}
```

Use `allowThreads` for CPU-bound Swift work:

```swift
py.allowThreads {
    // GIL released — other Python threads can run
    let data = heavyComputation()
}
```

## Common Pitfalls

1. **Don't store `PyObjectPtr` across GIL releases** — the object might be deallocated
2. **Don't share `PyObjectPtr` across threads** without acquiring the GIL
3. **Watch for cycles**: Swift object → Python wrapper → Swift object. Break with weak references.
