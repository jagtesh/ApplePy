// ApplePy – Error Bridging
// Maps Swift errors to Python exceptions and vice versa.

@preconcurrency import ApplePyFFI

// MARK: - Swift → Python

/// Describes a Python exception that was raised by CPython.
public struct PythonException: Error, CustomStringConvertible {
    /// The Python exception type name (e.g., "TypeError", "ValueError").
    public let typeName: String
    /// The exception message.
    public let message: String

    public var description: String {
        "\(typeName): \(message)"
    }

    /// Create a PythonException from the current Python error state.
    /// Clears the Python error indicator after capturing it.
    public static func fromCurrentError() -> PythonException? {
        guard PyErr_Occurred() != nil else { return nil }

        var pType: UnsafeMutablePointer<PyObject>?
        var pValue: UnsafeMutablePointer<PyObject>?
        var pTraceback: UnsafeMutablePointer<PyObject>?
        PyErr_Fetch(&pType, &pValue, &pTraceback)

        let typeName: String
        if let pType = pType {
            let typeObj = ApplePy_TYPE(pType)
            typeName = String(cString: typeObj!.pointee.tp_name)
            ApplePy_DECREF(pType)
        } else {
            typeName = "UnknownError"
        }

        let message: String
        if let pValue = pValue {
            if let strRepr = PyObject_Str(pValue) {
                if let cStr = PyUnicode_AsUTF8(strRepr) {
                    message = String(cString: cStr)
                } else {
                    message = "(unable to decode error message)"
                }
                ApplePy_DECREF(strRepr)
            } else {
                message = "(unable to format error)"
            }
            ApplePy_DECREF(pValue)
        } else {
            message = "(no message)"
        }

        if let pTraceback = pTraceback {
            ApplePy_DECREF(pTraceback)
        }

        return PythonException(typeName: typeName, message: message)
    }
}

// MARK: - Helper for setting Python exceptions from Swift errors

/// Set a Python exception from a Swift Error.
/// Uses RuntimeError by default. The macro-generated code calls this in catch blocks.
@inlinable
public func setPythonException(_ error: any Error) {
    let message = String(describing: error)
    message.withCString {
        PyErr_SetString(PyExc_RuntimeError, $0)
    }
}

/// Set a Python TypeError.
@inlinable
public func setPythonTypeError(_ message: String) {
    message.withCString {
        PyErr_SetString(PyExc_TypeError, $0)
    }
}

/// Set a Python ValueError.
@inlinable
public func setPythonValueError(_ message: String) {
    message.withCString {
        PyErr_SetString(PyExc_ValueError, $0)
    }
}

/// Check if a Python exception is currently set and throw it as a Swift error.
/// Use this after calling CPython functions that may set an error.
public func checkPythonError() throws {
    if let exc = PythonException.fromCurrentError() {
        throw exc
    }
}

// MARK: - Custom Exception Types

/// A custom Python exception type registered at module init time.
/// Create these and register them in your module to use domain-specific exception types.
///
/// ```swift
/// let MyError = PyExceptionType(name: "mylib.MyError", doc: "Custom error")
///
/// // In setPythonException:
/// MyError.raise("something went wrong")
/// ```
public final class PyExceptionType: @unchecked Sendable {
    /// The Python exception type object.
    public private(set) var pyType: UnsafeMutablePointer<PyObject>?
    /// The fully qualified name (e.g., "mylib.MyError").
    public let qualifiedName: String

    /// Create a custom exception type.
    /// - Parameters:
    ///   - name: Fully qualified name (e.g., "mylib.MyError")
    ///   - doc: Optional docstring
    ///   - base: Base exception type (defaults to RuntimeError)
    public init(name: String, doc: String? = nil, base: UnsafeMutablePointer<PyObject>? = nil) {
        self.qualifiedName = name
        // PyErr_NewException creates a new exception class
        let baseType = base ?? PyExc_RuntimeError
        self.pyType = name.withCString { namePtr in
            PyErr_NewException(namePtr, baseType, nil)
        }
    }

    /// Register this exception type in a Python module.
    /// Call this during module initialization.
    @discardableResult
    public func register(in module: UnsafeMutablePointer<PyObject>) -> Bool {
        guard let pyType = pyType else { return false }
        let shortName: String
        if let dotIdx = qualifiedName.lastIndex(of: ".") {
            shortName = String(qualifiedName[qualifiedName.index(after: dotIdx)...])
        } else {
            shortName = qualifiedName
        }
        ApplePy_INCREF(pyType)
        return shortName.withCString { namePtr in
            PyModule_AddObject(module, namePtr, pyType) == 0
        }
    }

    /// Raise this exception with a message.
    public func raise(_ message: String) {
        guard let pyType = pyType else { return }
        message.withCString {
            PyErr_SetString(pyType, $0)
        }
    }
}

// MARK: - PyExceptionMapping Protocol

/// Conform your Swift `Error` types to this protocol to control which
/// Python exception type they map to.
///
/// ```swift
/// enum MyError: Error, PyExceptionMapping {
///     case invalidInput(String)
///     case notFound(String)
///
///     var pythonExceptionType: PyExceptionType { MyErrors.invalidInput }
///     var pythonMessage: String {
///         switch self {
///         case .invalidInput(let msg): return msg
///         case .notFound(let msg): return msg
///         }
///     }
/// }
/// ```
public protocol PyExceptionMapping: Error {
    /// The Python exception type to raise for this error.
    var pythonExceptionType: PyExceptionType { get }
    /// The message to include with the exception.
    var pythonMessage: String { get }
}

/// Set a Python exception from any Error, using PyExceptionMapping if available.
@inlinable
public func setPythonExceptionMapped(_ error: any Error) {
    if let mapped = error as? PyExceptionMapping {
        mapped.pythonExceptionType.raise(mapped.pythonMessage)
    } else {
        setPythonException(error)
    }
}
