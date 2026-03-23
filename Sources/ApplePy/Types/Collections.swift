// ApplePy – Collection Type Conversions
// Array, Dictionary, Optional, Set, Tuple ↔ Python list, dict, None, set, tuple

import ApplePyFFI

// MARK: - Array

extension Array: FromPyObject where Element: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> [Element] {
        guard ApplePy_ListCheck(obj) != 0 else {
            let typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
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
            do {
                result.append(try Element.fromPython(item, py: py))
            } catch {
                throw PythonConversionError.collectionElement(
                    collection: "list", index: Int(i), key: nil, innerError: error)
            }
        }
        return result
    }
}

extension Array: IntoPyObject where Element: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let list = PyList_New(Py_ssize_t(self.count)) else { return nil }
        for (i, element) in self.enumerated() {
            guard let pyItem = element.intoPython(py: py) else {
                ApplePy_DECREF(list)
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
        guard ApplePy_DictCheck(obj) != 0 else {
            let typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "dict", got: typeName)
        }
        var result: [Key: Value] = [:]
        var pos: Py_ssize_t = 0
        var pyKey: UnsafeMutablePointer<PyObject>?
        var pyValue: UnsafeMutablePointer<PyObject>?
        var index = 0
        while PyDict_Next(obj, &pos, &pyKey, &pyValue) != 0 {
            guard let k = pyKey, let v = pyValue else { continue }
            let key = try Key.fromPython(k, py: py)
            do {
                let value = try Value.fromPython(v, py: py)
                result[key] = value
            } catch {
                // Try to get a string representation of the key for the error message
                let keyStr: String?
                if let strRepr = PyObject_Str(k), let cStr = PyUnicode_AsUTF8(strRepr) {
                    keyStr = String(cString: cStr)
                    ApplePy_DECREF(strRepr)
                } else {
                    PyErr_Clear()
                    keyStr = nil
                }
                throw PythonConversionError.collectionElement(
                    collection: "dict", index: index, key: keyStr, innerError: error)
            }
            index += 1
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
                ApplePy_DECREF(dict)
                return nil
            }
            // PyDict_SetItem does NOT steal references — it increfs both key and value
            PyDict_SetItem(dict, pyKey, pyValue)
            ApplePy_DECREF(pyKey)
            ApplePy_DECREF(pyValue)
        }
        return dict
    }
}

// MARK: - Optional

extension Optional: FromPyObject where Wrapped: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Wrapped? {
        if ApplePy_IsNone(obj) != 0 {
            return nil
        }
        return try Wrapped.fromPython(obj, py: py)
    }
}

extension Optional: IntoPyObject where Wrapped: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        switch self {
        case .none:
            return ApplePy_None()
        case .some(let value):
            return value.intoPython(py: py)
        }
    }
}

// MARK: - Set

extension Set: FromPyObject where Element: FromPyObject & Hashable {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> Set<Element> {
        guard ApplePy_SetCheck(obj) != 0 else {
            let typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "set", got: typeName)
        }
        let count = PySet_Size(obj)
        var result = Set<Element>(minimumCapacity: Int(count))
        // Iterate via PyObject_GetIter
        guard let iter = PyObject_GetIter(obj) else {
            throw PythonConversionError.pythonError
        }
        defer { ApplePy_DECREF(iter) }
        while let item = PyIter_Next(iter) {
            defer { ApplePy_DECREF(item) }
            result.insert(try Element.fromPython(item, py: py))
        }
        return result
    }
}

extension Set: IntoPyObject where Element: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let pySet = PySet_New(nil) else { return nil }
        for element in self {
            guard let pyItem = element.intoPython(py: py) else {
                ApplePy_DECREF(pySet)
                return nil
            }
            // PySet_Add does NOT steal a reference
            PySet_Add(pySet, pyItem)
            ApplePy_DECREF(pyItem)
        }
        return pySet
    }
}

// MARK: - Tuple2

/// A 2-element tuple bridgeable to/from Python.
public struct PyTuple2<A: FromPyObject & IntoPyObject, B: FromPyObject & IntoPyObject> {
    public var _0: A
    public var _1: B
    public init(_ a: A, _ b: B) { self._0 = a; self._1 = b }
}

extension PyTuple2: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> PyTuple2 {
        guard ApplePy_TupleCheck(obj) != 0 else {
            let typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "tuple", got: typeName)
        }
        guard PyTuple_Size(obj) == 2 else {
            throw PythonConversionError.typeMismatch(expected: "tuple of 2", got: "tuple of \(PyTuple_Size(obj))")
        }
        let a = try A.fromPython(PyTuple_GetItem(obj, 0)!, py: py)
        let b = try B.fromPython(PyTuple_GetItem(obj, 1)!, py: py)
        return PyTuple2(a, b)
    }
}

extension PyTuple2: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let tuple = PyTuple_New(2) else { return nil }
        guard let pa = _0.intoPython(py: py), let pb = _1.intoPython(py: py) else {
            ApplePy_DECREF(tuple)
            return nil
        }
        PyTuple_SetItem(tuple, 0, pa)  // steals reference
        PyTuple_SetItem(tuple, 1, pb)
        return tuple
    }
}

// MARK: - Tuple3

/// A 3-element tuple bridgeable to/from Python.
public struct PyTuple3<A: FromPyObject & IntoPyObject, B: FromPyObject & IntoPyObject, C: FromPyObject & IntoPyObject> {
    public var _0: A
    public var _1: B
    public var _2: C
    public init(_ a: A, _ b: B, _ c: C) { self._0 = a; self._1 = b; self._2 = c }
}

extension PyTuple3: FromPyObject {
    public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> PyTuple3 {
        guard ApplePy_TupleCheck(obj) != 0 else {
            let typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
            throw PythonConversionError.typeMismatch(expected: "tuple", got: typeName)
        }
        guard PyTuple_Size(obj) == 3 else {
            throw PythonConversionError.typeMismatch(expected: "tuple of 3", got: "tuple of \(PyTuple_Size(obj))")
        }
        let a = try A.fromPython(PyTuple_GetItem(obj, 0)!, py: py)
        let b = try B.fromPython(PyTuple_GetItem(obj, 1)!, py: py)
        let c = try C.fromPython(PyTuple_GetItem(obj, 2)!, py: py)
        return PyTuple3(a, b, c)
    }
}

extension PyTuple3: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let tuple = PyTuple_New(3) else { return nil }
        guard let pa = _0.intoPython(py: py), let pb = _1.intoPython(py: py), let pc = _2.intoPython(py: py) else {
            ApplePy_DECREF(tuple)
            return nil
        }
        PyTuple_SetItem(tuple, 0, pa)
        PyTuple_SetItem(tuple, 1, pb)
        PyTuple_SetItem(tuple, 2, pc)
        return tuple
    }
}
