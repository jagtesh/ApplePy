# Examples

Real-world Python packages built with ApplePy, each wrapping a different Apple framework.

## Showcase Projects

| Package | Framework | Install | Source |
|---------|-----------|---------|--------|
| [SwiftKeychain](swiftkeychain.md) | Security (Keychain) | `pip install swiftkeychain` | [GitHub](https://github.com/jagtesh/swiftkeychain) |
| [PyNatural](pynatural.md) | NaturalLanguage (NLP) | `pip install pynatural` | [GitHub](https://github.com/jagtesh/pynatural) |
| [PyCoreML](pycoreml.md) | CoreML (ML inference) | `pip install pycoreml` | [GitHub](https://github.com/jagtesh/pycoreml) |

All three are available on PyPI and can be installed with `pip install`.

## SwiftKeychain

Secure credential storage using the macOS Keychain — set, get, delete, and find passwords from Python.

```python
import swiftkeychain as kc

kc.set_password("myapp", "user@email.com", "s3cret")
pw = kc.get_password("myapp", "user@email.com")  # → "s3cret"
```

[:octicons-arrow-right-24: Full documentation](swiftkeychain.md)

## PyNatural

Apple's NaturalLanguage framework — language detection, tokenization, POS tagging, NER, sentiment analysis, and word embeddings.

```python
import pynatural as nl

nl.detect_language("Bonjour le monde")  # → "fr"
nl.tokenize("東京は美しい都市です")       # → ["東京", "は", "美しい", "都市", "です"]
```

[:octicons-arrow-right-24: Full documentation](pynatural.md)

## PyCoreML

Run CoreML models from Python — load `.mlmodel` files, make predictions, and control compute units.

```python
import pycoreml as ml

model = ml.load_model("MyModel.mlmodel")
result = ml.predict(model, {"input": 42.0})
```

[:octicons-arrow-right-24: Full documentation](pycoreml.md)
