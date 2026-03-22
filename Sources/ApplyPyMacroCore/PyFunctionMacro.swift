// ApplyPy – @PyFunction Macro Implementation
// Generates a @_cdecl wrapper + PyMethodDef for a top-level Swift function.

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyFunctionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The declaration must be a function
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError("@PyFunction can only be applied to functions")
        }

        let funcName = funcDecl.name.text
        let wrapperName = "_applypy_\(funcName)"
        let params = funcDecl.signature.parameterClause.parameters
        let returnsVoid = funcDecl.signature.returnClause == nil
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsClause != nil

        // Build argument unpacking lines
        var unpackLines: [String] = []
        var callArgs: [String] = []
        let paramCount = params.count

        if paramCount > 0 {
            unpackLines.append("""
                guard let args = args else {
                    PyErr_SetString(PyExc_TypeError, "\\(funcName)() requires arguments")
                    return nil
                }
                let _nArgs = PyTuple_Size(args)
                guard _nArgs == \(paramCount) else {
                    PyErr_SetString(PyExc_TypeError, "\\(funcName)() takes exactly \(paramCount) argument(s)")
                    return nil
                }
            """)

            for (i, param) in params.enumerated() {
                let paramName = param.secondName?.text ?? param.firstName.text
                let typeName = param.type.trimmedDescription

                unpackLines.append("""
                    guard let _pyArg\(i) = PyTuple_GetItem(args, \(i)) else { return nil }
                    let \(paramName): \(typeName) = try \(typeName).fromPython(_pyArg\(i), py: _py)
                """)

                if param.firstName.text == "_" {
                    callArgs.append(paramName)
                } else {
                    callArgs.append("\(param.firstName.text): \(paramName)")
                }
            }
        }

        // Build the call expression
        let callExpr = "\(funcName)(\(callArgs.joined(separator: ", ")))"

        // Build return conversion
        let returnConversion: String
        if returnsVoid {
            returnConversion = """
                \(isThrowing ? "try " : "")\(callExpr)
                return ApplyPy_None()
            """
        } else {
            returnConversion = """
                let _result = \(isThrowing ? "try " : "")\(callExpr)
                return _result.intoPython(py: _py)
            """
        }

        // Build the full wrapper function body
        let unpackBlock = unpackLines.joined(separator: "\n")

        let wrapperBody: String
        if isThrowing {
            wrapperBody = """
                let _py = PythonHandle()
                do {
                    \(unpackBlock)
                    \(returnConversion)
                } catch {
                    PyErr_SetString(PyExc_RuntimeError, "\\(error)")
                    return nil
                }
            """
        } else {
            wrapperBody = """
                let _py = PythonHandle()
                \(unpackBlock)
                \(returnConversion)
            """
        }

        // Generate the @_cdecl wrapper
        let wrapperDecl: DeclSyntax = """
            @_cdecl("\(raw: wrapperName)")
            public func \(raw: wrapperName)(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                \(raw: wrapperBody)
            }
            """

        // Generate the PyMethodDef constant name
        let methodDefName = "_applypy_methoddef_\(funcName)"

        // Generate the PyMethodDef
        // We use strdup for stable C strings
        let flags = paramCount == 0 ? "METH_NOARGS" : "METH_VARARGS"
        let methodDefDecl: DeclSyntax = """
            public let \(raw: methodDefName): PyMethodDef = {
                let name: UnsafePointer<CChar> = "\(raw: funcName)".withCString { UnsafePointer(strdup($0)!) }
                return PyMethodDef(ml_name: name, ml_meth: \(raw: wrapperName), ml_flags: \(raw: flags), ml_doc: nil)
            }()
            """

        return [wrapperDecl, methodDefDecl]
    }
}

// MARK: - Error type

struct MacroError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}
