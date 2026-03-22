// ApplePy – Subclassing Exploration
// Exploring the feasibility of Python subclasses of @PyClass types.
//
// ═══════════════════════════════════════════════════════════════
// SCENARIO: A Swift type exposed via @PyClass, subclassed from Python
// ═══════════════════════════════════════════════════════════════
//
// Goal:
//   # Python code:
//   class MyCounter(mylib.Counter):
//       def decrement(self):
//           self._count -= 1
//
// How CPython subclassing works:
// 1. The base type (Counter) must have Py_TPFLAGS_BASETYPE set ← we do this ✅
// 2. The derived type's tp_base points to the base type
// 3. Python allocates extra space for the subclass (via tp_basicsize)
// 4. The subclass inherits all slots from the base
//
// CHALLENGE #1: tp_basicsize
// Our PyObject layout is:
//   struct _Counter_PyObject {
//       PyObject ob_base      ← CPython header
//       UnsafeMutableRawPointer swiftPtr ← pointer to Swift Box
//   }
// basicsize = sizeof(_Counter_PyObject)
//
// When Python subclasses, it sets basicsize = max(parent.basicsize, child.basicsize)
// If the Python subclass doesn't add C-level fields, it inherits the parent's basicsize.
// This WORKS — the Swift pointer is inherited and accessible. ✅
//
// CHALLENGE #2: Method override from Python
// If a Python subclass overrides a method that we register via tp_methods,
// CPython's MRO (Method Resolution Order) handles this correctly.
// Python's __dict__ takes precedence over tp_methods.
// This WORKS — Python can override any @PyMethod. ✅
//
// CHALLENGE #3: init override
// If a Python subclass overrides __init__:
//   class MyCounter(mylib.Counter):
//       def __init__(self, start, label):
//           super().__init__(start)
//           self.label = label
//
// This WORKS because:
// - tp_new allocates the shell (inherited from base)
// - Python's __init__ calls super().__init__() which invokes our tp_init
// - Python can add __dict__ attributes (label) naturally
//
// CHALLENGE #4: tp_dealloc inheritance
// The subclass inherits tp_dealloc from the base.
// Our tp_dealloc calls Unmanaged.release() on the Swift Box.
// When the subclass is deallocated, the base's tp_dealloc is called,
// which correctly releases the Swift object. ✅
//
// CHALLENGE #5: Calling overridden Python methods from Swift
// If Swift calls a method on the object and Python has overridden it,
// Swift's @_cdecl wrapper calls the Swift method directly on the Box,
// BYPASSING the Python override.
//
// This is the FUNDAMENTAL LIMITATION:
// Swift doesn't know about Python overrides.
// If Swift code calls counter.increment(), it calls the Swift implementation,
// not the Python override.
//
// ═══════════════════════════════════════════════════════════════
// VERDICT: MOSTLY FEASIBLE (with documented limitation)
// ═══════════════════════════════════════════════════════════════
//
// ✅ Python subclassing of @PyClass types WORKS out of the box
//    (we already set BASETYPE flag)
// ✅ Python can override methods and add new ones
// ✅ Python can call super().__init__()
// ✅ Memory management is inherited correctly
// ❌ Swift-side method calls don't see Python overrides
//    (Would need to check tp_dict/MRO at call site — possible but expensive)
//
// RECOMMENDATION: Document that subclassing works from Python but
// Swift won't dispatch through Python's MRO. This matches PyO3's behavior.

// No code needed — subclassing works with Py_TPFLAGS_BASETYPE which we already set.
