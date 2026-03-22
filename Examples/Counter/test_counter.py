"""Test the counter Swift extension module."""
from counter import Counter

# Test basic creation
c = Counter()
print(f"Counter() = {c!r}")
assert repr(c) == "Counter(0)", f"Unexpected repr: {repr(c)}"

# Test creation with initial value
c = Counter(10)
print(f"Counter(10) = {c!r}")
assert c.value() == 10, f"Expected 10, got {c.value()}"

# Test increment
c.increment()
print(f"After increment: {c!r}")
assert c.value() == 11, f"Expected 11, got {c.value()}"

# Test multiple increments
for _ in range(5):
    c.increment()
print(f"After 5 more increments: {c!r}")
assert c.value() == 16, f"Expected 16, got {c.value()}"

# Test negative initial value
c = Counter(-5)
c.increment()
assert c.value() == -4, f"Expected -4, got {c.value()}"

# Test error: wrong argument type
try:
    Counter("not a number")
    assert False, "Should have raised TypeError"
except (TypeError, OverflowError):
    print("Counter('not a number') correctly raised an error")

# Test error: too many arguments
try:
    Counter(1, 2)
    assert False, "Should have raised TypeError"
except TypeError:
    print("Counter(1, 2) correctly raised TypeError")

# Test type
assert type(c).__name__ == "Counter", f"Expected 'Counter', got {type(c).__name__}"

# Test many objects (memory stress test)
counters = [Counter(i) for i in range(1000)]
assert all(counters[i].value() == i for i in range(1000)), "Memory stress test failed"
del counters  # Should trigger tp_dealloc for all 1000 objects
print("Memory stress test (1000 objects): passed")

print("\n✅ All tests passed!")
