// hello.swift — Manual Python Extension in Swift (no macros)
// This demonstrates the raw CPython API from Swift, proving the FFI works.
// The macros in Phase 2 will auto-generate code like this.
//
// Key learning: Swift can't call variadic C functions like PyArg_ParseTuple,
// so we parse arguments manually using PyTuple_GetItem + type-specific extractors.
// String literals for PyMethodDef/PyModuleDef must have stable (non-temporary) pointers.

import CPythonShim

// ─── greet(name: str) -> str ────────────────────────────────────────────────

@_cdecl("py_greet")
public func py_greet(
    _ self_: UnsafeMutablePointer<PyObject>?,
    _ args: UnsafeMutablePointer<PyObject>?
) -> UnsafeMutablePointer<PyObject>? {
    guard let args = args else {
        PyErr_SetString(PyExc_TypeError, "greet() requires exactly 1 argument")
        return nil
    }

    let nArgs = PyTuple_Size(args)
    guard nArgs == 1 else {
        PyErr_SetString(PyExc_TypeError, "greet() takes exactly 1 argument")
        return nil
    }

    guard let nameObj = PyTuple_GetItem(args, 0),
          let cStr = PyUnicode_AsUTF8(nameObj) else {
        PyErr_SetString(PyExc_TypeError, "greet() argument must be a string")
        return nil
    }

    let name = String(cString: cStr)
    let result = "Hello, \(name)! (from Swift)"
    return result.withCString { PyUnicode_FromString($0) }
}

// ─── add(a: int, b: int) -> int ─────────────────────────────────────────────

@_cdecl("py_add")
public func py_add(
    _ self_: UnsafeMutablePointer<PyObject>?,
    _ args: UnsafeMutablePointer<PyObject>?
) -> UnsafeMutablePointer<PyObject>? {
    guard let args = args else {
        PyErr_SetString(PyExc_TypeError, "add() requires exactly 2 arguments")
        return nil
    }

    let nArgs = PyTuple_Size(args)
    guard nArgs == 2 else {
        PyErr_SetString(PyExc_TypeError, "add() takes exactly 2 arguments")
        return nil
    }

    guard let aObj = PyTuple_GetItem(args, 0),
          let bObj = PyTuple_GetItem(args, 1) else { return nil }

    let a = PyLong_AsLongLong(aObj)
    if a == -1 && PyErr_Occurred() != nil { return nil }
    let b = PyLong_AsLongLong(bObj)
    if b == -1 && PyErr_Occurred() != nil { return nil }

    return PyLong_FromLongLong(a + b)
}

// ─── Method Table ───────────────────────────────────────────────────────────
// All string constants that go into PyMethodDef / PyModuleDef must outlive the
// module. We use strdup() to allocate permanent C copies.

private let kGreetName: UnsafePointer<CChar> = {
    "greet".withCString { UnsafePointer(strdup($0)!) }
}()

private let kAddName: UnsafePointer<CChar> = {
    "add".withCString { UnsafePointer(strdup($0)!) }
}()

private let kModuleName: UnsafePointer<CChar> = {
    "hello".withCString { UnsafePointer(strdup($0)!) }
}()

private let kModuleDoc: UnsafePointer<CChar> = {
    "A hello-world Python extension written in Swift.".withCString { UnsafePointer(strdup($0)!) }
}()

private var helloMethods: [PyMethodDef] = [
    PyMethodDef(ml_name: kGreetName, ml_meth: py_greet, ml_flags: METH_VARARGS, ml_doc: nil),
    PyMethodDef(ml_name: kAddName, ml_meth: py_add, ml_flags: METH_VARARGS, ml_doc: nil),
    PyMethodDef(ml_name: nil, ml_meth: nil, ml_flags: 0, ml_doc: nil),  // sentinel
]

// ─── Module init (must be a global) ─────────────────────────────────────────

private var moduleDef = ApplePy_MakeModuleDef(kModuleName, kModuleDoc, -1, &helloMethods)

@_cdecl("PyInit_hello")
public func PyInit_hello() -> UnsafeMutablePointer<PyObject>? {
    return ApplePy_ModuleCreate(&moduleDef)
}
