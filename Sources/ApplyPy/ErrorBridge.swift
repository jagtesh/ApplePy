// ApplyPy – Error Bridging
// Maps Swift errors to Python exceptions and vice versa.

@preconcurrency import ApplyPyFFI

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
            let typeObj = ApplyPy_TYPE(pType)
            typeName = String(cString: typeObj!.pointee.tp_name)
            ApplyPy_DECREF(pType)
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
                ApplyPy_DECREF(strRepr)
            } else {
                message = "(unable to format error)"
            }
            ApplyPy_DECREF(pValue)
        } else {
            message = "(no message)"
        }

        if let pTraceback = pTraceback {
            ApplyPy_DECREF(pTraceback)
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
