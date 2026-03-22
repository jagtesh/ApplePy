#!/usr/bin/env python3
"""
applepy-pack — Package a Swift Python extension into a wheel (.whl).

Usage:
    python3 applepy-pack.py --name mylib --version 0.1.0 --so dist/mylib.cpython-313-darwin.so

Generates a PEP 427 wheel in dist/.
"""

import argparse
import hashlib
import base64
import os
import platform
import sys
import zipfile
import sysconfig


def get_platform_tag() -> str:
    """Compute the wheel platform tag (e.g., macosx_14_0_arm64)."""
    system = platform.system()
    machine = platform.machine()

    if system == "Darwin":
        ver = platform.mac_ver()[0]
        major, minor = ver.split(".")[:2]
        return f"macosx_{major}_{minor}_{machine}"
    elif system == "Linux":
        # Use manylinux for broad compatibility
        return f"manylinux_2_34_{machine}"
    else:
        return f"{system.lower()}_{machine}"


def get_python_tag() -> str:
    """Compute the Python tag (e.g., cp313)."""
    return f"cp{sys.version_info.major}{sys.version_info.minor}"


def get_abi_tag() -> str:
    """Compute the ABI tag."""
    return f"cp{sys.version_info.major}{sys.version_info.minor}"


def sha256_digest(data: bytes) -> str:
    """Base64url-encoded SHA256 hash (no padding), as required by RECORD."""
    digest = hashlib.sha256(data).digest()
    return "sha256=" + base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")


def build_wheel(name: str, version: str, so_path: str, output_dir: str) -> str:
    """Build a wheel and return its path."""
    python_tag = get_python_tag()
    abi_tag = get_abi_tag()
    platform_tag = get_platform_tag()

    wheel_name = f"{name}-{version}-{python_tag}-{abi_tag}-{platform_tag}.whl"
    wheel_path = os.path.join(output_dir, wheel_name)

    dist_info = f"{name}-{version}.dist-info"

    # Read the .so file
    so_filename = os.path.basename(so_path)
    with open(so_path, "rb") as f:
        so_data = f.read()

    # Generate metadata files
    metadata_content = (
        f"Metadata-Version: 2.1\n"
        f"Name: {name}\n"
        f"Version: {version}\n"
        f"Summary: A Python extension built with ApplePy (Swift)\n"
        f"Requires-Python: >={sys.version_info.major}.{sys.version_info.minor}\n"
    ).encode("utf-8")

    wheel_content = (
        f"Wheel-Version: 1.0\n"
        f"Generator: applepy-pack\n"
        f"Root-Is-Purelib: false\n"
        f"Tag: {python_tag}-{abi_tag}-{platform_tag}\n"
    ).encode("utf-8")

    top_level_content = f"{name}\n".encode("utf-8")

    # Build RECORD entries
    record_entries = []

    def add_entry(path: str, data: bytes):
        record_entries.append(f"{path},{sha256_digest(data)},{len(data)}")

    add_entry(so_filename, so_data)
    add_entry(f"{dist_info}/METADATA", metadata_content)
    add_entry(f"{dist_info}/WHEEL", wheel_content)
    add_entry(f"{dist_info}/top_level.txt", top_level_content)
    # RECORD itself has no hash
    record_entries.append(f"{dist_info}/RECORD,,")

    record_content = "\n".join(record_entries).encode("utf-8")

    # Write the wheel (ZIP)
    os.makedirs(output_dir, exist_ok=True)
    with zipfile.ZipFile(wheel_path, "w", zipfile.ZIP_DEFLATED) as whl:
        whl.writestr(so_filename, so_data)
        whl.writestr(f"{dist_info}/METADATA", metadata_content)
        whl.writestr(f"{dist_info}/WHEEL", wheel_content)
        whl.writestr(f"{dist_info}/top_level.txt", top_level_content)
        whl.writestr(f"{dist_info}/RECORD", record_content)

    return wheel_path


def main():
    parser = argparse.ArgumentParser(description="Package a Swift extension as a Python wheel")
    parser.add_argument("--name", required=True, help="Package name (e.g., mylib)")
    parser.add_argument("--version", default="0.1.0", help="Package version")
    parser.add_argument("--so", required=True, help="Path to the .so file")
    parser.add_argument("--output", default="dist", help="Output directory for the wheel")
    args = parser.parse_args()

    if not os.path.exists(args.so):
        print(f"Error: .so file not found: {args.so}", file=sys.stderr)
        sys.exit(1)

    wheel_path = build_wheel(args.name, args.version, args.so, args.output)
    print(f"✅ Built wheel: {wheel_path}")
    print(f"   Install: pip install {wheel_path}")


if __name__ == "__main__":
    main()
