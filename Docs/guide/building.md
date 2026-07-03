# Building & Packaging

## Recommended: `applepy` CLI

The easiest way to build and package ApplePy projects:

```bash
pip install applepy-cli    # or: uv pip install applepy-cli
```

| Command | What it does |
|---------|-------------|
| `applepy develop` | Build Swift + install into current env |
| `applepy build` | Build a distributable wheel (`.whl`) |
| `applepy publish` | Upload to PyPI |

```bash
# Build and install for development
applepy develop

# Build a wheel for distribution
applepy build

# Publish to PyPI (or TestPyPI with --test)
applepy publish
```

---

## Manual Build with SPM

ApplePy uses Swift Package Manager. The `ApplePyFFI` system library target uses `pkg-config` (module `python3-embed`) to find Python headers and libraries automatically. The `-embed` variant is required rather than plain `python3` because ApplePy embeds the interpreter in a host process. A normal CPython extension module resolves Python symbols dynamically from the host interpreter at import time and must *not* link `libpython` directly, but an embedding host process needs to link against `libpython` explicitly — which is exactly what the `-embed` pkg-config module provides.

### Standard build

```bash
PKG_CONFIG_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBPC"))') \
  swift build
```

If your Python installation doesn't expose an unversioned `python3-embed.pc` alias (common on some Homebrew/pyenv installs, which only ship a versioned `python-3.1x-embed.pc`), create a symlink in a directory on `PKG_CONFIG_PATH`, e.g.:

```bash
ln -s "$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBPC"))')/python-3.$(python3 -c 'import sys; print(sys.version_info.minor)')-embed.pc" \
      /tmp/pkgconfig/python3-embed.pc
export PKG_CONFIG_PATH=/tmp/pkgconfig:$PKG_CONFIG_PATH
```

### Building for Python import

Python extensions need the `.dylib` renamed to `.so`:

```bash
cp .build/debug/libMyLib.dylib mylib/mylib.so
```

## SPM Plugins

### ApplePyBuild (Build Tool)

Auto-runs during `swift build`. Handles Python detection via pkg-config.

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

## Environment for mise-managed Python

If you use `mise` to manage Python, set these before building and testing:

```bash
export PYTHONHOME=$(python3 -c 'import sys; print(sys.prefix)')
export DYLD_LIBRARY_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')
export PKG_CONFIG_PATH=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBPC"))')
```
