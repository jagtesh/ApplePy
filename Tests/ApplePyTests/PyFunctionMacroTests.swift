import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import ApplePyMacros

nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "PyFunction": PyFunctionMacro.self,
    "PyClass": PyClassMacro.self,
    "PyMethod": PyMethodMacro.self,
]

@Suite("@PyFunction Macro Tests")
struct PyFunctionMacroTests {

    @Test("Simple function with one parameter")
    func simpleOneParam() {
        assertMacroExpansion(
            """
            @PyFunction
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }
            """,
            expandedSource: """
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }

            @_cdecl("_applepy_greet")
            public func _applepy_greet(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                let _py = PythonHandle()
                guard let args = args else {
                    PyErr_SetString(PyExc_TypeError, "greet() requires arguments")
                    return nil
                }
                let _nArgs = PyTuple_Size(args)
                guard _nArgs == 1 else {
                    PyErr_SetString(PyExc_TypeError, "greet() takes exactly 1 argument(s)")
                    return nil
                }
                guard let _pyArg0 = PyTuple_GetItem(args, 0) else {
                    return nil
                }
                let name: String = try String.fromPython(_pyArg0, py: _py)
                let _result = greet(name: name)
                return _result.intoPython(py: _py)
            }

            public let _applepy_methoddef_greet: PyMethodDef = {
                let name: UnsafePointer<CChar> = "greet".withCString {
                    UnsafePointer(strdup($0)!)
                }
                return PyMethodDef(ml_name: name, ml_meth: _applepy_greet, ml_flags: METH_VARARGS, ml_doc: nil)
            }()
            """,
            macros: testMacros
        )
    }

    @Test("Function with no parameters")
    func noParams() {
        assertMacroExpansion(
            """
            @PyFunction
            func hello() -> String {
                return "Hello!"
            }
            """,
            expandedSource: """
            func hello() -> String {
                return "Hello!"
            }

            @_cdecl("_applepy_hello")
            public func _applepy_hello(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                let _py = PythonHandle()
                let _result = hello()
                return _result.intoPython(py: _py)
            }

            public let _applepy_methoddef_hello: PyMethodDef = {
                let name: UnsafePointer<CChar> = "hello".withCString {
                    UnsafePointer(strdup($0)!)
                }
                return PyMethodDef(ml_name: name, ml_meth: _applepy_hello, ml_flags: METH_NOARGS, ml_doc: nil)
            }()
            """,
            macros: testMacros
        )
    }

    @Test("Void function")
    func voidReturn() {
        assertMacroExpansion(
            """
            @PyFunction
            func doNothing() {
            }
            """,
            expandedSource: """
            func doNothing() {
            }

            @_cdecl("_applepy_doNothing")
            public func _applepy_doNothing(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                let _py = PythonHandle()
                doNothing()
                return ApplePy_None()
            }

            public let _applepy_methoddef_doNothing: PyMethodDef = {
                let name: UnsafePointer<CChar> = "doNothing".withCString {
                    UnsafePointer(strdup($0)!)
                }
                return PyMethodDef(ml_name: name, ml_meth: _applepy_doNothing, ml_flags: METH_NOARGS, ml_doc: nil)
            }()
            """,
            macros: testMacros
        )
    }

    @Test("Applied to non-function produces error")
    func nonFunction() {
        assertMacroExpansion(
            """
            @PyFunction
            var x = 5
            """,
            expandedSource: """
            var x = 5
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyFunction can only be applied to functions", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
