#!/bin/bash
# install.sh — symlink worktree-setup scripts into ~/.local/bin/
# Part of the tool-scripts repository.
#
# Each toolset has its own install.sh so the top-level installer can
# discover and run it independently.

set -euo pipefail

TOOLSET_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR"

for script in "$TOOLSET_DIR"/gaw "$TOOLSET_DIR"/setup-worktree; do
    name="$(basename "$script")"
    target="$BIN_DIR/$name"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$script" ]; then
        echo "  ✓ $name already linked"
        continue
    fi

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "  ⚠ $target exists as a real file — skipping (delete it first)"
        continue
    fi

    chmod +x "$script"
    ln -sf "$script" "$target"
    echo "  ✓ $name → $target"
done

echo "  → worktree-setup installed"
