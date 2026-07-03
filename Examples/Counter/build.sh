#!/bin/bash
# Build the counter extension as a Python-importable .so
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_INCLUDE=$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')
PYTHON_LIBDIR=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')
PYTHON_TAG=$(python3 -c 'import sys; print(f"cpython-{sys.version_info.major}{sys.version_info.minor}")')
PYTHON_HOME=$(python3 -c 'import sys; print(sys.prefix)')
APPLEPY_FFI="$(cd ../.. && pwd)/Sources/ApplePyFFI"

case "$(uname -s)" in
    Darwin) PLATFORM="darwin"; UNDEFINED_SYMBOL_FLAGS="-Xlinker -undefined -Xlinker dynamic_lookup" ;;
    Linux)  PLATFORM="linux-$(uname -m)"; UNDEFINED_SYMBOL_FLAGS="" ;;
    *)      PLATFORM="unknown"; UNDEFINED_SYMBOL_FLAGS="" ;;
esac

SO_NAME="counter.${PYTHON_TAG}-${PLATFORM}.so"

echo "Building ${SO_NAME}..."

# Create a temporary module map for CPython
TMPDIR_MAP=$(mktemp -d)
cat > "$TMPDIR_MAP/module.modulemap" <<EOF
module ApplePyFFI [system] {
    header "${APPLEPY_FFI}/include/applepy_shim.h"
    export *
}
EOF

swiftc \
    -emit-library \
    -o "$SO_NAME" \
    -I "$PYTHON_INCLUDE" \
    -I "$TMPDIR_MAP" \
    -L "$PYTHON_LIBDIR" \
    $UNDEFINED_SYMBOL_FLAGS \
    -parse-as-library \
    counter.swift

rm -rf "$TMPDIR_MAP"

echo "✅ Built: ${SO_NAME}"
echo ""
ln counter.cpy*.* -s counter.so
echo "Run: python3 test_counter.py"
