import Testing
@testable import ApplePy
import ApplePyFFI

/// Ensure Python is initialized exactly once.
/// After initialization, release the GIL so that test threads can acquire it.
private let pythonReady: Bool = {
    Py_Initialize()
    // Release the main thread's GIL so test threads can acquire it
    // PyEval_SaveThread releases the GIL and returns a thread state
    _ = PyEval_SaveThread()
    return true
}()

@Suite("Type Conversion Tests", .serialized)
struct TypeConversionTests {

    init() {
        precondition(pythonReady, "Python failed to initialize")
    }

    /// Each test must acquire the GIL since Swift Testing may use different threads.
    private func withPython<T>(_ body: (PythonHandle) throws -> T) rethrows -> T {
        let gstate = PyGILState_Ensure()
        defer { PyGILState_Release(gstate) }
        return try body(PythonHandle())
    }

    @Test("Int roundtrip")
    func intRoundtrip() throws {
        try withPython { py in
            let original = 42
            let pyObj = original.intoPython(py: py)!
            let restored = try Int.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("Negative Int roundtrip")
    func negativeIntRoundtrip() throws {
        try withPython { py in
            let original = -9999
            let pyObj = original.intoPython(py: py)!
            let restored = try Int.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("String roundtrip")
    func stringRoundtrip() throws {
        try withPython { py in
            let original = "Hello, ApplePy! 🐍🍎"
            let pyObj = original.intoPython(py: py)!
            let restored = try String.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("Bool roundtrip")
    func boolRoundtrip() throws {
        try withPython { py in
            let pyTrue = true.intoPython(py: py)!
            let pyFalse = false.intoPython(py: py)!
            let restoredTrue = try Bool.fromPython(pyTrue, py: py)
            let restoredFalse = try Bool.fromPython(pyFalse, py: py)
            ApplePy_DECREF(pyTrue)
            ApplePy_DECREF(pyFalse)
            #expect(restoredTrue == true)
            #expect(restoredFalse == false)
        }
    }

    @Test("Double roundtrip")
    func doubleRoundtrip() throws {
        try withPython { py in
            let original = 3.14159
            let pyObj = original.intoPython(py: py)!
            let restored = try Double.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("Float roundtrip")
    func floatRoundtrip() throws {
        try withPython { py in
            let original: Float = 2.718
            let pyObj = original.intoPython(py: py)!
            let restored = try Float.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(abs(restored - original) < 0.0001)
        }
    }

    @Test("Array<Int> roundtrip")
    func arrayRoundtrip() throws {
        try withPython { py in
            let original = [1, 2, 3, 4, 5]
            let pyObj = original.intoPython(py: py)!
            let restored = try [Int].fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("Dictionary<String, Int> roundtrip")
    func dictRoundtrip() throws {
        try withPython { py in
            let original: [String: Int] = ["a": 1, "b": 2, "c": 3]
            let pyObj = original.intoPython(py: py)!
            let restored = try [String: Int].fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("Optional<Int> roundtrip — nil")
    func optionalNilRoundtrip() throws {
        try withPython { py in
            let original: Int? = nil
            let pyObj = original.intoPython(py: py)!
            let restored = try Int?.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == nil)
        }
    }

    @Test("Optional<Int> roundtrip — some")
    func optionalSomeRoundtrip() throws {
        try withPython { py in
            let original: Int? = 42
            let pyObj = original.intoPython(py: py)!
            let restored = try Int?.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == 42)
        }
    }

    @Test("Type mismatch throws error")
    func typeMismatchThrows() throws {
        try withPython { py in
            let pyStr = "not an int".intoPython(py: py)!
            defer { ApplePy_DECREF(pyStr) }
            #expect(throws: PythonConversionError.self) {
                _ = try Int.fromPython(pyStr, py: py)
            }
        }
    }
}
