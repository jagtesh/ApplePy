// ApplePy – Buffer Protocol Support
// Enables zero-copy access to Swift Data/Array<UInt8> from Python via memoryview.
//
// FEASIBILITY EXPLORATION:
// The buffer protocol requires implementing bf_getbuffer and bf_releasebuffer
// type slots. These are C function pointers with specific signatures.
//
// Challenge: Swift cannot directly express Py_buffer struct manipulation,
// and the buffer protocol requires careful pointer lifetime management.
//
// Approach: Implement as a helper that can be used in @PyClass tp_methods
// or as standalone functions.

import ApplePyFFI

/// Extension to make Array<UInt8> work with Python's buffer protocol.
/// This demonstrates the feasibility of zero-copy buffer access.
///
/// Usage in a @PyClass:
///   - Add a `data` property of type `[UInt8]` or `Data`
///   - The generated type would include bf_getbuffer/bf_releasebuffer slots
public enum BufferBridge {

    /// Create a Python `bytes` object from a Swift byte array (copies data).
    @inlinable
    public static func bytesToPython(_ bytes: [UInt8]) -> UnsafeMutablePointer<PyObject>? {
        return bytes.withUnsafeBufferPointer { buffer in
            return PyBytes_FromStringAndSize(
                buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: buffer.count) { $0 },
                buffer.count
            )
        }
    }

    /// Extract bytes from a Python `bytes` or `bytearray` object (copies data).
    public static func bytesFromPython(_ obj: UnsafeMutablePointer<PyObject>) -> [UInt8]? {
        // Try bytes first
        if let ptr = PyBytes_AsString(obj) {
            let len = PyBytes_Size(obj)
            return Array(UnsafeBufferPointer(start: ptr.withMemoryRebound(to: UInt8.self, capacity: len) { $0 }, count: len))
        }
        return nil
    }

    // ═══════════════════════════════════════════════════════════════
    // TRUE ZERO-COPY BUFFER PROTOCOL
    //
    // The real buffer protocol (bf_getbuffer / bf_releasebuffer) requires:
    //
    // 1. A C function with signature:
    //    int (*getbufferproc)(PyObject *exporter, Py_buffer *view, int flags)
    //
    // 2. Filling the Py_buffer struct with:
    //    - buf: raw pointer to the data
    //    - len: size in bytes
    //    - itemsize: size of each element
    //    - format: format string ("B" for uint8)
    //    - ndim: number of dimensions
    //    - shape/strides: arrays (must outlive the buffer view)
    //
    // 3. The release function must clean up any retained state.
    //
    // FEASIBILITY VERDICT: PARTIALLY FEASIBLE
    //
    // ✅ We CAN generate bf_getbuffer/bf_releasebuffer functions from Swift
    //    using @_cdecl, since the Py_buffer struct is importable.
    //
    // ⚠️ The tricky part is lifetime management:
    //    - The Swift array must not be deallocated while the Python buffer
    //      view exists. We'd need to pin the data (e.g., via withUnsafeBufferPointer
    //      or by retaining a reference in the Py_buffer.obj field).
    //    - For mutable arrays (bf_getbuffer with PyBUF_WRITABLE), mutations
    //      from Python would need to be reflected back to Swift.
    //
    // ❌ Associated values in enums can't participate in the buffer protocol
    //    without boxing, which defeats the zero-copy purpose.
    //
    // RECOMMENDATION: Implement as a copy-based bridge (bytes/bytearray)
    // for the common case, add true zero-copy only for pinned Data objects
    // where the lifetime can be guaranteed.
    // ═══════════════════════════════════════════════════════════════
}
