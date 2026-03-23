# PyNatural

Apple's NaturalLanguage framework from Python — language detection, tokenization, POS tagging, NER, sentiment analysis, and word embeddings.

[:fontawesome-brands-github: GitHub](https://github.com/jagtesh/pynatural) · [:fontawesome-brands-python: PyPI](https://pypi.org/project/pynatural/)

## Install

```bash
pip install pynatural
```

## API

| Function | Description |
|----------|-------------|
| `detect_language(text)` → `str` | Detect dominant language (ISO 639 code) |
| `detect_language_detailed(text, count)` → `list` | Top-N language candidates with confidence |
| `tokenize(text, unit)` → `list[str]` | Tokenize by word, sentence, or paragraph |
| `tag(text, scheme)` → `list[tuple]` | POS tagging, NER, lemmatization |
| `sentiment(text)` → `float` | Sentiment score (-1.0 to 1.0) |
| `embedding(word)` → `list[float]` | Word embedding vector |
| `distance(word1, word2)` → `float` | Cosine distance between embeddings |
| `neighbors(word, count)` → `list` | Nearest neighbor words |

## Usage

### Language Detection

```python
import pynatural as nl

nl.detect_language("Hello, how are you?")           # → "en"
nl.detect_language("Bonjour le monde")               # → "fr"
nl.detect_language("東京は世界で最も美しい都市")       # → "ja"

# Detailed detection with confidence scores
nl.detect_language_detailed("Ciao mondo, come stai?", 3)
# → [("it", 0.997), ("id", 0.001), ("en", 0.001)]
```

### Tokenization

```python
nl.tokenize("The quick brown fox jumps", "word")
# → ["The", "quick", "brown", "fox", "jumps"]

nl.tokenize("東京は美しい都市です", "word")
# → ["東京", "は", "美しい", "都市", "です"]

nl.tokenize("First sentence. Second! Third?", "sentence")
# → ["First sentence. ", "Second! ", "Third?"]
```

### POS Tagging & NER

```python
# Part-of-speech tagging
nl.tag("The quick brown fox jumps", "lexicalClass")
# → [("The", "Determiner"), ("quick", "Adjective"), ...]

# Named entity recognition
nl.tag("Tim Cook announced at Apple Park in Cupertino", "nameType")
# → [("Tim", "PersonalName"), ("Cook", "PersonalName"),
#    ("Cupertino", "PlaceName")]
```

### Sentiment Analysis

```python
nl.sentiment("This product is absolutely amazing!")  # → 1.0
nl.sentiment("This is the worst experience ever.")   # → -1.0
```

### Word Embeddings

```python
nl.distance("dog", "cat")      # → 0.717 (similar)
nl.distance("dog", "quantum")  # → 1.354 (dissimilar)

nl.neighbors("python", 5)
# → [("snake", 0.868), ("constrictor", 0.890), ...]
```
