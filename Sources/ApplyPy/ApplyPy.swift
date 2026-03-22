// ApplyPy – Core Library
// Re-exports FFI and macro declarations, provides type conversions and runtime support.

@_exported import ApplyPyFFI
@_exported import ApplyPyClient

// MARK: - PyObjectPtr

/// A pointer to a CPython `PyObject`. This is the fundamental type bridged between Swift and Python.
public typealias PyObjectPtr = UnsafeMutablePointer<PyObject>?

// MARK: - PythonHandle (GIL Token)

/// A token proving that the current thread holds the Python GIL.
/// All functions that interact with Python objects require a `PythonHandle`.
///
/// For now this is a simple stub. Phase 3 upgrades this to full GIL management
/// with `~Copyable` enforcement and debug assertions.
public struct PythonHandle: Sendable {
    /// Internal-only initializer — users get this via `withGIL`.
    init() {}

    /// Acquire the GIL and execute a closure.
    public static func withGIL<T>(_ body: (PythonHandle) throws -> T) rethrows -> T {
        let gstate = PyGILState_Ensure()
        defer { PyGILState_Release(gstate) }
        return try body(PythonHandle())
    }

    /// Release the GIL for CPU-bound Swift work that doesn't touch Python objects.
    public func allowThreads<T>(_ body: () throws -> T) rethrows -> T {
        let save = PyEval_SaveThread()
        defer { PyEval_RestoreThread(save) }
        return try body()
    }
}

// MARK: - Conversion Error

/// Errors that can occur during Swift ↔ Python type conversion.
public enum PythonConversionError: Error, @unchecked Sendable {
    case typeMismatch(expected: String, got: String)
    case overflow(value: String, targetType: String)
    case nullPointer
    case pythonError
}
