#!/bin/bash
# uninstall.sh — remove all toolsets installed from this repository
# Usage: ./uninstall.sh
#
# Discovers every subdirectory with its own uninstall.sh and runs it.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Uninstalling tools from $REPO_DIR"
echo ""

for dir in "$REPO_DIR"/*/; do
    uninstall_script="$dir/uninstall.sh"
    if [ -f "$uninstall_script" ]; then
        echo "→ $(basename "$dir"):"
        bash "$uninstall_script"
        echo ""
    fi
done

echo "All toolsets uninstalled."
