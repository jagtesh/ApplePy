// ApplyPy – Primitive Type Conversions
// Int, Double, Float, Bool, String ↔ Python int, float, bool, str

import ApplyPyFFI

// MARK: - Int

extension Int: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Int {
        let value = PyLong_AsLongLong(obj)
        if value == -1 && PyErr_Occurred() != nil {
            PyErr_Clear()
            let typeName = String(cString: ApplyPy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "int", got: typeName)
        }
        return Int(value)
    }
}

extension Int: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        return PyLong_FromLongLong(Int64(self))
    }
}

// MARK: - Double

extension Double: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Double {
        let value = PyFloat_AsDouble(obj)
        if value == -1.0 && PyErr_Occurred() != nil {
            PyErr_Clear()
            let typeName = String(cString: ApplyPy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "float", got: typeName)
        }
        return value
    }
}

extension Double: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        return PyFloat_FromDouble(self)
    }
}

// MARK: - Float

extension Float: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Float {
        let d = try Double.fromPython(obj, py: py)
        return Float(d)
    }
}

extension Float: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        return PyFloat_FromDouble(Double(self))
    }
}

// MARK: - Bool

extension Bool: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Bool {
        let result = PyObject_IsTrue(obj)
        if result == -1 {
            PyErr_Clear()
            let typeName = String(cString: ApplyPy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "bool", got: typeName)
        }
        return result == 1
    }
}

extension Bool: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        return PyBool_FromLong(self ? 1 : 0)
    }
}

// MARK: - String

extension String: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> String {
        guard let cStr = PyUnicode_AsUTF8(obj) else {
            PyErr_Clear()
            let typeName = String(cString: ApplyPy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "str", got: typeName)
        }
        return String(cString: cStr)
    }
}

extension String: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        return self.withCString { cStr in
            PyUnicode_FromString(cStr)
        }
    }
}
