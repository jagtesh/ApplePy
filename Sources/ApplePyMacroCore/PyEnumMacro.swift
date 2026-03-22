// ApplePy – @PyEnum Macro Implementation
// Generates a Python enum.IntEnum from a Swift enum with Int raw values.
//
// Usage:
//   @PyEnum
//   enum Color: Int {
//       case red = 0
//       case green = 1
//       case blue = 2
//   }
//
// Generates a registerEnum(in:) static method that creates a Python IntEnum
// at runtime using the `enum` module.

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyEnumMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError("@PyEnum can only be applied to enums")
        }

        let enumName = enumDecl.name.text

        // Check for Int raw type
        let hasIntRaw = enumDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Int"
        } ?? false

        // Extract cases with raw values
        var cases: [(name: String, rawValue: String)] = []
        var autoValue = 0
        for member in enumDecl.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in caseDecl.elements {
                    let caseName = element.name.text
                    if let rawValue = element.rawValue?.value.trimmedDescription {
                        cases.append((name: caseName, rawValue: rawValue))
                        if let intVal = Int(rawValue) {
                            autoValue = intVal + 1
                        }
                    } else if hasIntRaw {
                        cases.append((name: caseName, rawValue: "\(autoValue)"))
                        autoValue += 1
                    } else {
                        cases.append((name: caseName, rawValue: "\(autoValue)"))
                        autoValue += 1
                    }
                }
            }
        }

        // Build case pairs for Python enum creation
        var casePairs: [String] = []
        for c in cases {
            casePairs.append("(\"\(c.name)\", \(c.rawValue))")
        }

        var decls: [DeclSyntax] = []

        // Generate FromPyObject conformance helper
        decls.append("""
            static func _fromPythonInt(_ val: Int) -> \(raw: enumName)? {
                return \(raw: enumName)(rawValue: val)
            }
            """)

        // Generate intoPython helper
        decls.append("""
            func _toPythonInt() -> Int {
                return self.rawValue
            }
            """)

        // Generate registerEnum method
        // This creates a Python IntEnum at runtime via the `enum` module
        decls.append("""
            public static func registerEnum(in module: UnsafeMutablePointer<PyObject>) -> Bool {
                // import enum; EnumType = enum.IntEnum("Name", [(case, val), ...])
                guard let enumMod = PyImport_ImportModule("enum") else { return false }
                defer { ApplePy_DECREF(enumMod) }
                
                guard let intEnumClass = PyObject_GetAttrString(enumMod, "IntEnum") else { return false }
                defer { ApplePy_DECREF(intEnumClass) }
                
                // Build the members list: [("red", 0), ("green", 1), ...]
                let memberList = PyList_New(\(raw: cases.count))!
                \(raw: cases.enumerated().map { i, c in
                    """
                    do {
                        let pair = PyTuple_New(2)!
                        PyTuple_SetItem(pair, 0, PyUnicode_FromString("\(c.name)"))
                        PyTuple_SetItem(pair, 1, PyLong_FromLongLong(Int64(\(c.rawValue))))
                        PyList_SetItem(memberList, \(i), pair)
                    }
                    """
                }.joined(separator: "\n        "))
                
                // Call IntEnum("Name", members)
                let args = PyTuple_New(2)!
                PyTuple_SetItem(args, 0, PyUnicode_FromString("\(raw: enumName)"))
                PyTuple_SetItem(args, 1, memberList)
                
                guard let enumType = PyObject_CallObject(intEnumClass, args) else {
                    ApplePy_DECREF(args)
                    return false
                }
                ApplePy_DECREF(args)
                
                // Add to module
                let name: UnsafePointer<CChar> = "\(raw: enumName)".withCString { UnsafePointer(strdup($0)!) }
                if PyModule_AddObject(module, name, enumType) < 0 {
                    ApplePy_DECREF(enumType)
                    return false
                }
                return true
            }
            """)

        return decls
    }
}
