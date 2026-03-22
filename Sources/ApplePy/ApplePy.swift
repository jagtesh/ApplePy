// ApplePy – Core Library
// Re-exports FFI and macro declarations, provides type conversions and runtime support.

@_exported import ApplePyFFI
@_exported import ApplePyClient

// MARK: - PyObjectPtr

/// A pointer to a CPython `PyObject`. This is the fundamental type bridged between Swift and Python.
///
/// > Warning: `PyObjectPtr` should only be accessed while holding the GIL. Accessing it from
/// > a thread that doesn't hold the GIL is undefined behavior.
public typealias PyObjectPtr = UnsafeMutablePointer<PyObject>?

// MARK: - PythonHandle (GIL Token)

/// A token proving that the current thread holds the Python GIL.
/// All functions that interact with Python objects should accept a `PythonHandle`
/// to prove the GIL is held at the call site.
///
/// ## Usage
/// ```swift
/// PythonHandle.withGIL { py in
///     let result = myFunc.intoPython(py: py)
///     // ... use Python objects safely ...
/// }
/// ```
///
/// ## Thread Safety
/// The GIL is acquired on the current thread. Do not pass `PythonHandle`
/// to other threads — use `allowThreads` to release the GIL for CPU-bound work.
public struct PythonHandle: Sendable {
    /// Internal-only initializer — users get this via `withGIL`.
    /// Direct construction is allowed for macro-generated code.
    public init() {}

    /// Acquire the GIL and execute a closure.
    /// This is the primary entry point for all Python operations.
    public static func withGIL<T>(_ body: (PythonHandle) throws -> T) rethrows -> T {
        let gstate = PyGILState_Ensure()
        defer { PyGILState_Release(gstate) }
        return try body(PythonHandle())
    }

    /// Release the GIL for CPU-bound Swift work that doesn't touch Python objects.
    /// Python threads can run while the GIL is released.
    public func allowThreads<T>(_ body: () throws -> T) rethrows -> T {
        let save = PyEval_SaveThread()
        defer { PyEval_RestoreThread(save) }
        return try body()
    }
}

// MARK: - @PythonActor

/// A global actor that ensures Python-related work runs on a single thread.
/// Use this for Swift concurrency integration:
///
/// ```swift
/// @PythonActor
/// func doWork() async {
///     // Guaranteed to run on the Python actor's executor
/// }
/// ```
@globalActor
public actor PythonActor {
    public static let shared = PythonActor()
}

// MARK: - Conversion Error

/// Errors that can occur during Swift ↔ Python type conversion.
public enum PythonConversionError: Error, @unchecked Sendable {
    case typeMismatch(expected: String, got: String)
    case overflow(value: String, targetType: String)
    case nullPointer
    case pythonError
}
