// ApplePy – @PyModule Macro Implementation
// Generates PyInit_<name> entry point that creates the module and registers types/functions.
//
// Follows PyO3's pattern: @PyModule is attached to a function, not freestanding.
// The host function provides the declaration name for `names: prefixed(_applepy_)`.
//
// Usage:
//   @PyModule("mylib", functions: [greet, add])
//   func mylib() {}

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyModuleMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError("@PyModule can only be applied to functions")
        }

        guard let argList = node.arguments?.as(LabeledExprListSyntax.self) else {
            throw MacroError("@PyModule requires arguments")
        }

        guard let firstArg = argList.first,
              let strLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) else {
            throw MacroError("@PyModule requires a string literal module name")
        }
        let moduleName = strLiteral.segments.trimmedDescription
        let hostName = funcDecl.name.text

        var typeNames: [String] = []
        var functionNames: [String] = []

        for arg in argList {
            if arg.label?.text == "types",
               let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
                for element in arrayExpr.elements {
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

        // Build PyMethodDef entries
        var methodTableLines: [String] = []
        for funcName in functionNames {
            let wrapperName = "_applepy_\(funcName)"
            methodTableLines.append("""
                {
                    let n: UnsafePointer<CChar> = "\(funcName)".withCString { UnsafePointer(strdup($0)!) }
                    return PyMethodDef(ml_name: n, ml_meth: \(wrapperName), ml_flags: METH_VARARGS, ml_doc: nil)
                }(),
            """)
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

        // All generated names use the _applepy_ prefix + host function name
        // This satisfies `names: prefixed(_applepy_)` constraint
        let initFuncName = "PyInit_\(moduleName)"

        // Single generated function that contains everything inline
        // The @_cdecl provides the C symbol name, Swift name uses _applepy_ prefix
        let initDecl: DeclSyntax = """
            @_cdecl("\(raw: initFuncName)")
            func _applepy_\(raw: hostName)() -> UnsafeMutablePointer<PyObject>? {
                var methods: [PyMethodDef] = [
                    \(raw: methodTableLines.joined(separator: "\n        "))
                ]
                let name: UnsafePointer<CChar> = "\(raw: moduleName)".withCString { UnsafePointer(strdup($0)!) }
                var moduleDef = ApplePy_MakeModuleDef(name, nil, -1, &methods)
                guard let module = ApplePy_ModuleCreate(&moduleDef) else { return nil }
                \(raw: typeRegCalls.joined(separator: "\n    "))
                return module
            }
            """

        return [initDecl]
    }
}
