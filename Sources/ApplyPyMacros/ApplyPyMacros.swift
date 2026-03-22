// ApplyPy – Macro Plugin Entry Point
// Thin wrapper: registers macros from ApplyPyMacroCore with the compiler.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros
@_exported import ApplyPyMacroCore

@main
struct ApplyPyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PyFunctionMacro.self,
        PyClassMacro.self,
        PyMethodMacro.self,
    ]
}
