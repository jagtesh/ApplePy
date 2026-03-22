// ApplePy – Macro Declarations
// Users import this target to use @PyClass, @PyFunction, @PyMethod.

@attached(member, names: arbitrary)
public macro PyClass() = #externalMacro(module: "ApplePyMacros", type: "PyClassMacro")

@attached(peer, names: arbitrary)
public macro PyFunction() = #externalMacro(module: "ApplePyMacros", type: "PyFunctionMacro")

@attached(peer, names: arbitrary)
public macro PyMethod(_ pythonName: String? = nil) = #externalMacro(module: "ApplePyMacros", type: "PyMethodMacro")

@freestanding(declaration, names: arbitrary)
public macro pymodule(_ name: String, types: [Any.Type] = [], functions: [Any] = []) = #externalMacro(module: "ApplePyMacros", type: "PyModuleMacro")
