// ApplyPy – Macro Implementations
// This target contains the SwiftSyntax-based macro implementations.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Placeholder macros (to be implemented in Phase 2)

/// Macro that marks a Swift struct/class for export as a Python type.
public struct PyClassMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Phase 2.3: will generate tp_new, tp_dealloc, PyType_Spec, etc.
        return []
    }
}

/// Macro that marks a function for export as a Python callable.
public struct PyFunctionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Phase 2.2: will generate @_cdecl wrapper + PyMethodDef
        return []
    }
}

/// Macro that marks a method within a @PyClass for export.
public struct PyMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Phase 2.4: will generate @_cdecl wrapper + PyMethodDef entry
        return []
    }
}

@main
struct ApplyPyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PyClassMacro.self,
        PyFunctionMacro.self,
        PyMethodMacro.self,
    ]
}
