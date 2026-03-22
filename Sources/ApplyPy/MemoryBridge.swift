// ApplyPy – Memory Bridge
// Formalized protocol and helpers for bridging Swift ARC with Python reference counting.
//
// Design: Two runtimes, two refcounts. Neither tries to synchronize with the other.
// - When Python wraps a Swift object: `Unmanaged.passRetained()` — ARC count +1
// - When Python deallocates the wrapper: `Unmanaged.release()` — ARC count -1
// - Each runtime manages its own count independently.

@preconcurrency import ApplyPyFFI

// MARK: - PyBridged Protocol

/// A type that can be stored inside a Python object's memory.
///
/// Conforming types define how they are boxed (stored) and unboxed (retrieved)
/// from the opaque pointer slot in a `PyObject`.
///
/// - For **reference types** (classes): the box IS the class itself.
/// - For **value types** (structs): the box is a heap-allocated wrapper class.
public protocol PyBridged {
    associatedtype Box: AnyObject

    /// Wrap this value for storage in a Python object.
    static func box(_ value: Self) -> Box

    /// Extract this value from its boxed storage.
    static func unbox(_ box: Box) -> Self
}

// MARK: - Default struct box

/// A generic box for value types. Stores a mutable copy on the heap.
public final class PyObjectBox<T>: @unchecked Sendable {
    public var value: T

    public init(_ value: T) {
        self.value = value
    }
}

// MARK: - PyObject storage helpers

/// The standard layout for a PyObject wrapping a Swift value.
/// The macro generates this per-type, but this documents the expected layout.
public struct SwiftPyObject {
    public var ob_base: PyObject
    public var swiftPtr: UnsafeMutableRawPointer?
}

/// Convenience extensions for storing/loading Swift objects in Python objects.
/// These encapsulate the `Unmanaged<T>` dance so macros and manual code stay clean.
public enum PyBridge {

    /// Store a Swift value in a Python object, retaining it.
    /// Call this from `tp_init` after creating the Swift value.
    @inlinable
    public static func store<T: PyBridged>(_ value: T, in pyObj: UnsafeMutablePointer<PyObject>) {
        let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: SwiftPyObject.self)
        let box = T.box(value)
        typed.pointee.swiftPtr = Unmanaged.passRetained(box).toOpaque()
    }

    /// Load a Swift value from a Python object without changing the retain count.
    /// Call this from method wrappers to access `self`.
    @inlinable
    public static func load<T: PyBridged>(_ type: T.Type, from pyObj: UnsafeMutablePointer<PyObject>) -> T {
        let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: SwiftPyObject.self)
        let box = Unmanaged<T.Box>.fromOpaque(typed.pointee.swiftPtr!).takeUnretainedValue()
        return T.unbox(box)
    }

    /// Load the mutable box from a Python object (for structs that need mutation).
    @inlinable
    public static func loadBox<T: PyBridged>(_ type: T.Type, from pyObj: UnsafeMutablePointer<PyObject>) -> T.Box {
        let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: SwiftPyObject.self)
        return Unmanaged<T.Box>.fromOpaque(typed.pointee.swiftPtr!).takeUnretainedValue()
    }

    /// Release the Swift value stored in a Python object.
    /// Call this from `tp_dealloc`.
    @inlinable
    public static func release<T: PyBridged>(_ type: T.Type, from pyObj: UnsafeMutablePointer<PyObject>) {
        let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: SwiftPyObject.self)
        if let ptr = typed.pointee.swiftPtr {
            Unmanaged<T.Box>.fromOpaque(ptr).release()
            typed.pointee.swiftPtr = nil
        }
    }

    // MARK: - Debug assertions

    /// Assert that the Python object has a positive reference count.
    /// Call this before accessing the Swift value from Python-facing code.
    @inlinable
    public static func assertPyAlive(_ pyObj: UnsafeMutablePointer<PyObject>) {
        #if DEBUG
        let refcnt = ApplyPy_REFCNT(pyObj)
        precondition(refcnt >= 1, "ApplyPy: Accessing PyObject with refcnt=\(refcnt) — already deallocated?")
        #endif
    }

    /// Assert that the Swift pointer is non-nil.
    @inlinable
    public static func assertSwiftAlive(_ pyObj: UnsafeMutablePointer<PyObject>) {
        #if DEBUG
        let typed = UnsafeMutableRawPointer(pyObj).assumingMemoryBound(to: SwiftPyObject.self)
        precondition(typed.pointee.swiftPtr != nil, "ApplyPy: Swift object pointer is nil — already released?")
        #endif
    }
}
