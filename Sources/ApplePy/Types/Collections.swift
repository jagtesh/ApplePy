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
        guard count >= 0 else {
            PyErr_Clear()
            throw PythonConversionError.pythonError
        }
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
            // PyList_SetItem steals the reference to pyItem regardless of
            // success or failure, so we must not decref it ourselves.
            guard PyList_SetItem(list, Py_ssize_t(i), pyItem) == 0 else {
                ApplePy_DECREF(list)
                return nil
            }
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
        // PyDict_Next returns 0 both when iteration is complete and when an
        // exception occurred (e.g. the dict was mutated during iteration).
        // Without this check a real Python exception would be silently dropped.
        if PyErr_Occurred() != nil {
            throw PythonConversionError.pythonError
        }
        return result
    }
}

extension Dictionary: IntoPyObject where Key: IntoPyObject, Value: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let dict = PyDict_New() else { return nil }
        for (key, value) in self {
            guard let pyKey = key.intoPython(py: py) else {
                ApplePy_DECREF(dict)
                return nil
            }
            guard let pyValue = value.intoPython(py: py) else {
                ApplePy_DECREF(pyKey)
                ApplePy_DECREF(dict)
                return nil
            }
            // PyDict_SetItem does NOT steal references — it increfs both key and value
            let rc = PyDict_SetItem(dict, pyKey, pyValue)
            ApplePy_DECREF(pyKey)
            ApplePy_DECREF(pyValue)
            guard rc == 0 else {
                ApplePy_DECREF(dict)
                return nil
            }
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
        guard count >= 0 else {
            PyErr_Clear()
            throw PythonConversionError.pythonError
        }
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
        // PyIter_Next returns NULL both when iteration is complete and when an
        // exception occurred. Without this check a real Python exception raised
        // mid-iteration would be silently discarded.
        if PyErr_Occurred() != nil {
            throw PythonConversionError.pythonError
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
            let rc = PySet_Add(pySet, pyItem)
            ApplePy_DECREF(pyItem)
            guard rc == 0 else {
                ApplePy_DECREF(pySet)
                return nil
            }
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
        guard let item0 = PyTuple_GetItem(obj, 0), let item1 = PyTuple_GetItem(obj, 1) else {
            throw PythonConversionError.nullPointer
        }
        let a = try A.fromPython(item0, py: py)
        let b = try B.fromPython(item1, py: py)
        return PyTuple2(a, b)
    }
}

extension PyTuple2: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let tuple = PyTuple_New(2) else { return nil }
        guard let pa = _0.intoPython(py: py) else {
            ApplePy_DECREF(tuple)
            return nil
        }
        guard let pb = _1.intoPython(py: py) else {
            ApplePy_DECREF(pa)
            ApplePy_DECREF(tuple)
            return nil
        }
        // PyTuple_SetItem steals the reference regardless of success/failure.
        guard PyTuple_SetItem(tuple, 0, pa) == 0, PyTuple_SetItem(tuple, 1, pb) == 0 else {
            ApplePy_DECREF(tuple)
            return nil
        }
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
        guard let item0 = PyTuple_GetItem(obj, 0),
              let item1 = PyTuple_GetItem(obj, 1),
              let item2 = PyTuple_GetItem(obj, 2) else {
            throw PythonConversionError.nullPointer
        }
        let a = try A.fromPython(item0, py: py)
        let b = try B.fromPython(item1, py: py)
        let c = try C.fromPython(item2, py: py)
        return PyTuple3(a, b, c)
    }
}

extension PyTuple3: IntoPyObject {
    public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
        guard let tuple = PyTuple_New(3) else { return nil }
        guard let pa = _0.intoPython(py: py) else {
            ApplePy_DECREF(tuple)
            return nil
        }
        guard let pb = _1.intoPython(py: py) else {
            ApplePy_DECREF(pa)
            ApplePy_DECREF(tuple)
            return nil
        }
        guard let pc = _2.intoPython(py: py) else {
            ApplePy_DECREF(pa)
            ApplePy_DECREF(pb)
            ApplePy_DECREF(tuple)
            return nil
        }
        guard PyTuple_SetItem(tuple, 0, pa) == 0,
              PyTuple_SetItem(tuple, 1, pb) == 0,
              PyTuple_SetItem(tuple, 2, pc) == 0 else {
            ApplePy_DECREF(tuple)
            return nil
        }
        return tuple
    }
}
