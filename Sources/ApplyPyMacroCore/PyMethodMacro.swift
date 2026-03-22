// ApplyPy – @PyMethod Macro Implementation
// Generates a @_cdecl wrapper for a method inside a @PyClass.
// The wrapper extracts `self` from the PyObject, unpacks args, calls the method,
// and converts the return value.

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(FunctionDeclSyntax.self) else {
            throw MacroError("@PyMethod can only be applied to functions")
        }

        // Find the enclosing type name by looking at the context
        // Since we can't get the enclosing type directly in a PeerMacro,
        // we rely on @PyClass to generate the actual wrappers.
        // @PyMethod on its own just serves as a marker that @PyClass reads.
        // It doesn't generate any code independently.
        return []
    }
}
