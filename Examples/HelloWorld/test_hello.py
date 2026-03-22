"""Test the hello Swift extension module."""
import hello

# Test greet
result = hello.greet("World")
print(f"greet('World') = {result!r}")
assert result == "Hello, World! (from Swift)", f"Unexpected: {result}"

# Test add
result = hello.add(40, 2)
print(f"add(40, 2) = {result}")
assert result == 42, f"Expected 42, got {result}"

# Test negative numbers
result = hello.add(-10, 3)
print(f"add(-10, 3) = {result}")
assert result == -7, f"Expected -7, got {result}"

# Test error handling
try:
    hello.greet(42)  # Wrong type
    assert False, "Should have raised TypeError"
except TypeError:
    print("greet(42) correctly raised TypeError")

print("\n✅ All tests passed!")
