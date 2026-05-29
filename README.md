# tool-scripts

My collection of custom CLI tool scripts. Each subdirectory is a
self-contained toolset with its own scripts, README, install, and
uninstall.

## Toolsets

| Toolset | Description |
|---|---|
| [worktree-setup](worktree-setup/README.md) | Git worktree wrappers and Laravel worktree bootstrapping |

## Install

```bash
cd ~/programming/tools/tool-scripts
./install.sh
```

This runs each toolset's `install.sh`, which creates symlinks in
`~/.local/bin/`.

## Uninstall

```bash
./uninstall.sh
```

Removes the symlinks created by install.sh.

## Adding a new toolset

Create a new directory with the following files:

```
my-toolset/
├── my-command         # executable script
├── install.sh         # symlinks my-command → ~/.local/bin/
├── uninstall.sh       # removes the symlinks
└── README.md          # docs
```

The top-level `install.sh` and `uninstall.sh` discover and run each
toolset's scripts automatically — no configuration needed.
