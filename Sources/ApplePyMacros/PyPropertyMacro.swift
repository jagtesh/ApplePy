// ApplePy – @PyProperty Macro Implementation
// Marks a stored property for Python getter/setter exposure.
// The actual code generation happens in `@PyClass`, which reads @PyProperty attributes.
//
// Usage:
//   @PyClass
//   struct Point {
//       @PyProperty var x: Double
//       @PyProperty var y: Double
//   }
//
// Generates:
//   - getter function: _Point_get_x(self, closure) -> PyObject*
//   - setter function: _Point_set_x(self, value, closure) -> Int32
//   - PyGetSetDef entry for the type

import SwiftSyntax
import SwiftSyntaxMacros

/// @PyProperty is a marker macro — code generation is done by @PyClass.
public struct PyPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate: must be applied to a var declaration
        guard declaration.is(VariableDeclSyntax.self) else {
            throw MacroError("@PyProperty can only be applied to stored properties")
        }
        // Marker only — @PyClass reads this attribute to generate getters/setters
        return []
    }
}
