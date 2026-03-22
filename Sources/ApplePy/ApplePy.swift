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

/// A lightweight token proving that the current thread holds the Python GIL.
/// All functions that interact with Python objects should accept a `PythonHandle`
/// to prove the GIL is held at the call site.
///
/// `PythonHandle` is copyable for protocol compatibility. For scope-enforced
/// GIL management, use `GILGuard.withGIL` which provides both a `GILGuard`
/// (non-copyable, owns the GIL) and a `PythonHandle` (for API calls).
///
/// ## Usage
/// ```swift
/// GILGuard.withGIL { guard, py in
///     let result = myFunc.intoPython(py: py)
///     // guard ensures GIL is held for this entire scope
///     // py can be passed to FromPyObject/IntoPyObject methods
/// }
/// ```
public struct PythonHandle: Sendable {
    /// Internal-only initializer — users get this via `GILGuard.withGIL`.
    /// Direct construction is allowed for macro-generated code.
    public init() {}

    /// Acquire the GIL and execute a closure.
    /// For stricter scope enforcement, prefer `GILGuard.withGIL`.
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

// MARK: - GILGuard (~Copyable)

/// A non-copyable GIL ownership token. When this value exists, the GIL is held.
/// When it is consumed/destroyed, the GIL is released.
///
/// `GILGuard` cannot be copied, moved out of scope, or stored — it enforces
/// that Python object access happens only within the `withGIL` closure.
///
/// ```swift
/// GILGuard.withGIL { guard, py in
///     // guard: GILGuard — proves GIL is held, can't escape
///     // py: PythonHandle — lightweight token for API calls
///     let obj = value.intoPython(py: py)
/// }
/// // GIL automatically released here
/// ```
public struct GILGuard: ~Copyable {
    @usableFromInline
    let gstate: PyGILState_STATE

    @usableFromInline
    init(gstate: PyGILState_STATE) {
        self.gstate = gstate
    }

    deinit {
        PyGILState_Release(gstate)
    }

    /// Acquire the GIL and execute a closure with both a GILGuard and PythonHandle.
    /// The GILGuard cannot escape the closure — compile-time enforcement.
    /// The PythonHandle is a lightweight token for passing to protocol methods.
    @inlinable
    public static func withGIL<T>(_ body: (borrowing GILGuard, PythonHandle) throws -> T) rethrows -> T {
        let guard_ = GILGuard(gstate: PyGILState_Ensure())
        return try body(guard_, PythonHandle())
    }

    /// Release the GIL temporarily for CPU-bound work.
    @inlinable
    public borrowing func allowThreads<T>(_ body: () throws -> T) rethrows -> T {
        let save = PyEval_SaveThread()
        defer { PyEval_RestoreThread(save) }
        return try body()
    }

    /// Assert the GIL is held (debug builds only).
    @inlinable
    public borrowing func assertGILHeld() {
        #if DEBUG
        assert(PyGILState_Check() != 0, "GIL is not held on current thread")
        #endif
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
