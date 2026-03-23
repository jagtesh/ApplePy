import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import ApplePyMacros

let unionTestMacros: [String: Macro.Type] = [
    "PyUnion": PyUnionMacro.self,
]

@Suite("@PyUnion Macro Tests")
struct PyUnionMacroTests {

    @Test("Simple two-variant union")
    func simpleUnion() {
        assertMacroExpansion(
            """
            @PyUnion
            enum StringOrInt {
                case string(String)
                case int(Int)
            }
            """,
            expandedSource: """
            enum StringOrInt {
                case string(String)
                case int(Int)

                public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> StringOrInt {
                    if let _v = try? String.fromPython(obj, py: py) { return .string(_v) }
                    if let _v = try? Int.fromPython(obj, py: py) { return .int(_v) }
                    let _typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
                    throw PythonConversionError.unionMismatch(got: _typeName, expected: ["str", "int"])
                }

                public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
                    switch self {
                    case .string(let _v): return _v.intoPython(py: py)
                    case .int(let _v): return _v.intoPython(py: py)
                    }
                }
            }
            """,
            macros: unionTestMacros
        )
    }

    @Test("Union with None case")
    func unionWithNone() {
        assertMacroExpansion(
            """
            @PyUnion
            enum MaybeString {
                case string(String)
                case none
            }
            """,
            expandedSource: """
            enum MaybeString {
                case string(String)
                case none

                public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> MaybeString {
                    if ApplePy_IsNone(obj) != 0 { return .none }
                    if let _v = try? String.fromPython(obj, py: py) { return .string(_v) }
                    let _typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
                    throw PythonConversionError.unionMismatch(got: _typeName, expected: ["str", "None"])
                }

                public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
                    switch self {
                    case .string(let _v): return _v.intoPython(py: py)
                    case .none: return ApplePy_None()
                    }
                }
            }
            """,
            macros: unionTestMacros
        )
    }

    @Test("Applied to non-enum produces error")
    func nonEnum() {
        assertMacroExpansion(
            """
            @PyUnion
            struct Foo {}
            """,
            expandedSource: """
            struct Foo {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyUnion can only be applied to enums", line: 1, column: 1)
            ],
            macros: unionTestMacros
        )
    }
}
