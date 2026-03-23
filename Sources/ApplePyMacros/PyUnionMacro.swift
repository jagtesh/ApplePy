// ApplePy – @PyUnion Macro Implementation
// Generates FromPyObject/IntoPyObject conformance for Swift enums,
// enabling Python union type dispatch (e.g., str | int).

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyUnionMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError("@PyUnion can only be applied to enums")
        }

        let enumName = enumDecl.name.text

        // Extract variants: each case must have 0 or 1 associated value
        var variants: [UnionVariant] = []
        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                if let paramClause = element.parameterClause {
                    let params = paramClause.parameters
                    guard params.count == 1 else {
                        throw MacroError("@PyUnion case '\(caseName)' must have exactly 0 or 1 associated value, got \(params.count)")
                    }
                    let typeName = params.first!.type.trimmedDescription
                    variants.append(UnionVariant(caseName: caseName, typeName: typeName, isNone: false))
                } else {
                    // Case with no associated value — treated as None
                    variants.append(UnionVariant(caseName: caseName, typeName: nil, isNone: true))
                }
            }
        }

        guard !variants.isEmpty else {
            throw MacroError("@PyUnion enum must have at least one case")
        }

        // Build Python type annotations for error messages
        let annotations = variants.map { v in
            if v.isNone { return "None" }
            return swiftTypeToPythonName(v.typeName!)
        }

        // Generate fromPython: try each variant in declaration order
        var fromPythonLines: [String] = []

        // Check None variants first (cheap check)
        for v in variants where v.isNone {
            fromPythonLines.append("""
                    if ApplePy_IsNone(obj) != 0 { return .\(v.caseName) }
            """)
        }

        // Then try typed variants
        for v in variants where !v.isNone {
            fromPythonLines.append("""
                    if let _v = try? \(v.typeName!).fromPython(obj, py: py) { return .\(v.caseName)(_v) }
            """)
        }

        // Final error
        fromPythonLines.append("""
                    let _typeName = String(cString: ApplePy_TYPE(obj).pointee.tp_name)
                    throw PythonConversionError.unionMismatch(got: _typeName, expected: [\(annotations.map { "\"\($0)\"" }.joined(separator: ", "))])
        """)

        let fromPythonBody = fromPythonLines.joined(separator: "\n")

        // Generate intoPython: switch on cases
        var intoPythonCases: [String] = []
        for v in variants {
            if v.isNone {
                intoPythonCases.append("            case .\(v.caseName): return ApplePy_None()")
            } else {
                intoPythonCases.append("            case .\(v.caseName)(let _v): return _v.intoPython(py: py)")
            }
        }
        let intoPythonBody = intoPythonCases.joined(separator: "\n")

        // Generate the conformance as static methods within the enum
        let fromPythonDecl: DeclSyntax = """
            public static func fromPython(_ obj: UnsafeMutablePointer<PyObject>, py: PythonHandle) throws -> \(raw: enumName) {
        \(raw: fromPythonBody)
            }
        """

        let intoPythonDecl: DeclSyntax = """
            public func intoPython(py: PythonHandle) -> UnsafeMutablePointer<PyObject>? {
                switch self {
        \(raw: intoPythonBody)
                }
            }
        """

        return [fromPythonDecl, intoPythonDecl]
    }

    /// Map Swift type names to Python type names for error messages
    private static func swiftTypeToPythonName(_ swiftType: String) -> String {
        switch swiftType {
        case "Int": return "int"
        case "Double", "Float": return "float"
        case "String": return "str"
        case "Bool": return "bool"
        default:
            if swiftType.hasPrefix("[") && swiftType.hasSuffix("]") {
                if swiftType.contains(":") {
                    return "dict"
                }
                return "list"
            }
            return swiftType
        }
    }
}

private struct UnionVariant {
    let caseName: String
    let typeName: String?  // nil for None variants
    let isNone: Bool
}
