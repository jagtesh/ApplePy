// ApplePy – @PyStaticMethod Macro Implementation
// Marks a static function inside a @PyClass for Python exposure.
// The actual code generation happens in `@PyClass`, which reads @PyStaticMethod attributes.
//
// Usage:
//   @PyClass
//   struct Counter {
//       @PyStaticMethod
//       static func zero() -> Counter { Counter(count: 0) }
//   }

import SwiftSyntax
import SwiftSyntaxMacros

/// @PyStaticMethod is a marker macro — code generation is done by @PyClass.
public struct PyStaticMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError("@PyStaticMethod can only be applied to functions")
        }
        // Verify it's a static function
        let isStatic = funcDecl.modifiers.contains { $0.name.text == "static" }
        if !isStatic {
            throw MacroError("@PyStaticMethod requires the function to be declared as 'static'")
        }
        // Marker only — @PyClass reads this attribute
        return []
    }
}
