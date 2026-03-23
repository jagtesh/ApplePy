# PyCoreML

Run CoreML models from Python — load `.mlmodel` files, make predictions, and control compute units.

[:fontawesome-brands-github: GitHub](https://github.com/jagtesh/pycoreml) · [:fontawesome-brands-python: PyPI](https://pypi.org/project/pycoreml/)

## Install

```bash
pip install pycoreml
```

## API

| Function | Description |
|----------|-------------|
| `load_model(path)` → `model` | Load a `.mlmodel` or compiled `.mlmodelc` |
| `predict(model, inputs)` → `dict` | Run inference with input dictionary |
| `model_description(model)` → `str` | Get model metadata and description |
| `set_compute_units(units)` | Set compute preference: `"all"`, `"cpu"`, `"gpu"`, `"neural_engine"` |

## Usage

```python
import pycoreml as ml

# Load a model
model = ml.load_model("MyClassifier.mlmodel")

# Get model info
print(ml.model_description(model))

# Run prediction
result = ml.predict(model, {
    "input_feature": 42.0,
    "image": [0.1, 0.2, 0.3, ...],
})
print(result)

# Control compute units
ml.set_compute_units("neural_engine")  # Use Apple Neural Engine
model = ml.load_model("MyModel.mlmodel")
result = ml.predict(model, {"x": 1.0})
```

## Compute Units

| Value | Description |
|-------|-------------|
| `"all"` | Auto-select best (default) |
| `"cpu"` | CPU only |
| `"gpu"` | GPU (Metal) |
| `"neural_engine"` | Apple Neural Engine |
