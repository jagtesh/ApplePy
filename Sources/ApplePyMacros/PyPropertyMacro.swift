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
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw MacroError("@PyProperty can only be applied to stored properties")
        }

        // Reject computed properties (`get`/`set`, or `get`-only). @PyClass's
        // codegen assumes a stored property backed by real storage in the
        // Swift value; applying @PyProperty to a computed property would
        // silently generate a getter/setter pair that reads/writes a
        // property with no backing storage, producing confusing runtime
        // behavior instead of a clear compile-time error.
        for binding in varDecl.bindings {
            if let accessorBlock = binding.accessorBlock {
                switch accessorBlock.accessors {
                case .accessors(let accessors):
                    let hasComputedAccessor = accessors.contains { accessor in
                        accessor.accessorSpecifier.tokenKind == .keyword(.get)
                            || accessor.accessorSpecifier.tokenKind == .keyword(.set)
                    }
                    if hasComputedAccessor {
                        throw MacroError("@PyProperty can only be applied to stored properties, not computed properties")
                    }
                case .getter:
                    throw MacroError("@PyProperty can only be applied to stored properties, not computed properties")
                }
            }
        }

        // Marker only — @PyClass reads this attribute to generate getters/setters
        return []
    }
}
