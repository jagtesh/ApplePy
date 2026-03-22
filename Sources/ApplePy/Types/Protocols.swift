// ApplePy – Type Conversion Protocols
// These protocols define the bidirectional bridge between Swift and Python types.

import ApplePyFFI

// MARK: - FromPyObject

/// A type that can be constructed from a Python object.
///
/// Conforming types provide a way to extract a Swift value from a `PyObject*`.
/// Conversion may fail if the Python object is the wrong type or contains
/// an out-of-range value.
public protocol FromPyObject {
    /// Attempt to convert a Python object to this Swift type.
    /// - Parameters:
    ///   - obj: Pointer to the Python object.
    ///   - py: GIL token proving the GIL is held.
    /// - Throws: `PythonConversionError` if conversion fails.
    static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Self
}

// MARK: - IntoPyObject

/// A type that can be converted into a Python object.
///
/// Conforming types provide a way to create a new `PyObject*` from a Swift value.
/// The returned object has a +1 reference count (caller owns it).
public protocol IntoPyObject {
    /// Convert this Swift value into a new Python object.
    /// - Parameter py: GIL token proving the GIL is held.
    /// - Returns: A new reference to a Python object (refcount +1), or `nil` on error.
    func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>?
}

// MARK: - PyBridgeable (convenience combo)

/// A type that can be converted both to and from Python.
public typealias PyBridgeable = FromPyObject & IntoPyObject
