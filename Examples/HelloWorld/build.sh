#!/bin/bash
# Build the hello extension as a Python-importable .so
# Usage: ./build.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Detect Python paths
PYTHON_INCLUDE=$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')
PYTHON_LIBDIR=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')
PYTHON_TAG=$(python3 -c 'import sys; print(f"cpython-{sys.version_info.major}{sys.version_info.minor}")')
APPLEPY_FFI="$(cd ../.. && pwd)/Sources/ApplePyFFI"

# Determine platform suffix
case "$(uname -s)" in
    Darwin) PLATFORM="darwin" ;; 
    Linux)  PLATFORM="linux-$(uname -m)" ;;
    *)      PLATFORM="unknown" ;;
esac

SO_NAME="hello.${PYTHON_TAG}-${PLATFORM}.so"

echo "Building ${SO_NAME}..."
echo "  Python include: ${PYTHON_INCLUDE}"
echo "  Python libdir:  ${PYTHON_LIBDIR}"
echo "  ApplePyFFI:     ${APPLEPY_FFI}"

# Create a temporary module map for CPython
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/module.modulemap" <<EOF
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
    -I "$TMPDIR" \
    -L "$PYTHON_LIBDIR" \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    -parse-as-library \
    hello.swift

rm -rf "$TMPDIR"

echo "✅ Built: ${SO_NAME}"
echo ""
echo "Run: DYLD_LIBRARY_PATH='${PYTHON_LIBDIR}' PYTHONHOME='$(python3 -c "import sys; print(sys.prefix)")' python3 test_hello.py"
