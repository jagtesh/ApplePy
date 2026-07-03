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

    @Test("Set<Int> roundtrip")
    func setRoundtrip() throws {
        try withPython { py in
            let original: Set<Int> = [1, 2, 3, 4, 5]
            let pyObj = original.intoPython(py: py)!
            let restored = try Set<Int>.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored == original)
        }
    }

    @Test("Set<Int> type mismatch throws error")
    func setTypeMismatchThrows() throws {
        try withPython { py in
            let pyList = [1, 2, 3].intoPython(py: py)!
            defer { ApplePy_DECREF(pyList) }
            #expect(throws: PythonConversionError.self) {
                _ = try Set<Int>.fromPython(pyList, py: py)
            }
        }
    }

    @Test("PyTuple2 roundtrip")
    func tuple2Roundtrip() throws {
        try withPython { py in
            let original = PyTuple2(42, "hello")
            let pyObj = original.intoPython(py: py)!
            let restored = try PyTuple2<Int, String>.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored._0 == 42)
            #expect(restored._1 == "hello")
        }
    }

    @Test("PyTuple2 wrong arity throws error")
    func tuple2WrongArityThrows() throws {
        try withPython { py in
            let original = [1, 2, 3].intoPython(py: py)!
            defer { ApplePy_DECREF(original) }
            // A list is not a tuple, so this should throw a type mismatch.
            #expect(throws: PythonConversionError.self) {
                _ = try PyTuple2<Int, Int>.fromPython(original, py: py)
            }
        }
    }

    @Test("PyTuple3 roundtrip")
    func tuple3Roundtrip() throws {
        try withPython { py in
            let original = PyTuple3(1, "two", 3.0)
            let pyObj = original.intoPython(py: py)!
            let restored = try PyTuple3<Int, String, Double>.fromPython(pyObj, py: py)
            ApplePy_DECREF(pyObj)
            #expect(restored._0 == 1)
            #expect(restored._1 == "two")
            #expect(restored._2 == 3.0)
        }
    }

    @Test("bytes roundtrip")
    func bytesRoundtrip() throws {
        try withPython { _ in
            let original: [UInt8] = [0x00, 0x01, 0xFF, 0x42, 0x7F]
            let pyObj = BufferBridge.bytesToPython(original)!
            defer { ApplePy_DECREF(pyObj) }
            let restored = BufferBridge.bytesFromPython(pyObj)
            #expect(restored == original)
        }
    }

    @Test("bytearray roundtrip")
    func bytearrayRoundtrip() throws {
        try withPython { _ in
            let original: [UInt8] = [0x10, 0x20, 0x30]
            let pyBytes = BufferBridge.bytesToPython(original)!
            defer { ApplePy_DECREF(pyBytes) }
            guard let pyByteArray = PyByteArray_FromObject(pyBytes) else {
                Issue.record("Failed to create bytearray")
                return
            }
            defer { ApplePy_DECREF(pyByteArray) }
            let restored = BufferBridge.bytesFromPython(pyByteArray)
            #expect(restored == original)
        }
    }

    @Test("bytesFromPython returns nil for non-bytes type")
    func bytesFromPythonTypeMismatch() throws {
        try withPython { py in
            let pyInt = 42.intoPython(py: py)!
            defer { ApplePy_DECREF(pyInt) }
            #expect(BufferBridge.bytesFromPython(pyInt) == nil)
        }
    }
}
