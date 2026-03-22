// ApplePy – #pymodule Macro Implementation
// Generates PyInit_<name> entry point that creates the module and registers types/functions.

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyModuleMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Parse arguments: #pymodule("name", types: [...], functions: [...])
        let argList = node.arguments

        // First positional argument: module name
        guard let firstArg = argList.first,
              let strLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) else {
            throw MacroError("#pymodule requires a string literal module name")
        }
        let moduleName = strLiteral.segments.trimmedDescription

        // Collect type names from `types:` arg
        var typeNames: [String] = []
        var functionNames: [String] = []

        for arg in argList {
            if arg.label?.text == "types",
               let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
                for element in arrayExpr.elements {
                    // Expect Type.self expressions
                    if let memberAccess = element.expression.as(MemberAccessExprSyntax.self),
                       memberAccess.declName.baseName.text == "self",
                       let base = memberAccess.base {
                        typeNames.append(base.trimmedDescription)
                    } else {
                        typeNames.append(element.expression.trimmedDescription)
                    }
                }
            }

            if arg.label?.text == "functions",
               let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
                for element in arrayExpr.elements {
                    functionNames.append(element.expression.trimmedDescription)
                }
            }
        }

        // Build method table entries from @PyFunction-annotated functions
        var methodEntries: [String] = []
        for funcName in functionNames {
            methodEntries.append("_applepy_methoddef_\(funcName)")
        }

        // Build the method table
        var methodTableLines: [String] = []
        for entry in methodEntries {
            methodTableLines.append("\(entry),")
        }
        methodTableLines.append("PyMethodDef(ml_name: nil, ml_meth: nil, ml_flags: 0, ml_doc: nil),")

        // Build type registration calls
        var typeRegCalls: [String] = []
        for typeName in typeNames {
            typeRegCalls.append("""
                guard \(typeName).registerType(in: module) else {
                    ApplePy_DECREF(module)
                    return nil
                }
            """)
        }

        let initFuncName = "PyInit_\(moduleName)"

        var decls: [DeclSyntax] = []

        // Generate the method table
        decls.append("""
            private var _applepy_module_methods: [PyMethodDef] = [
                \(raw: methodTableLines.joined(separator: "\n    "))
            ]
            """)

        // Generate module def (global to survive the function scope)
        decls.append("""
            private var _applepy_module_def: PyModuleDef = {
                let name: UnsafePointer<CChar> = "\(raw: moduleName)".withCString { UnsafePointer(strdup($0)!) }
                return ApplePy_MakeModuleDef(name, nil, -1, &_applepy_module_methods)
            }()
            """)

        // Generate PyInit function
        decls.append("""
            @_cdecl("\(raw: initFuncName)")
            public func \(raw: initFuncName)() -> UnsafeMutablePointer<PyObject>? {
                guard let module = ApplePy_ModuleCreate(&_applepy_module_def) else { return nil }
                \(raw: typeRegCalls.joined(separator: "\n    "))
                return module
            }
            """)

        return decls
    }
}
