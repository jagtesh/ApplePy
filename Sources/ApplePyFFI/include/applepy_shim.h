#ifndef APPLEPY_SHIM_H
#define APPLEPY_SHIM_H

// CPython main header — pulls in everything we need
#include <Python.h>
#include <structmember.h>

// ─── Shim functions for CPython macros that Swift can't import ───────────────
// Swift's C interop cannot call C preprocessor macros directly.
// These inline functions expose the same functionality as regular C functions.

/// Increment the reference count of a Python object.
static inline void ApplePy_INCREF(PyObject *o) {
    Py_INCREF(o);
}

/// Decrement the reference count of a Python object.
static inline void ApplePy_DECREF(PyObject *o) {
    Py_DECREF(o);
}

/// Increment refcount and return the object (useful for Py_RETURN_NONE pattern).
static inline PyObject* ApplePy_NewRef(PyObject *o) {
    return Py_NewRef(o);
}

/// Return Py_None with an incremented reference count.
static inline PyObject* ApplePy_None(void) {
    return Py_NewRef(Py_None);
}

/// Check if a PyObject is None.
static inline int ApplePy_IsNone(PyObject *o) {
    return o == Py_None;
}

/// Return Py_True with an incremented reference count.
static inline PyObject* ApplePy_True(void) {
    return Py_NewRef(Py_True);
}

/// Return Py_False with an incremented reference count.
static inline PyObject* ApplePy_False(void) {
    return Py_NewRef(Py_False);
}

/// Get the reference count of a Python object.
static inline Py_ssize_t ApplePy_REFCNT(PyObject *o) {
    return Py_REFCNT(o);
}

/// Get the type of a Python object.
static inline PyTypeObject* ApplePy_TYPE(PyObject *o) {
    return Py_TYPE(o);
}

/// Initialize a PyModuleDef with the HEAD_INIT macro (which Swift can't use).
static inline PyModuleDef ApplePy_MakeModuleDef(
    const char *name,
    const char *doc,
    Py_ssize_t size,
    PyMethodDef *methods
) {
    PyModuleDef def = {
        PyModuleDef_HEAD_INIT,
        name,
        doc,
        size,
        methods,
        NULL, // m_slots
        NULL, // m_traverse
        NULL, // m_clear
        NULL  // m_free
    };
    return def;
}

/// Wrapper for PyModule_Create (which is a macro that expands to PyModule_Create2).
static inline PyObject* ApplePy_ModuleCreate(PyModuleDef *def) {
    return PyModule_Create2(def, PYTHON_API_VERSION);
}

// ─── Type check shims (these are macros Swift can't import) ─────────────────

/// Check if a PyObject is a list (or list subclass).
static inline int ApplePy_ListCheck(PyObject *o) {
    return PyList_Check(o);
}

/// Check if a PyObject is a dict (or dict subclass).
static inline int ApplePy_DictCheck(PyObject *o) {
    return PyDict_Check(o);
}

/// Check if a PyObject is a tuple (or tuple subclass).
static inline int ApplePy_TupleCheck(PyObject *o) {
    return PyTuple_Check(o);
}

/// Check if a PyObject is a set.
static inline int ApplePy_SetCheck(PyObject *o) {
    return PyAnySet_Check(o);
}

/// Check if a PyObject is bytes.
static inline int ApplePy_BytesCheck(PyObject *o) {
    return PyBytes_Check(o);
}

/// Check if a PyObject is a Unicode string.
static inline int ApplePy_UnicodeCheck(PyObject *o) {
    return PyUnicode_Check(o);
}

/// Check if a PyObject is a long/int.
static inline int ApplePy_LongCheck(PyObject *o) {
    return PyLong_Check(o);
}

/// Check if a PyObject is a float.
static inline int ApplePy_FloatCheck(PyObject *o) {
    return PyFloat_Check(o);
}

#endif // APPLEPY_SHIM_H
