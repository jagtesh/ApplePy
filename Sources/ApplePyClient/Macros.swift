// ApplePy – Macro Declarations
// Users import this target to use @PyClass, @PyFunction, @PyMethod.

@attached(member, names: arbitrary)
public macro PyClass() = #externalMacro(module: "ApplePyMacros", type: "PyClassMacro")

@attached(peer, names: prefixed(_applepy_))
public macro PyFunction() = #externalMacro(module: "ApplePyMacros", type: "PyFunctionMacro")

@attached(peer, names: prefixed(_applepy_))
public macro PyMethod(_ pythonName: String? = nil) = #externalMacro(module: "ApplePyMacros", type: "PyMethodMacro")

@attached(peer, names: prefixed(_applepy_))
public macro PyModule(_ name: String, types: [Any.Type] = [], functions: [Any] = []) = #externalMacro(module: "ApplePyMacros", type: "PyModuleMacro")

@attached(member, names: arbitrary)
public macro PyEnum() = #externalMacro(module: "ApplePyMacros", type: "PyEnumMacro")

@attached(peer, names: prefixed(_applepy_))
public macro PyProperty() = #externalMacro(module: "ApplePyMacros", type: "PyPropertyMacro")

@attached(peer, names: prefixed(_applepy_))
public macro PyStaticMethod() = #externalMacro(module: "ApplePyMacros", type: "PyStaticMethodMacro")

@attached(member, names: arbitrary)
@attached(extension, names: arbitrary)
public macro PyUnion() = #externalMacro(module: "ApplePyMacros", type: "PyUnionMacro")
