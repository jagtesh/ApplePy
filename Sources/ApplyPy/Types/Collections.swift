// ApplyPy – Collection Type Conversions
// Array, Dictionary, Optional ↔ Python list, dict, None

import ApplyPyFFI

// MARK: - Array

extension Array: FromPyObject where Element: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> [Element] {
        guard ApplyPy_ListCheck(obj) != 0 else {
            let typeName = String(cString: ApplyPy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "list", got: typeName)
        }
        let count = PyList_Size(obj)
        var result: [Element] = []
        result.reserveCapacity(Int(count))
        for i in 0..<count {
            guard let item = PyList_GetItem(obj, i) else {
                throw PythonConversionError.nullPointer
            }
            // PyList_GetItem returns a borrowed reference — no need to decref
            result.append(try Element.fromPython(item, py: py))
        }
        return result
    }
}

extension Array: IntoPyObject where Element: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let list = PyList_New(Py_ssize_t(self.count)) else { return nil }
        for (i, element) in self.enumerated() {
            guard let pyItem = element.intoPython(py: py) else {
                ApplyPy_DECREF(list)
                return nil
            }
            // PyList_SetItem steals a reference, so we don't need to decref pyItem
            PyList_SetItem(list, Py_ssize_t(i), pyItem)
        }
        return list
    }
}

// MARK: - Dictionary

extension Dictionary: FromPyObject where Key: FromPyObject & Hashable, Value: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> [Key: Value] {
        guard ApplyPy_DictCheck(obj) != 0 else {
            let typeName = String(cString: ApplyPy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "dict", got: typeName)
        }
        var result: [Key: Value] = [:]
        var pos: Py_ssize_t = 0
        var pyKey: UnsafeMutablePointer<PyObject>?
        var pyValue: UnsafeMutablePointer<PyObject>?
        while PyDict_Next(obj, &pos, &pyKey, &pyValue) != 0 {
            guard let k = pyKey, let v = pyValue else { continue }
            let key = try Key.fromPython(k, py: py)
            let value = try Value.fromPython(v, py: py)
            result[key] = value
        }
        return result
    }
}

extension Dictionary: IntoPyObject where Key: IntoPyObject, Value: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let dict = PyDict_New() else { return nil }
        for (key, value) in self {
            guard let pyKey = key.intoPython(py: py),
                  let pyValue = value.intoPython(py: py) else {
                ApplyPy_DECREF(dict)
                return nil
            }
            // PyDict_SetItem does NOT steal references — it increfs both key and value
            PyDict_SetItem(dict, pyKey, pyValue)
            ApplyPy_DECREF(pyKey)
            ApplyPy_DECREF(pyValue)
        }
        return dict
    }
}

// MARK: - Optional

extension Optional: FromPyObject where Wrapped: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Wrapped? {
        if ApplyPy_IsNone(obj) != 0 {
            return nil
        }
        return try Wrapped.fromPython(obj, py: py)
    }
}

extension Optional: IntoPyObject where Wrapped: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        switch self {
        case .none:
            return ApplyPy_None()
        case .some(let value):
            return value.intoPython(py: py)
        }
    }
}
