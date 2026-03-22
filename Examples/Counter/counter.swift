// counter.swift — Manual Python Class Extension in Swift (no macros)
// This demonstrates exposing a Swift class as a Python type via raw CPython API.
// The @PyClass / @PyMethod macros in Phase 2 will auto-generate code like this.
//
// Python usage:
//   from counter import Counter
//   c = Counter(10)
//   c.increment()
//   c.increment()
//   print(c.value())  # 12

import CPythonShim

// ─── The Swift type we're wrapping ──────────────────────────────────────────

/// A simple counter — this is the "real" Swift code a user would write.
final class CounterBox {
    var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    func increment() {
        count += 1
    }

    func value() -> Int {
        return count
    }
}

// ─── PyObject storage layout ────────────────────────────────────────────────
// We store a pointer to the Swift CounterBox inside the PyObject's memory.
// CPython allocates `basicsize` bytes for us; we use the space after PyObject_HEAD
// to store an opaque pointer to our Swift object.

/// Opaque pointer to the Swift CounterBox, stored in the Python object.
/// This struct mirrors what PyObject_HEAD + one pointer looks like.
struct CounterPyObject {
    var ob_base: PyObject
    var swiftPtr: UnsafeMutableRawPointer?  // Unmanaged<CounterBox> stored here
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Get the CounterBox from a Python object, without changing ARC refcount.
private func getBox(_ pyObj: UnsafeMutablePointer<PyObject>) -> CounterBox {
    let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: CounterPyObject.self)
    return Unmanaged<CounterBox>.fromOpaque(typed.pointee.swiftPtr!).takeUnretainedValue()
}

/// Store a CounterBox into a Python object (retains the Swift object).
private func setBox(_ pyObj: UnsafeMutablePointer<PyObject>, _ box: CounterBox) {
    let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: CounterPyObject.self)
    typed.pointee.swiftPtr = Unmanaged.passRetained(box).toOpaque()
}

/// Release the CounterBox stored in a Python object.
private func releaseBox(_ pyObj: UnsafeMutablePointer<PyObject>) {
    let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: CounterPyObject.self)
    if let ptr = typed.pointee.swiftPtr {
        Unmanaged<CounterBox>.fromOpaque(ptr).release()
        typed.pointee.swiftPtr = nil
    }
}

// ─── Type slots ─────────────────────────────────────────────────────────────

/// tp_new: Allocate the PyObject shell (but don't initialize the Swift object yet).
@_cdecl("Counter_tp_new")
public func Counter_tp_new(
    _ type: UnsafeMutablePointer<PyTypeObject>?,
    _ args: UnsafeMutablePointer<PyObject>?,
    _ kwargs: UnsafeMutablePointer<PyObject>?
) -> UnsafeMutablePointer<PyObject>? {
    // Allocate the PyObject with enough room for our swiftPtr field
    guard let type = type else { return nil }
    guard let self_ = type.pointee.tp_alloc?(type, 0) else { return nil }
    // Initialize the swiftPtr to nil (tp_init will fill it in)
    let typed = UnsafeMutableRawPointer(self_).assumingMemoryBound(to: CounterPyObject.self)
    typed.pointee.swiftPtr = nil
    return self_
}

/// tp_init: Initialize the Swift CounterBox from Python __init__ args.
@_cdecl("Counter_tp_init")
public func Counter_tp_init(
    _ self_: UnsafeMutablePointer<PyObject>?,
    _ args: UnsafeMutablePointer<PyObject>?,
    _ kwargs: UnsafeMutablePointer<PyObject>?
) -> Int32 {
    guard let self_ = self_ else { return -1 }

    // Parse the optional initial count argument
    var initialCount: Int = 0
    if let args = args {
        let nArgs = PyTuple_Size(args)
        if nArgs > 1 {
            PyErr_SetString(PyExc_TypeError, "Counter() takes at most 1 argument")
            return -1
        }
        if nArgs == 1 {
            guard let arg0 = PyTuple_GetItem(args, 0) else { return -1 }
            let val = PyLong_AsLongLong(arg0)
            if val == -1 && PyErr_Occurred() != nil { return -1 }
            initialCount = Int(val)
        }
    }

    // Release any existing box (in case __init__ is called again)
    releaseBox(self_)

    // Create and store the Swift object
    let box = CounterBox(count: initialCount)
    setBox(self_, box)

    return 0  // success
}

/// tp_dealloc: Release the Swift object and free the PyObject.
@_cdecl("Counter_tp_dealloc")
public func Counter_tp_dealloc(_ self_: UnsafeMutablePointer<PyObject>?) {
    guard let self_ = self_ else { return }
    // Release the ARC reference to our Swift CounterBox
    releaseBox(self_)
    // Free the PyObject memory
    let type = ApplePy_TYPE(self_)
    type?.pointee.tp_free?(UnsafeMutableRawPointer(self_))
}

// ─── Method wrappers ────────────────────────────────────────────────────────

/// increment() — mutates the counter
@_cdecl("Counter_increment")
public func Counter_increment(
    _ self_: UnsafeMutablePointer<PyObject>?,
    _ args: UnsafeMutablePointer<PyObject>?
) -> UnsafeMutablePointer<PyObject>? {
    guard let self_ = self_ else { return nil }
    let box = getBox(self_)
    box.increment()
    return ApplePy_None()
}

/// value() -> int — returns the current count
@_cdecl("Counter_value")
public func Counter_value(
    _ self_: UnsafeMutablePointer<PyObject>?,
    _ args: UnsafeMutablePointer<PyObject>?
) -> UnsafeMutablePointer<PyObject>? {
    guard let self_ = self_ else { return nil }
    let box = getBox(self_)
    return PyLong_FromLongLong(Int64(box.value()))
}

/// __repr__ — string representation
@_cdecl("Counter_repr")
public func Counter_repr(
    _ self_: UnsafeMutablePointer<PyObject>?
) -> UnsafeMutablePointer<PyObject>? {
    guard let self_ = self_ else { return nil }
    let box = getBox(self_)
    let repr = "Counter(\(box.count))"
    return repr.withCString { PyUnicode_FromString($0) }
}

// ─── Method table ───────────────────────────────────────────────────────────

private let kIncName = "increment".withCString { UnsafePointer(strdup($0)!) }
private let kIncDoc  = "Increment the counter by 1.".withCString { UnsafePointer(strdup($0)!) }
private let kValName = "value".withCString { UnsafePointer(strdup($0)!) }
private let kValDoc  = "Return the current count.".withCString { UnsafePointer(strdup($0)!) }

private var counterMethods: [PyMethodDef] = [
    PyMethodDef(ml_name: kIncName, ml_meth: Counter_increment, ml_flags: METH_NOARGS, ml_doc: kIncDoc),
    PyMethodDef(ml_name: kValName, ml_meth: Counter_value, ml_flags: METH_NOARGS, ml_doc: kValDoc),
    PyMethodDef(ml_name: nil, ml_meth: nil, ml_flags: 0, ml_doc: nil),  // sentinel
]

// ─── Type definition via PyType_Spec ────────────────────────────────────────

private let kTypeName = "counter.Counter".withCString { UnsafePointer(strdup($0)!) }

private var counterSlots: [PyType_Slot] = [
    PyType_Slot(slot: Py_tp_new,     pfunc: unsafeBitCast(Counter_tp_new     as @convention(c) (UnsafeMutablePointer<PyTypeObject>?, UnsafeMutablePointer<PyObject>?, UnsafeMutablePointer<PyObject>?) -> UnsafeMutablePointer<PyObject>?, to: UnsafeMutableRawPointer.self)),
    PyType_Slot(slot: Py_tp_init,    pfunc: unsafeBitCast(Counter_tp_init    as @convention(c) (UnsafeMutablePointer<PyObject>?, UnsafeMutablePointer<PyObject>?, UnsafeMutablePointer<PyObject>?) -> Int32, to: UnsafeMutableRawPointer.self)),
    PyType_Slot(slot: Py_tp_dealloc, pfunc: unsafeBitCast(Counter_tp_dealloc as @convention(c) (UnsafeMutablePointer<PyObject>?) -> Void, to: UnsafeMutableRawPointer.self)),
    PyType_Slot(slot: Py_tp_repr,    pfunc: unsafeBitCast(Counter_repr       as @convention(c) (UnsafeMutablePointer<PyObject>?) -> UnsafeMutablePointer<PyObject>?, to: UnsafeMutableRawPointer.self)),
    PyType_Slot(slot: Py_tp_methods, pfunc: UnsafeMutableRawPointer(&counterMethods)),
    PyType_Slot(slot: 0, pfunc: nil),  // sentinel
]

private var counterSpec = PyType_Spec(
    name: kTypeName,
    basicsize: Int32(MemoryLayout<CounterPyObject>.size),
    itemsize: 0,
    flags: UInt32(Py_TPFLAGS_DEFAULT) | UInt32(Py_TPFLAGS_BASETYPE),
    slots: &counterSlots
)

// ─── Module definition ──────────────────────────────────────────────────────

private let kModName = "counter".withCString { UnsafePointer(strdup($0)!) }
private let kModDoc  = "A counter module demonstrating Swift classes as Python types.".withCString { UnsafePointer(strdup($0)!) }

// No module-level functions — just the Counter type
private var moduleMethods: [PyMethodDef] = [
    PyMethodDef(ml_name: nil, ml_meth: nil, ml_flags: 0, ml_doc: nil),
]

private var moduleDef = ApplePy_MakeModuleDef(kModName, kModDoc, -1, &moduleMethods)

@_cdecl("PyInit_counter")
public func PyInit_counter() -> UnsafeMutablePointer<PyObject>? {
    // Create the module
    guard let module = ApplePy_ModuleCreate(&moduleDef) else { return nil }

    // Create the Counter type from our spec
    guard let counterType = PyType_FromSpec(&counterSpec) else {
        ApplePy_DECREF(module)
        return nil
    }

    // Add Counter to the module: counter.Counter
    let addResult = "Counter".withCString { name in
        PyModule_AddObject(module, name, counterType)
    }
    if addResult < 0 {
        ApplePy_DECREF(counterType)
        ApplePy_DECREF(module)
        return nil
    }

    return module
}
