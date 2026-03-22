// ApplePy – Macro Plugin Entry Point
// Thin wrapper: registers macros from ApplePyMacroCore with the compiler.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros
@_exported import ApplePyMacroCore

@main
struct ApplePyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PyFunctionMacro.self,
        PyClassMacro.self,
        PyMethodMacro.self,
        PyModuleMacro.self,
        PyEnumMacro.self,
    ]
}
