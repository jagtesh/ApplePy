#!/usr/bin/env python3
"""applepy — Build tool for ApplePy projects.

Equivalent to maturin for PyO3. Scaffolds, builds, and publishes
Swift-powered Python extension modules.

Commands:
    applepy new <name>      Create a new project
    applepy develop         Build and install into current env
    applepy build           Build a distributable wheel
    applepy publish         Publish to PyPI
"""
import argparse
import os
import shutil
import subprocess
import sys
import sysconfig
from pathlib import Path
from textwrap import dedent

__version__ = "0.1.0"

# ── Templates ───────────────────────────────────────────────

PYPROJECT_TEMPLATE = '''\
[build-system]
requires = ["setuptools>=68.0"]
build-backend = "setuptools.build_meta"

[project]
name = "{name}"
version = "0.1.0"
description = "{description}"
readme = "README.md"
license = {{text = "BSD-3-Clause"}}
requires-python = ">=3.10"
classifiers = [
    "Development Status :: 3 - Alpha",
    "Operating System :: MacOS",
    "Programming Language :: Python :: 3",
    "Programming Language :: Swift",
]

[tool.setuptools.packages.find]
include = ["{name}*"]
'''

SETUP_PY_TEMPLATE = '''\
"""Build — compiles Swift source into a Python-loadable .so"""
import os
import subprocess
import sys
import sysconfig
from pathlib import Path

from setuptools import setup
from setuptools.command.build_ext import build_ext


class SwiftBuildExt(build_ext):
    """Custom build_ext that calls `swift build` to compile the Swift extension."""

    def run(self):
        if sys.platform != "darwin":
            raise RuntimeError("{name} only supports macOS")

        swift_dir = Path(__file__).parent / "swift"
        pkg_config_path = sysconfig.get_config_var("LIBPC") or ""

        env = os.environ.copy()
        env["PKG_CONFIG_PATH"] = pkg_config_path

        print("🔨 Building Swift extension...")
        subprocess.check_call(
            ["swift", "build"],
            cwd=swift_dir,
            env=env,
        )

        build_dir = swift_dir / ".build" / "debug"
        dylib = build_dir / "lib{swift_target}.dylib"
        if not dylib.exists():
            raise RuntimeError(f"Build succeeded but {{dylib}} not found")

        dest = Path(__file__).parent / "{name}" / "{name}.so"
        print(f"📦 Installing {{dylib.name}} → {{dest}}")
        import shutil
        shutil.copy2(dylib, dest)

    def get_ext_filename(self, ext_name):
        return ext_name + ".so"


setup(cmdclass={{"build_ext": SwiftBuildExt}})
'''

INIT_PY_TEMPLATE = '''\
"""{name} — {description}

Powered by Swift & ApplePy.
"""
import importlib
import os
import sys

if sys.platform != "darwin":
    raise ImportError("{name} only supports macOS")


def _load_native():
    """Load the compiled Swift extension module."""
    pkg_dir = os.path.dirname(os.path.abspath(__file__))
    so_path = os.path.join(pkg_dir, "{name}.so")

    if not os.path.exists(so_path):
        raise ImportError(
            "Native extension not found. Build it first:\\n"
            "  applepy develop\\n"
            "  # or: pip install -e ."
        )

    spec = importlib.util.spec_from_file_location("{name}", so_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_native = _load_native()

# Re-export all public attributes from the native module
for _attr in dir(_native):
    if not _attr.startswith("_"):
        globals()[_attr] = getattr(_native, _attr)

__version__ = "0.1.0"
'''

PACKAGE_SWIFT_TEMPLATE = '''\
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{swift_target}",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "{swift_target}", type: .dynamic, targets: ["{swift_target}"]),
    ],
    dependencies: [
        .package(path: "{applepy_path}"),
    ],
    targets: [
        .target(
            name: "{swift_target}",
            dependencies: [
                .product(name: "ApplePy", package: "ApplePy"),
                .product(name: "ApplePyClient", package: "ApplePy"),
            ]
        ),
    ]
)
'''

SWIFT_SOURCE_TEMPLATE = '''\
// {swift_target} — Powered by ApplePy
//
// Usage from Python:
//   import {name}
//   print({name}.hello("world"))

import ApplePy
@preconcurrency import ApplePyFFI

// MARK: - Functions

@PyFunction
func hello(name: String = "World") -> String {{
    return "Hello, \\(name)! 🍎"
}}

// MARK: - Module Entry Point

@PyModule("{name}", functions: [
    hello,
])
func {name}() {{}}
'''

DEMO_PY_TEMPLATE = '''\
#!/usr/bin/env python3
"""{swift_target} — Example Usage"""
import {name}

print({name}.hello("World"))
print({name}.hello("ApplePy"))
'''

README_TEMPLATE = '''\
# {swift_target}

{description}

> **macOS only** — requires Swift 6.0+ and ApplePy

## Install

```bash
applepy develop
# or: pip install -e .
```

## Usage

```python
import {name}

print({name}.hello("World"))  # Hello, World! 🍎
```

## Development

```bash
applepy develop    # Build Swift + install
applepy build      # Build wheel
applepy publish    # Publish to PyPI
```
'''

GITIGNORE_TEMPLATE = '''\
*.so
swift/.build/
*.egg-info/
dist/
build/
__pycache__/
.DS_Store
'''


# ── Commands ────────────────────────────────────────────────

def cmd_new(args):
    """Scaffold a new ApplePy project."""
    name = args.name.lower().replace("-", "_").replace(" ", "_")
    swift_target = "".join(word.capitalize() for word in name.split("_")) or name.capitalize()
    project_dir = Path(args.name)
    description = args.description or f"A Swift-powered Python package"

    if project_dir.exists():
        print(f"❌ Directory '{args.name}' already exists")
        sys.exit(1)

    print(f"🍎 Creating new ApplePy project: {name}")
    print(f"   Swift target: {swift_target}")
    print()

    # Resolve ApplePy path
    applepy_path = args.applepy_path or _find_applepy()

    # Create directory structure
    dirs = [
        project_dir,
        project_dir / name,
        project_dir / name / "examples",
        project_dir / "swift",
        project_dir / "swift" / "Sources" / swift_target,
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)

    # Compute relative path from swift/ to ApplePy
    swift_dir = project_dir / "swift"
    if applepy_path:
        try:
            rel_applepy = os.path.relpath(applepy_path, swift_dir)
        except ValueError:
            rel_applepy = str(applepy_path)
    else:
        rel_applepy = "../../ApplePy"

    # Generate files
    ctx = {
        "name": name,
        "swift_target": swift_target,
        "description": description,
        "applepy_path": rel_applepy,
    }

    files = {
        project_dir / "pyproject.toml": PYPROJECT_TEMPLATE,
        project_dir / "setup.py": SETUP_PY_TEMPLATE,
        project_dir / "README.md": README_TEMPLATE,
        project_dir / ".gitignore": GITIGNORE_TEMPLATE,
        project_dir / name / "__init__.py": INIT_PY_TEMPLATE,
        project_dir / name / "examples" / "demo.py": DEMO_PY_TEMPLATE,
        project_dir / "swift" / "Package.swift": PACKAGE_SWIFT_TEMPLATE,
        project_dir / "swift" / "Sources" / swift_target / f"{swift_target}.swift": SWIFT_SOURCE_TEMPLATE,
    }

    for filepath, template in files.items():
        content = template.format(**ctx)
        filepath.write_text(content)
        rel = filepath.relative_to(project_dir)
        print(f"  ✓ {rel}")

    # Init git
    if shutil.which("git"):
        subprocess.run(["git", "init", "-q"], cwd=project_dir)
        subprocess.run(["git", "add", "-A"], cwd=project_dir)
        subprocess.run(
            ["git", "commit", "-q", "-m", f"Initial ApplePy project: {name}"],
            cwd=project_dir,
        )
        print(f"  ✓ git initialized")

    print()
    print(f"🎉 Project created! Next steps:")
    print(f"   cd {args.name}")
    print(f"   applepy develop")
    print(f"   python {name}/examples/demo.py")


def cmd_develop(args):
    """Build Swift extension and install into current environment."""
    project_dir = Path.cwd()
    config = _load_project(project_dir)
    name = config["name"]
    swift_target = config["swift_target"]

    swift_dir = project_dir / "swift"
    if not swift_dir.exists():
        print(f"❌ No swift/ directory found. Are you in an ApplePy project?")
        sys.exit(1)

    pkg_config_path = sysconfig.get_config_var("LIBPC") or ""
    env = os.environ.copy()
    env["PKG_CONFIG_PATH"] = pkg_config_path

    # Build Swift
    print(f"🔨 Building {swift_target}...")
    try:
        subprocess.check_call(["swift", "build"], cwd=swift_dir, env=env)
    except subprocess.CalledProcessError:
        print(f"❌ Swift build failed")
        sys.exit(1)

    # Copy dylib
    dylib = swift_dir / ".build" / "debug" / f"lib{swift_target}.dylib"
    if not dylib.exists():
        print(f"❌ Expected {dylib} not found")
        sys.exit(1)

    dest = project_dir / name / f"{name}.so"
    shutil.copy2(dylib, dest)
    print(f"📦 Installed {dylib.name} → {dest.relative_to(project_dir)}")

    # pip install -e .
    print(f"📥 Installing {name} into current environment...")
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "-e", ".", "-q"],
        cwd=project_dir,
    )

    print(f"✅ Done! Try: python -c \"import {name}; print(dir({name}))\"")


def cmd_build(args):
    """Build a distributable wheel."""
    project_dir = Path.cwd()
    config = _load_project(project_dir)
    name = config["name"]
    swift_target = config["swift_target"]

    swift_dir = project_dir / "swift"
    pkg_config_path = sysconfig.get_config_var("LIBPC") or ""
    env = os.environ.copy()
    env["PKG_CONFIG_PATH"] = pkg_config_path

    # Build Swift
    print(f"🔨 Building {swift_target}...")
    try:
        subprocess.check_call(["swift", "build"], cwd=swift_dir, env=env)
    except subprocess.CalledProcessError:
        print(f"❌ Swift build failed")
        sys.exit(1)

    # Copy dylib
    dylib = swift_dir / ".build" / "debug" / f"lib{swift_target}.dylib"
    if not dylib.exists():
        print(f"❌ Expected {dylib} not found")
        sys.exit(1)

    dest = project_dir / name / f"{name}.so"
    shutil.copy2(dylib, dest)
    print(f"📦 Installed {dylib.name} → {dest.relative_to(project_dir)}")

    # Build wheel
    dist_dir = project_dir / "dist"
    dist_dir.mkdir(exist_ok=True)

    print(f"📦 Building wheel...")
    subprocess.check_call(
        [sys.executable, "-m", "pip", "wheel", ".", "-w", "dist", "-q", "--no-deps"],
        cwd=project_dir,
    )

    # List built wheels
    wheels = list(dist_dir.glob("*.whl"))
    if wheels:
        for w in wheels:
            size_kb = w.stat().st_size / 1024
            print(f"✅ Built: {w.name} ({size_kb:.0f} KB)")
    else:
        print(f"❌ No wheel found in dist/")
        sys.exit(1)


def cmd_publish(args):
    """Publish to PyPI."""
    project_dir = Path.cwd()
    config = _load_project(project_dir)
    name = config["name"]

    dist_dir = project_dir / "dist"
    wheels = list(dist_dir.glob("*.whl"))

    if not wheels:
        print(f"❌ No wheels found in dist/. Run `applepy build` first.")
        sys.exit(1)

    print(f"📤 Publishing {name} to PyPI...")
    print(f"   Wheels: {', '.join(w.name for w in wheels)}")

    if args.test:
        repo_url = "https://test.pypi.org/legacy/"
        print(f"   Repository: TestPyPI")
    else:
        repo_url = None
        print(f"   Repository: PyPI")

    if not args.yes:
        confirm = input("\n   Proceed? [y/N] ")
        if confirm.lower() not in ("y", "yes"):
            print("   Cancelled.")
            return

    cmd = [sys.executable, "-m", "twine", "upload"]
    if repo_url:
        cmd += ["--repository-url", repo_url]
    cmd += [str(w) for w in wheels]

    try:
        subprocess.check_call(cmd)
        print(f"✅ Published {name}!")
        if args.test:
            print(f"   pip install -i https://test.pypi.org/simple/ {name}")
        else:
            print(f"   pip install {name}")
    except FileNotFoundError:
        print(f"❌ twine not found. Install it: pip install twine")
        sys.exit(1)
    except subprocess.CalledProcessError:
        print(f"❌ Upload failed")
        sys.exit(1)


# ── Helpers ─────────────────────────────────────────────────

def _find_applepy():
    """Try to find the ApplePy package relative to the CLI tool."""
    # Check common locations
    cli_dir = Path(__file__).resolve().parent
    candidates = [
        cli_dir.parent.parent,                    # tools/applepy-cli -> ApplePy
        cli_dir.parent.parent.parent / "ApplePy", # sibling in workspace
        Path.cwd().parent / "ApplePy",
    ]
    for p in candidates:
        if (p / "Package.swift").exists() and (p / "Sources").exists():
            return p
    return None


def _load_project(project_dir: Path) -> dict:
    """Load project configuration from pyproject.toml."""
    pyproject = project_dir / "pyproject.toml"
    if not pyproject.exists():
        print(f"❌ No pyproject.toml found. Are you in a project directory?")
        sys.exit(1)

    # Simple TOML parser for name field (avoid dependency)
    name = None
    content = pyproject.read_text()
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("name") and "=" in line:
            val = line.split("=", 1)[1].strip().strip('"').strip("'")
            name = val
            break

    if not name:
        print(f"❌ Could not find project name in pyproject.toml")
        sys.exit(1)

    # Derive swift target from name
    swift_target = "".join(word.capitalize() for word in name.split("_")) or name.capitalize()

    # Check if swift/Package.swift has a different target name
    pkg_swift = project_dir / "swift" / "Package.swift"
    if pkg_swift.exists():
        pkg_content = pkg_swift.read_text()
        # Look for name: "..." in the Package declaration
        import re
        match = re.search(r'Package\(\s*name:\s*"([^"]+)"', pkg_content)
        if match:
            swift_target = match.group(1)

    return {"name": name, "swift_target": swift_target}


# ── Main ────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="applepy",
        description="🍎 ApplePy — Build tool for Swift-powered Python packages",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=dedent("""\
            Examples:
              applepy new myproject          Create a new project
              cd myproject && applepy develop Build and install
              applepy build                  Build a wheel
              applepy publish --test         Publish to TestPyPI
        """),
    )
    parser.add_argument("--version", action="version", version=f"applepy {__version__}")
    sub = parser.add_subparsers(dest="command", help="Command to run")

    # new
    p_new = sub.add_parser("new", help="Create a new ApplePy project")
    p_new.add_argument("name", help="Project name (e.g. myproject)")
    p_new.add_argument("-d", "--description", help="Project description")
    p_new.add_argument("--applepy-path", help="Path to ApplePy package (auto-detected)")

    # develop
    p_dev = sub.add_parser("develop", help="Build Swift and install into current env")

    # build
    p_build = sub.add_parser("build", help="Build a distributable wheel")

    # publish
    p_pub = sub.add_parser("publish", help="Publish to PyPI")
    p_pub.add_argument("--test", action="store_true", help="Publish to TestPyPI instead")
    p_pub.add_argument("-y", "--yes", action="store_true", help="Skip confirmation")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    commands = {
        "new": cmd_new,
        "develop": cmd_develop,
        "build": cmd_build,
        "publish": cmd_publish,
    }

    commands[args.command](args)


if __name__ == "__main__":
    main()
