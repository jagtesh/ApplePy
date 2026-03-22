// ApplyPy – Macro Declarations
// Users import this target to use @PyClass, @PyFunction, @PyMethod.

@attached(member, names: arbitrary)
public macro PyClass() = #externalMacro(module: "ApplyPyMacros", type: "PyClassMacro")

@attached(peer, names: arbitrary)
public macro PyFunction() = #externalMacro(module: "ApplyPyMacros", type: "PyFunctionMacro")

@attached(peer, names: arbitrary)
public macro PyMethod(_ pythonName: String? = nil) = #externalMacro(module: "ApplyPyMacros", type: "PyMethodMacro")
