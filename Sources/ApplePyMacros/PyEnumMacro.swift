// ApplePy – @PyEnum Macro Implementation
// Generates Python types from Swift enums.
//
// Simple enums (Int raw values) → Python enum.IntEnum
// Variant enums (associated values) → Python class hierarchy
//
// Usage (simple):
//   @PyEnum
//   enum Color: Int {
//       case red = 0
//       case green = 1
//       case blue = 2
//   }
//
// Usage (variant):
//   @PyEnum
//   enum Shape {
//       case circle(radius: Double)
//       case rect(width: Double, height: Double)
//   }
//
// Generates registerEnum(in:) that creates the appropriate Python types.

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

        // Detect whether this is a simple (Int raw) or variant (associated values) enum
        let hasAssociatedValues = enumDecl.memberBlock.members.contains { member in
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                return caseDecl.elements.contains { $0.parameterClause != nil }
            }
            return false
        }

        if hasAssociatedValues {
            return try generateVariantEnum(enumName: enumName, enumDecl: enumDecl)
        } else {
            return try generateIntEnum(enumName: enumName, enumDecl: enumDecl)
        }
    }

    // MARK: - Simple IntEnum

    private static func generateIntEnum(enumName: String, enumDecl: EnumDeclSyntax) throws -> [DeclSyntax] {
        let hasIntRaw = enumDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Int"
        } ?? false

        var cases: [(name: String, rawValue: String)] = []
        var autoValue = 0
        for member in enumDecl.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in caseDecl.elements {
                    let caseName = element.name.text
                    if let rawValue = element.rawValue?.value.trimmedDescription {
                        cases.append((name: caseName, rawValue: rawValue))
                        if let intVal = Int(rawValue) { autoValue = intVal + 1 }
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

        var decls: [DeclSyntax] = []

        decls.append("""
            static func _fromPythonInt(_ val: Int) -> \(raw: enumName)? {
                return \(raw: enumName)(rawValue: val)
            }
            """)

        decls.append("""
            func _toPythonInt() -> Int {
                return self.rawValue
            }
            """)

        decls.append("""
            public static func registerEnum(in module: UnsafeMutablePointer<PyObject>) -> Bool {
                guard let enumMod = PyImport_ImportModule("enum") else { return false }
                defer { ApplePy_DECREF(enumMod) }
                
                guard let intEnumClass = PyObject_GetAttrString(enumMod, "IntEnum") else { return false }
                defer { ApplePy_DECREF(intEnumClass) }
                
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
                
                let args = PyTuple_New(2)!
                PyTuple_SetItem(args, 0, PyUnicode_FromString("\(raw: enumName)"))
                PyTuple_SetItem(args, 1, memberList)
                
                guard let enumType = PyObject_CallObject(intEnumClass, args) else {
                    ApplePy_DECREF(args)
                    return false
                }
                ApplePy_DECREF(args)
                
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

    // MARK: - Variant Enum (Associated Values → Class Hierarchy)

    private static func generateVariantEnum(enumName: String, enumDecl: EnumDeclSyntax) throws -> [DeclSyntax] {
        // Extract all cases with their associated values
        struct VariantCase {
            let name: String
            let capitalizedName: String
            let params: [(label: String, type: String)]
        }

        var variants: [VariantCase] = []
        for member in enumDecl.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in caseDecl.elements {
                    let caseName = element.name.text
                    let capitalized = caseName.prefix(1).uppercased() + caseName.dropFirst()
                    var params: [(label: String, type: String)] = []
                    if let paramClause = element.parameterClause {
                        for (idx, param) in paramClause.parameters.enumerated() {
                            let label = param.firstName?.text ?? "_\(idx)"
                            let type = param.type.trimmedDescription
                            params.append((label: label, type: type))
                        }
                    }
                    variants.append(VariantCase(name: caseName, capitalizedName: capitalized, params: params))
                }
            }
        }

        // Map Swift type names to Python type format codes
        func pyTypeString(_ swiftType: String) -> String {
            switch swiftType {
            case "Int": return "int"
            case "Double", "Float": return "float"
            case "String": return "str"
            case "Bool": return "bool"
            default: return "object"
            }
        }

        var decls: [DeclSyntax] = []

        // Generate registerEnum that creates:
        //   class Shape:  # base (tag only)
        //       pass
        //   class Circle(Shape):
        //       def __init__(self, radius): self.radius = radius
        //   class Rectangle(Shape):
        //       def __init__(self, width, height): ...
        decls.append("""
            public static func registerEnum(in module: UnsafeMutablePointer<PyObject>) -> Bool {
                // Create base class via: type("EnumName", (object,), {"__slots__": ()})
                guard let builtins = PyImport_ImportModule("builtins") else { return false }
                defer { ApplePy_DECREF(builtins) }
                guard let typeFunc = PyObject_GetAttrString(builtins, "type") else { return false }
                defer { ApplePy_DECREF(typeFunc) }
                
                // Base class dict with __slots__ = ()
                guard let baseDict = PyDict_New() else { return false }
                guard let emptyTuple = PyTuple_New(0) else {
                    ApplePy_DECREF(baseDict)
                    return false
                }
                PyDict_SetItemString(baseDict, "__slots__", emptyTuple)
                ApplePy_DECREF(emptyTuple)
                
                // type("EnumName", (object,), {"__slots__": ()})
                let baseBases = PyTuple_New(1)!
                guard let objectType = PyObject_GetAttrString(builtins, "object") else {
                    ApplePy_DECREF(baseDict)
                    return false
                }
                PyTuple_SetItem(baseBases, 0, objectType)
                
                let baseArgs = PyTuple_New(3)!
                PyTuple_SetItem(baseArgs, 0, PyUnicode_FromString("\(raw: enumName)"))
                PyTuple_SetItem(baseArgs, 1, baseBases)
                PyTuple_SetItem(baseArgs, 2, baseDict)
                
                guard let baseClass = PyObject_CallObject(typeFunc, baseArgs) else {
                    ApplePy_DECREF(baseArgs)
                    return false
                }
                ApplePy_DECREF(baseArgs)
                
                // Add base class to module
                if PyModule_AddObject(module, "\(raw: enumName)", baseClass) < 0 {
                    ApplePy_DECREF(baseClass)
                    return false
                }
                
                // Create each variant subclass
                \(raw: variants.map { v in
                    let slotNames = v.params.map { "\"\($0.label)\"" }.joined(separator: ", ")
                    let initParams = v.params.map { "\($0.label)" }.joined(separator: ", ")
                    let initBody = v.params.map { "self.\($0.label) = \($0.label)" }.joined(separator: "; ")
                    let initCode: String
                    if v.params.isEmpty {
                        initCode = "pass"
                    } else {
                        initCode = """
                        def __init__(self, \(initParams)):
                                    \(v.params.map { "self.\($0.label) = \($0.label)" }.joined(separator: "\n                    "))
                        """
                    }
                    return """
                    do {
                        // Variant: \(v.capitalizedName)
                        let variantDict = PyDict_New()!
                        let slots = PyTuple_New(\(v.params.count))!
                        \(v.params.enumerated().map { i, p in
                            "PyTuple_SetItem(slots, \(i), PyUnicode_FromString(\"\(p.label)\"))"
                        }.joined(separator: "\n            "))
                        PyDict_SetItemString(variantDict, "__slots__", slots)
                        ApplePy_DECREF(slots)
                        
                        // Create __init__ via compile/exec
                        \(v.params.isEmpty ? "" : """
                        let initSrc = PyUnicode_FromString("def __init__(self, \(initParams)):\\n\(v.params.map { "    self.\($0.label) = \($0.label)" }.joined(separator: "\\n"))")!
                        let initCode = Py_CompileString(
                            "def __init__(self, \(initParams)):\\n\(v.params.map { "    self.\($0.label) = \($0.label)" }.joined(separator: "\\n"))",
                            "<\(v.name)>",
                            Int32(258) // Py_file_input
                        )
                        if let initCode = initCode {
                            let initNs = PyDict_New()!
                            if let _ = PyEval_EvalCode(initCode, initNs, initNs) {
                                if let initFn = PyDict_GetItemString(initNs, "__init__") {
                                    ApplePy_INCREF(initFn)
                                    PyDict_SetItemString(variantDict, "__init__", initFn)
                                    ApplePy_DECREF(initFn)
                                }
                            }
                            ApplePy_DECREF(initNs)
                            ApplePy_DECREF(initCode)
                        }
                        ApplePy_DECREF(initSrc)
                        """)
                        
                        // type("VariantName", (BaseClass,), dict)
                        let variantBases = PyTuple_New(1)!
                        ApplePy_INCREF(baseClass)
                        PyTuple_SetItem(variantBases, 0, baseClass)
                        
                        let variantArgs = PyTuple_New(3)!
                        PyTuple_SetItem(variantArgs, 0, PyUnicode_FromString("\(v.capitalizedName)"))
                        PyTuple_SetItem(variantArgs, 1, variantBases)
                        PyTuple_SetItem(variantArgs, 2, variantDict)
                        
                        if let variantClass = PyObject_CallObject(typeFunc, variantArgs) {
                            PyModule_AddObject(module, "\(v.capitalizedName)", variantClass)
                            // Also add as attribute on base: Shape.Circle = Circle
                            PyObject_SetAttrString(baseClass, "\(v.capitalizedName)", variantClass)
                        }
                        ApplePy_DECREF(variantArgs)
                    }
                    """
                }.joined(separator: "\n        "))
                
                return true
            }
            """)

        // Generate tag-checking helper
        decls.append("""
            var _variantTag: String {
                switch self {
                \(raw: variants.map { v in
                    if v.params.isEmpty {
                        return "case .\(v.name): return \"\(v.capitalizedName)\""
                    } else {
                        let underscores = v.params.map { _ in "_" }.joined(separator: ", ")
                        return "case .\(v.name)(\(underscores)): return \"\(v.capitalizedName)\""
                    }
                }.joined(separator: "\n        "))
                }
            }
            """)

        return decls
    }
}
