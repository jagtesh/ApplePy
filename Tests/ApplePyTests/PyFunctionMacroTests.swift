import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
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
            func _applepy_greet(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                    let _py = PythonHandle()
                do {
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
                } catch {
                    setPythonConversionException(error)
                    return nil
                }
            }

            let _applepy_flags_greet: Int32 = METH_VARARGS
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
            func _applepy_hello(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                    let _py = PythonHandle()

                    let _result = hello()
                return _result.intoPython(py: _py)
            }

            let _applepy_flags_hello: Int32 = METH_NOARGS
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
            func _applepy_doNothing(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                    let _py = PythonHandle()

                    doNothing()
                return ApplePy_None()
            }

            let _applepy_flags_doNothing: Int32 = METH_NOARGS
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
