// ApplePy – Macro Plugin Entry Point
// Thin wrapper: registers macros from ApplePyMacroCore with the compiler.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct ApplePyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PyFunctionMacro.self,
        PyClassMacro.self,
        PyMethodMacro.self,
        PyModuleMacro.self,
        PyEnumMacro.self,
        PyPropertyMacro.self,
        PyStaticMethodMacro.self,
        PyUnionMacro.self,
    ]
}
