# Building & Packaging

## Building with SPM

ApplePy uses Swift Package Manager. The `ApplePyFFI` system library target uses `pkg-config` to find Python headers and libraries automatically.

### Standard build

```bash
PKG_CONFIG_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBPC"))') \
  swift build
```

### Building for Python import

Python extensions need special naming. Use the example build scripts as reference:

```bash
# Set up environment
PYTHON_INCLUDE=$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')
PYTHON_LIBDIR=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')
PYTHON_TAG=$(python3 -c 'import sys; print(f"cpython-{sys.version_info.major}{sys.version_info.minor}")')

# Compile
swiftc -emit-library -o "mylib.${PYTHON_TAG}-darwin.so" \
    -I "$PYTHON_INCLUDE" \
    -L "$PYTHON_LIBDIR" \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    -parse-as-library \
    mylib.swift
```

## SPM Plugins

### ApplePyBuild (Build Tool)

Auto-runs during `swift build`. Currently handles Python detection via pkg-config.

### ApplePyBundle (Command Plugin)

Renames the built `.dylib`/`.so` to CPython-compatible naming:

```bash
swift package plugin applepy-bundle --target MyExtension
```

This copies `libMyExtension.dylib` → `dist/myextension.cpython-3XX-PLATFORM.so`.

## Wheel Packaging

The `Tools/applepy-pack.py` script generates PEP 427 wheels:

```bash
python3 Tools/applepy-pack.py \
    --name mylib \
    --version 0.1.0 \
    --so dist/mylib.cpython-313-darwin.so

# Produces: dist/mylib-0.1.0-cp313-cp313-macosx_14_0_arm64.whl
pip install dist/mylib-*.whl
```

### Wheel contents

```
mylib.cpython-313-darwin.so     # The extension module
mylib-0.1.0.dist-info/METADATA # Package metadata
mylib-0.1.0.dist-info/WHEEL    # Wheel format metadata
mylib-0.1.0.dist-info/RECORD   # File hashes
mylib-0.1.0.dist-info/top_level.txt
```

## Environment for mise-managed Python

If you use `mise` to manage Python, set these before building and testing:

```bash
export PYTHONHOME=$(python3 -c 'import sys; print(sys.prefix)')
export DYLD_LIBRARY_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')
export PKG_CONFIG_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBPC"))')
```
