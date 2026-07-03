import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
@testable import ApplePyMacros

nonisolated(unsafe) let classTestMacros: [String: Macro.Type] = [
    "PyClass": PyClassMacro.self,
    "PyMethod": PyMethodMacro.self,
    "PyProperty": PyPropertyMacro.self,
    "PyStaticMethod": PyStaticMethodMacro.self,
]

@Suite("@PyClass Macro Tests")
struct PyClassMacroTests {

    @Test("Applied to non-struct/class produces error")
    func nonStructOrClass() {
        assertMacroExpansion(
            """
            @PyClass
            enum Foo { case bar }
            """,
            expandedSource: """
            enum Foo { case bar 
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyClass can only be applied to structs or classes", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }

    @Test("Generic struct produces error")
    func genericStruct() {
        assertMacroExpansion(
            """
            @PyClass
            struct Box<T> {
                var value: T
            }
            """,
            expandedSource: """
            struct Box<T> {
                var value: T
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyClass does not support generic types", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }

    @Test("Generic class produces error")
    func genericClass() {
        assertMacroExpansion(
            """
            @PyClass
            class Box<T> {
                var value: T
                init(value: T) { self.value = value }
            }
            """,
            expandedSource: """
            class Box<T> {
                var value: T
                init(value: T) { self.value = value }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyClass does not support generic types", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }
}

@Suite("@PyProperty Macro Tests")
struct PyPropertyMacroTests {

    @Test("Applied to non-variable produces error")
    func nonVariable() {
        assertMacroExpansion(
            """
            @PyProperty
            func foo() {}
            """,
            expandedSource: """
            func foo() {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyProperty can only be applied to stored properties", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }

    @Test("Applied to computed property produces error")
    func computedProperty() {
        assertMacroExpansion(
            """
            @PyProperty
            var x: Int {
                get { 42 }
                set { }
            }
            """,
            expandedSource: """
            var x: Int {
                get { 42 }
                set { }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyProperty can only be applied to stored properties, not computed properties", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }

    @Test("Applied to get-only computed property produces error")
    func getOnlyComputedProperty() {
        assertMacroExpansion(
            """
            @PyProperty
            var x: Int {
                42
            }
            """,
            expandedSource: """
            var x: Int {
                42
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyProperty can only be applied to stored properties, not computed properties", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }
}

@Suite("@PyStaticMethod Macro Tests")
struct PyStaticMethodMacroTests {

    @Test("Non-static function produces error")
    func nonStaticFunction() {
        assertMacroExpansion(
            """
            @PyStaticMethod
            func zero() -> Int { 0 }
            """,
            expandedSource: """
            func zero() -> Int { 0 }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PyStaticMethod requires the function to be declared as 'static'", line: 1, column: 1)
            ],
            macros: classTestMacros
        )
    }
}
