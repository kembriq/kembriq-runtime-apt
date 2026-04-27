#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: patch-termux-for-kembriq.sh <termux-packages-dir>" >&2
  exit 64
fi

termux_dir="$1"
props="$termux_dir/scripts/properties.sh"
repo_json="$termux_dir/repo.json"

if [ ! -f "$props" ] || [ ! -f "$repo_json" ]; then
  echo "Invalid termux-packages directory: $termux_dir" >&2
  exit 66
fi

python3 - "$props" "$repo_json" <<'PY'
import json
import sys
from pathlib import Path

props = Path(sys.argv[1])
repo_json = Path(sys.argv[2])
termux_dir = props.parent.parent

text = props.read_text(encoding="utf-8")
replacements = {
    'TERMUX__NAME="Termux"': 'TERMUX__NAME="Kembriq"',
    'TERMUX__INTERNAL_NAME="termux"': 'TERMUX__INTERNAL_NAME="kembriq"',
    'TERMUX__REPOS_HOST_ORG_NAME="termux"': 'TERMUX__REPOS_HOST_ORG_NAME="kembriq"',
    'TERMUX_APP__PACKAGE_NAME="com.termux"': 'TERMUX_APP__PACKAGE_NAME="com.kembriq.code"',
    'TERMUX_APP__NAMESPACE="com.termux"': 'TERMUX_APP__NAMESPACE="com.kembriq.code"',
    'TERMUX_APP__APP_IDENTIFIER="termux"': 'TERMUX_APP__APP_IDENTIFIER="kembriq"',
    'TERMUX_REPO_APP__PACKAGE_NAME="com.termux"': 'TERMUX_REPO_APP__PACKAGE_NAME="com.kembriq.code"',
    'TERMUX_REPO_APP__DATA_DIR="/data/data/com.termux"': 'TERMUX_REPO_APP__DATA_DIR="/data/data/com.kembriq.code"',
    'TERMUX_REPO__CORE_DIR="/data/data/com.termux/termux/core"': 'TERMUX_REPO__CORE_DIR="/data/data/com.kembriq.code/kembriq/core"',
    'TERMUX_REPO__APPS_DIR="/data/data/com.termux/termux/app"': 'TERMUX_REPO__APPS_DIR="/data/data/com.kembriq.code/kembriq/app"',
    'TERMUX_REPO__ROOTFS="/data/data/com.termux/files"': 'TERMUX_REPO__ROOTFS="/data/data/com.kembriq.code/files"',
    'TERMUX_REPO__HOME="/data/data/com.termux/files/home"': 'TERMUX_REPO__HOME="/data/data/com.kembriq.code/files/home"',
    'TERMUX_REPO__PREFIX="/data/data/com.termux/files/usr"': 'TERMUX_REPO__PREFIX="/data/data/com.kembriq.code/files/usr"',
    'CGCT_DEFAULT_PREFIX="/data/data/com.termux/files/usr/glibc"': 'CGCT_DEFAULT_PREFIX="/data/data/com.kembriq.code/files/usr/glibc"',
    'export CGCT_DIR="/data/data/com.termux/cgct"': 'export CGCT_DIR="/data/data/com.kembriq.code/cgct"',
}

missing = [needle for needle in replacements if needle not in text]
if missing:
    raise SystemExit("Missing expected properties strings:\n" + "\n".join(missing))

for needle, replacement in replacements.items():
    text = text.replace(needle, replacement)

props.write_text(text, encoding="utf-8")

repo = json.loads(repo_json.read_text(encoding="utf-8"))
repo["packages"] = {
    "name": "kembriq-main",
    "distribution": "stable",
    "component": "main",
    "url": "https://kembriq.github.io/kembriq-runtime-apt",
}
repo.pop("root-packages", None)
repo.pop("x11-packages", None)
repo_json.write_text(json.dumps(repo, indent=2) + "\n", encoding="utf-8")

# The first Kembriq bootstrap is a headless in-app runtime, not a user-facing
# Termux app. Keep Android intent bridges out of the MVP bootstrap because
# they require a Gradle/Android SDK build and are not needed for apt/python/git/node.
termux_tools = termux_dir / "packages" / "termux-tools" / "build.sh"
if not termux_tools.exists():
    raise SystemExit(f"Missing expected termux-tools build file: {termux_tools}")

tools_text = termux_tools.read_text(encoding="utf-8")
tools_text = tools_text.replace(", termux-am (>= 0.8.0), termux-am-socket (>= 1.5.0)", "")
tools_text = tools_text.replace('TERMUX_PKG_SUGGESTS="termux-api"', 'TERMUX_PKG_SUGGESTS=""')
termux_tools.write_text(tools_text, encoding="utf-8")

bootstraps = termux_dir / "scripts" / "build-bootstraps.sh"
if not bootstraps.exists():
    raise SystemExit(f"Missing expected bootstrap build script: {bootstraps}")

bootstrap_text = bootstraps.read_text(encoding="utf-8")
bootstrap_text = bootstrap_text.replace(
    '\t\tPACKAGES+=("bzip2")\n',
    '\t\tPACKAGES+=("libbz2")\n',
)
bootstrap_text = bootstrap_text.replace(
    '\t\tif ! ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then\n'
    '\t\t\tPACKAGES+=("command-not-found")\n'
    '\t\telse\n'
    '\t\t\tPACKAGES+=("proot")\n'
    '\t\tfi\n',
    '\t\tif ${BOOTSTRAP_ANDROID10_COMPATIBLE}; then\n'
    '\t\t\tPACKAGES+=("proot")\n'
    '\t\tfi\n',
)
for optional_package in ("ed", "debianutils", "dos2unix", "inetutils", "lsof", "nano", "net-tools", "patch"):
    bootstrap_text = bootstrap_text.replace(f'\t\tPACKAGES+=("{optional_package}")\n', "")
bootstraps.write_text(bootstrap_text, encoding="utf-8")

# termux-exec is part of the bootstrap and upstream includes old com.termux
# references in comments, headers and helper scripts. Keep the scanner strict
# by sanitizing those sources before packaging them as Kembriq artifacts.
termux_exec = termux_dir / "packages" / "termux-exec" / "build.sh"
if not termux_exec.exists():
    raise SystemExit(f"Missing expected termux-exec build file: {termux_exec}")

exec_text = termux_exec.read_text(encoding="utf-8")
if "kembriq_sanitize_termux_exec_sources" not in exec_text:
    exec_text += r'''

kembriq_sanitize_termux_exec_sources() {
	find "$TERMUX_PKG_SRCDIR" -type f \( \
		-name '*.h' -o \
		-name '*.c' -o \
		-name '*.cpp' -o \
		-name '*.sh' -o \
		-name '*.md' -o \
		-name '*.txt' -o \
		-name 'termux-exec-ld-preload-lib' \
	\) -print0 | xargs -0 -r sed -i -E \
		-e 's|/data/data/com\.termux|/data/data/com.kembriq.code|g' \
		-e 's|/data/user/[0-9]+/com\.termux|/data/user/0/com.kembriq.code|g' \
		-e 's|com\.termux|com.kembriq.code|g'
}

termux_step_post_get_source() {
	kembriq_sanitize_termux_exec_sources
}
'''
termux_exec.write_text(exec_text, encoding="utf-8")
PY

echo "Patched termux-packages for com.kembriq.code."
