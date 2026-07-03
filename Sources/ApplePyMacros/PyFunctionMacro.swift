// ApplePy – @PyFunction Macro Implementation
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
        let params = funcDecl.signature.parameterClause.parameters
        let returnsVoid = funcDecl.signature.returnClause == nil
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsClause != nil

        // Build argument unpacking lines
        var unpackLines: [String] = []
        var callArgs: [String] = []
        let paramCount = params.count

        // Track param info: (index, name, label, typeName, defaultValue?, isUnderscoreLabel)
        var paramIndices: [Int] = []
        var paramNames: [String] = []
        var paramLabels: [String] = []
        var paramTypes: [String] = []
        var paramDefaults: [String?] = []
        var paramIsUnderscore: [Bool] = []

        for (i, param) in params.enumerated() {
            paramIndices.append(i)
            paramNames.append(param.secondName?.text ?? param.firstName.text)
            paramLabels.append(param.firstName.text)
            paramTypes.append(param.type.trimmedDescription)
            paramDefaults.append(param.defaultValue?.value.trimmedDescription)
            paramIsUnderscore.append(param.firstName.text == "_")
        }

        let requiredCount = paramDefaults.filter { $0 == nil }.count

        if paramCount > 0 {
            if requiredCount == paramCount {
                // No defaults — strict checking (original behavior)
                unpackLines.append("""
                    guard let args = args else {
                        PyErr_SetString(PyExc_TypeError, "\(funcName)() requires arguments")
                        return nil
                    }
                    let _nArgs = PyTuple_Size(args)
                    guard _nArgs == \(paramCount) else {
                        PyErr_SetString(PyExc_TypeError, "\(funcName)() takes exactly \(paramCount) argument(s)")
                        return nil
                    }
                """)
            } else {
                // Has defaults — flexible arg count
                unpackLines.append("""
                    let _nArgs: Py_ssize_t = args != nil ? PyTuple_Size(args!) : 0
                    guard _nArgs >= \(requiredCount) && _nArgs <= \(paramCount) else {
                        PyErr_SetString(PyExc_TypeError, "\(funcName)() takes \(requiredCount) to \(paramCount) argument(s)")
                        return nil
                    }
                """)
            }

            for idx in 0..<paramCount {
                let pName = paramNames[idx]
                let pType = paramTypes[idx]
                let pIdx = paramIndices[idx]
                if let defaultValue = paramDefaults[idx] {
                    // Optional param: use Python arg if provided, else fallback to Swift default
                    unpackLines.append("""
                        let \(pName): \(pType)
                        if _nArgs > \(pIdx), let _pyArg\(pIdx) = PyTuple_GetItem(args!, \(pIdx)) {
                            \(pName) = try \(pType).fromPython(_pyArg\(pIdx), py: _py)
                        } else {
                            \(pName) = \(defaultValue)
                        }
                    """)
                } else {
                    // Required param
                    unpackLines.append("""
                        guard let _pyArg\(pIdx) = PyTuple_GetItem(args, \(pIdx)) else { return nil }
                        let \(pName): \(pType) = try \(pType).fromPython(_pyArg\(pIdx), py: _py)
                    """)
                }

                if paramIsUnderscore[idx] {
                    callArgs.append(pName)
                } else {
                    callArgs.append("\(paramLabels[idx]): \(pName)")
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
                return ApplePy_None()
            """
        } else {
            returnConversion = """
                let _result = \(isThrowing ? "try " : "")\(callExpr)
                return _result.intoPython(py: _py)
            """
        }

        // Build the full wrapper function body
        // Always use do/catch because fromPython() throws, even for non-throwing host functions
        let unpackBlock = unpackLines.joined(separator: "\n")

        let needsTryCatch = paramCount > 0 || isThrowing

        let wrapperBody: String
        if needsTryCatch {
            wrapperBody = """
                let _py = PythonHandle()
                do {
                    \(unpackBlock)
                    \(returnConversion)
                } catch {
                    setPythonConversionException(error)
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

        // Generate a single @_cdecl wrapper function
        // The name _applepy_<funcName> satisfies `names: prefixed(_applepy_)`
        // PyMethodDef is generated by #pymodule which knows the function names
        let namespaceName = "_applepy_\(funcName)"
        let flagsName = "_applepy_flags_\(funcName)"
        let flagsValue = paramCount == 0 ? "METH_NOARGS" : "METH_VARARGS"

        let wrapperDecl: DeclSyntax = """
            @_cdecl("\(raw: namespaceName)")
            func \(raw: namespaceName)(
                _ _self: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                \(raw: wrapperBody)
            }
            """

        // Exposes the correct METH_* flag for this function's arity so
        // @PyModule can build an accurate PyMethodDef without guessing.
        // Using METH_VARARGS unconditionally would break valid zero-arg
        // calls from Python (they'd be invoked with an empty args tuple,
        // which is fine for METH_VARARGS, but METH_NOARGS is the correct,
        // more efficient flag CPython expects for truly argument-less methods).
        let flagsDecl: DeclSyntax = """
            let \(raw: flagsName): Int32 = \(raw: flagsValue)
            """

        return [wrapperDecl, flagsDecl]
    }
}

// MARK: - Error type

struct MacroError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}
