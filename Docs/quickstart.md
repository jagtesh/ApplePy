# Quickstart

Go from zero to a working Python extension in 60 seconds.

## 1. Install the CLI

=== "pip"

    ```bash
    pip install applepy-cli
    ```

=== "uv"

    ```bash
    uv pip install applepy-cli
    ```

## 2. Create a project

```bash
applepy new myproject
cd myproject
```

This generates:

```
myproject/
├── pyproject.toml
├── myproject/
│   ├── __init__.py
│   └── examples/demo.py
└── swift/
    ├── Package.swift
    └── Sources/MyProject/MyProject.swift
```

## 3. Build & install

```bash
applepy develop
```

This compiles the Swift code and installs the package into your current Python environment.

## 4. Use it

```bash
python myproject/examples/demo.py
```

```
Hello, World! 🍎
Hello, ApplePy! 🍎
```

Or from a Python REPL:

```python
>>> import myproject
>>> myproject.hello("World")
'Hello, World! 🍎'
```

## 5. Add your own functions

Edit `swift/Sources/MyProject/MyProject.swift`:

```swift
import ApplePy
@preconcurrency import ApplePyFFI

@PyFunction
func hello(name: String = "World") -> String {
    return "Hello, \(name)! 🍎"
}

// Add a new function:
@PyFunction
func add(a: Int, b: Int) -> Int {
    return a + b
}

// Register it in the module:
@PyModule("myproject", functions: [
    hello,
    add,  // ← add it here
])
func myproject() {}
```

Then rebuild:

```bash
applepy develop
```

```python
>>> import myproject
>>> myproject.add(2, 3)
5
```

## 6. Use Apple frameworks

This is where ApplePy shines. Any Apple framework available in Swift is accessible:

```swift
import ApplePy
import NaturalLanguage
@preconcurrency import ApplePyFFI

@PyFunction
func detect_language(text: String) -> String {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    return recognizer.dominantLanguage?.rawValue ?? "unknown"
}

@PyModule("myproject", functions: [detect_language])
func myproject() {}
```

```python
>>> import myproject
>>> myproject.detect_language("Bonjour le monde")
'fr'
>>> myproject.detect_language("こんにちは世界")
'ja'
```

## 7. Publish

```bash
applepy build     # → dist/myproject-0.1.0-py3-none-any.whl
applepy publish   # → uploads to PyPI
```

## What's next?

- [Getting Started](getting-started.md) — deeper walkthrough with classes, enums, and error handling
- [Macros Reference](guide/macros.md) — all available macros
- [Examples](examples/index.md) — real-world packages using Apple frameworks
