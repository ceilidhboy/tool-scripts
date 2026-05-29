#!/bin/bash
# install.sh — install all toolsets in this repository
# Usage: ./install.sh
#
# Discovers every subdirectory with its own install.sh and runs it.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing tools from $REPO_DIR"
echo ""

for dir in "$REPO_DIR"/*/; do
    install_script="$dir/install.sh"
    if [ -f "$install_script" ]; then
        echo "→ $(basename "$dir"):"
        bash "$install_script"
        echo ""
    fi
done

echo "All toolsets installed."
echo "Make sure $HOME/.local/bin is in your PATH."
