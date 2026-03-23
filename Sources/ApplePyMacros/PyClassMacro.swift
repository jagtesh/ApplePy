// ApplePy – @PyClass Macro Implementation
// Generates: PyObject storage struct, tp_new, tp_init, tp_dealloc, PyType_Spec, and registration.

import SwiftSyntax
import SwiftSyntaxMacros

public struct PyClassMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get the type name
        let typeName: String
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            typeName = structDecl.name.text
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            typeName = classDecl.name.text
        } else {
            throw MacroError("@PyClass can only be applied to structs or classes")
        }

        let isClass = declaration.is(ClassDeclSyntax.self)
        let boxName = "_\(typeName)_Box"
        let pyObjName = "_\(typeName)_PyObject"

        // Find the init parameters (first non-private init)
        let initParams = extractInitParams(from: declaration)

        // Find all @PyMethod-annotated methods
        let methods = extractPyMethods(from: declaration)

        // Find __repr__ method
        let hasRepr = methods.contains { $0.pythonName == "__repr__" }

        var decls: [DeclSyntax] = []

        // 1. Generate the Box class (for value types; for classes, box IS the class)
        if !isClass {
            decls.append("""
                private final class \(raw: boxName) {
                    var value: \(raw: typeName)
                    init(_ v: \(raw: typeName)) { self.value = v }
                }
                """)
        }

        // 2. Generate the PyObject storage struct
        decls.append("""
            struct \(raw: pyObjName) {
                var ob_base: PyObject
                var swiftPtr: UnsafeMutableRawPointer?
            }
            """)

        // 3. Generate box helpers
        let boxType = isClass ? typeName : boxName
        decls.append("""
            private static func _getSwiftValue(_ pyObj: UnsafeMutablePointer<PyObject>) -> \(raw: typeName) {
                let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: \(raw: pyObjName).self)
                let box = Unmanaged<\(raw: boxType)>.fromOpaque(typed.pointee.swiftPtr!).takeUnretainedValue()
                return \(raw: isClass ? "box" : "box.value")
            }
            """)

        decls.append("""
            private static func _setSwiftValue(_ pyObj: UnsafeMutablePointer<PyObject>, _ value: \(raw: typeName)) {
                let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: \(raw: pyObjName).self)
                let box: \(raw: boxType) = \(raw: isClass ? "value" : "\(boxName)(value)")
                typed.pointee.swiftPtr = Unmanaged.passRetained(box).toOpaque()
            }
            """)

        decls.append("""
            private static func _releaseSwiftValue(_ pyObj: UnsafeMutablePointer<PyObject>) {
                let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: \(raw: pyObjName).self)
                if let ptr = typed.pointee.swiftPtr {
                    Unmanaged<\(raw: boxType)>.fromOpaque(ptr).release()
                    typed.pointee.swiftPtr = nil
                }
            }
            """)

        // 4. Generate tp_new
        let tpNewName = "_applepy_\(typeName)_tp_new"
        decls.append("""
            @_cdecl("\(raw: tpNewName)")
            public static func _tp_new(
                _ type: UnsafeMutablePointer<PyTypeObject>?,
                _ args: UnsafeMutablePointer<PyObject>?,
                _ kwargs: UnsafeMutablePointer<PyObject>?
            ) -> UnsafeMutablePointer<PyObject>? {
                guard let type = type else { return nil }
                guard let self_ = type.pointee.tp_alloc?(type, 0) else { return nil }
                let typed = UnsafeMutableRawPointer(self_).assumingMemoryBound(to: \(raw: pyObjName).self)
                typed.pointee.swiftPtr = nil
                return self_
            }
            """)

        // 5. Generate tp_init
        let tpInitName = "_applepy_\(typeName)_tp_init"
        let initBody = generateInitBody(typeName: typeName, params: initParams)
        decls.append("""
            @_cdecl("\(raw: tpInitName)")
            public static func _tp_init(
                _ self_: UnsafeMutablePointer<PyObject>?,
                _ args: UnsafeMutablePointer<PyObject>?,
                _ kwargs: UnsafeMutablePointer<PyObject>?
            ) -> Int32 {
                guard let self_ = self_ else { return -1 }
                let _py = PythonHandle()
                \(raw: initBody)
            }
            """)

        // 6. Generate tp_dealloc
        let tpDeallocName = "_applepy_\(typeName)_tp_dealloc"
        decls.append("""
            @_cdecl("\(raw: tpDeallocName)")
            public static func _tp_dealloc(_ self_: UnsafeMutablePointer<PyObject>?) {
                guard let self_ = self_ else { return }
                _releaseSwiftValue(self_)
                let type = ApplePy_TYPE(self_)
                type?.pointee.tp_free?(UnsafeMutableRawPointer(self_))
            }
            """)

        // 7. Generate tp_repr (if declared)
        let tpReprName = "_applepy_\(typeName)_tp_repr"
        if hasRepr {
            decls.append("""
                @_cdecl("\(raw: tpReprName)")
                public static func _tp_repr(_ self_: UnsafeMutablePointer<PyObject>?) -> UnsafeMutablePointer<PyObject>? {
                    guard let self_ = self_ else { return nil }
                    let value = _getSwiftValue(self_)
                    let repr = value.__repr__()
                    return repr.withCString { PyUnicode_FromString($0) }
                }
                """)
        }

        // 8. Generate method table
        let regularMethods = methods.filter { !$0.pythonName.hasPrefix("__") }
        var methodTableEntries: [String] = []
        for method in regularMethods {
            let wrapperName = "_applepy_\(typeName)_\(method.swiftName)"
            let flags = method.paramCount == 0 ? "METH_NOARGS" : "METH_VARARGS"
            methodTableEntries.append("""
                PyMethodDef(
                    ml_name: "\(method.pythonName)".withCString { UnsafePointer(strdup($0)!) },
                    ml_meth: \(wrapperName),
                    ml_flags: \(flags),
                    ml_doc: nil
                )
            """)
        }
        methodTableEntries.append("PyMethodDef(ml_name: nil, ml_meth: nil, ml_flags: 0, ml_doc: nil)")

        decls.append("""
            static var _pyMethods: [PyMethodDef] = [
                \(raw: methodTableEntries.joined(separator: ",\n        "))
            ]
            """)

        // 9. Generate slot array
        var slotEntries: [String] = []
        slotEntries.append("""
            PyType_Slot(slot: Py_tp_new, pfunc: unsafeBitCast(\(tpNewName) as @convention(c) (UnsafeMutablePointer<PyTypeObject>?, UnsafeMutablePointer<PyObject>?, UnsafeMutablePointer<PyObject>?) -> UnsafeMutablePointer<PyObject>?, to: UnsafeMutableRawPointer.self))
        """)
        slotEntries.append("""
            PyType_Slot(slot: Py_tp_init, pfunc: unsafeBitCast(\(tpInitName) as @convention(c) (UnsafeMutablePointer<PyObject>?, UnsafeMutablePointer<PyObject>?, UnsafeMutablePointer<PyObject>?) -> Int32, to: UnsafeMutableRawPointer.self))
        """)
        slotEntries.append("""
            PyType_Slot(slot: Py_tp_dealloc, pfunc: unsafeBitCast(\(tpDeallocName) as @convention(c) (UnsafeMutablePointer<PyObject>?) -> Void, to: UnsafeMutableRawPointer.self))
        """)
        if hasRepr {
            slotEntries.append("""
                PyType_Slot(slot: Py_tp_repr, pfunc: unsafeBitCast(\(tpReprName) as @convention(c) (UnsafeMutablePointer<PyObject>?) -> UnsafeMutablePointer<PyObject>?, to: UnsafeMutableRawPointer.self))
            """)
        }
        slotEntries.append("""
            PyType_Slot(slot: Py_tp_methods, pfunc: UnsafeMutableRawPointer(&_pyMethods))
        """)
        slotEntries.append("PyType_Slot(slot: 0, pfunc: nil)")

        decls.append("""
            static var _pySlots: [PyType_Slot] = [
                \(raw: slotEntries.joined(separator: ",\n        "))
            ]
            """)

        // 10. Generate PyType_Spec
        decls.append("""
            static var _pyTypeSpec: PyType_Spec = {
                let name: UnsafePointer<CChar> = "\(raw: typeName)".withCString { UnsafePointer(strdup($0)!) }
                return PyType_Spec(
                    name: name,
                    basicsize: Int32(MemoryLayout<\(raw: pyObjName)>.size),
                    itemsize: 0,
                    flags: UInt32(Py_TPFLAGS_DEFAULT) | UInt32(Py_TPFLAGS_BASETYPE),
                    slots: &_pySlots
                )
            }()
            """)

        // 11. Generate registerType helper
        decls.append("""
            public static func registerType(in module: UnsafeMutablePointer<PyObject>) -> Bool {
                guard let typeObj = PyType_FromSpec(&_pyTypeSpec) else { return false }
                let name: UnsafePointer<CChar> = "\(raw: typeName)".withCString { UnsafePointer(strdup($0)!) }
                if PyModule_AddObject(module, name, typeObj) < 0 {
                    ApplePy_DECREF(typeObj)
                    return false
                }
                return true
            }
            """)

        return decls
    }

    // MARK: - Helpers

    private static func extractInitParams(from declaration: some DeclGroupSyntax) -> [(name: String, type: String)] {
        var params: [(name: String, type: String)] = []

        for member in declaration.memberBlock.members {
            if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                let sig = initDecl.signature
                for param in sig.parameterClause.parameters {
                    let name = param.secondName?.text ?? param.firstName.text
                    let type = param.type.trimmedDescription
                    params.append((name: name, type: type))
                }
                break // use first init
            }
        }
        return params
    }

    private static func extractPyMethods(from declaration: some DeclGroupSyntax) -> [MethodInfo] {
        var methods: [MethodInfo] = []

        for member in declaration.memberBlock.members {
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

            // Check if it has @PyMethod attribute
            let hasPyMethod = funcDecl.attributes.contains { attr in
                if case .attribute(let a) = attr {
                    return a.attributeName.trimmedDescription == "PyMethod"
                }
                return false
            }

            guard hasPyMethod else { continue }

            // Extract Python name from @PyMethod("name") or use Swift name
            var pythonName = funcDecl.name.text
            for attr in funcDecl.attributes {
                if case .attribute(let a) = attr,
                   a.attributeName.trimmedDescription == "PyMethod",
                   let argList = a.arguments?.as(LabeledExprListSyntax.self),
                   let firstArg = argList.first,
                   let strLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) {
                    pythonName = strLiteral.segments.trimmedDescription
                }
            }

            let paramCount = funcDecl.signature.parameterClause.parameters.count
            methods.append(MethodInfo(swiftName: funcDecl.name.text, pythonName: pythonName, paramCount: paramCount))
        }

        return methods
    }

    private static func generateInitBody(typeName: String, params: [(name: String, type: String)]) -> String {
        if params.isEmpty {
            return """
                _releaseSwiftValue(self_)
                let value = \(typeName)()
                _setSwiftValue(self_, value)
                return 0
            """
        }

        var lines: [String] = []
        lines.append("""
            guard let args = args else {
                PyErr_SetString(PyExc_TypeError, "\(typeName)() requires arguments")
                return -1
            }
            let _nArgs = PyTuple_Size(args)
            guard _nArgs == \(params.count) else {
                PyErr_SetString(PyExc_TypeError, "\(typeName)() takes exactly \(params.count) argument(s)")
                return -1
            }
        """)

        var callArgs: [String] = []
        for (i, param) in params.enumerated() {
            lines.append("""
                guard let _pyArg\(i) = PyTuple_GetItem(args, \(i)) else { return -1 }
            """)

            // For tp_init we can't use try — need to handle errors manually
            lines.append("""
                let \(param.name): \(param.type)
                do {
                    \(param.name) = try \(param.type).fromPython(_pyArg\(i), py: _py)
                } catch {
                    setPythonConversionException(error)
                    return -1
                }
            """)
            callArgs.append("\(param.name): \(param.name)")
        }

        lines.append("""
            _releaseSwiftValue(self_)
            let value = \(typeName)(\(callArgs.joined(separator: ", ")))
            _setSwiftValue(self_, value)
            return 0
        """)

        return lines.joined(separator: "\n")
    }
}

struct MethodInfo {
    let swiftName: String
    let pythonName: String
    let paramCount: Int
}
