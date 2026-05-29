#!/bin/bash
# uninstall.sh — remove symlinks for worktree-setup scripts
# Part of the tool-scripts repository.

set -euo pipefail

TOOLSET_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"

for script in "$TOOLSET_DIR"/gaw "$TOOLSET_DIR"/setup-worktree; do
    name="$(basename "$script")"
    target="$BIN_DIR/$name"

    if [ -L "$target" ]; then
        rm "$target"
        echo "  ✓ removed $name symlink"
    elif [ ! -e "$target" ]; then
        echo "  - $name not installed"
    else
        echo "  ⚠ $target is a real file — not removing"
    fi
done

echo "  → worktree-setup uninstalled"
