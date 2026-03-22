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
    Darwin) PLATFORM="darwin" ;; 
    Linux)  PLATFORM="linux-$(uname -m)" ;;
    *)      PLATFORM="unknown" ;;
esac

SO_NAME="counter.${PYTHON_TAG}-${PLATFORM}.so"

echo "Building ${SO_NAME}..."

# Create a temporary module map for CPython
TMPDIR_MAP=$(mktemp -d)
cat > "$TMPDIR_MAP/module.modulemap" <<EOF
module CPythonShim [system] {
    header "${APPLEPY_FFI}/include/applepy_shim.h"
    link "python3.13"
    export *
}
EOF

swiftc \
    -emit-library \
    -o "$SO_NAME" \
    -I "$PYTHON_INCLUDE" \
    -I "$TMPDIR_MAP" \
    -L "$PYTHON_LIBDIR" \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    -parse-as-library \
    counter.swift

rm -rf "$TMPDIR_MAP"

echo "✅ Built: ${SO_NAME}"
echo ""
echo "Run: DYLD_LIBRARY_PATH='${PYTHON_LIBDIR}' PYTHONHOME='${PYTHON_HOME}' python3 test_counter.py"
