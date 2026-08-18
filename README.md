# tool-scripts

My collection of custom CLI tool scripts. Each subdirectory is a
self-contained toolset with its own scripts, README, install, and
uninstall.

## Toolsets

| Toolset | Description                                               |
|---|-----------------------------------------------------------|
| [worktree-setup](worktree-setup/README.md) | Git worktree wrappers with copy-on-write package sharing for Laravel |

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

## Technical description

### Symlink architecture

The canonical source of truth for every script is inside this repository.
Installing does not copy files — it creates **symlinks** from
`~/.local/bin/` back into the repo:

```
~/.local/bin/gaw  ──symlink──→  ~/programming/tools/tool-scripts/worktree-setup/gaw
~/.local/bin/setup-worktree  ──→  .../worktree-setup/setup-worktree
```

This means:

- **`git pull` updates instantly** — next time you run the command, you get
the latest version. No re-install needed.
- **Edits are live immediately** — you can edit scripts inside the repo
and they take effect on the next invocation.
- **The repo remains portable** — uninstall just removes the symlinks;
the scripts stay in the repo.

### Discovery model

`install.sh` iterates each subdirectory of the repo root. Any directory
containing its own `install.sh` is treated as a toolset and gets
installed. Same for `uninstall.sh`. This means adding a new toolset is
just creating a directory with the right files — no configuration to
update.

### Per-toolset autonomy

Each toolset's `install.sh` is self-contained. It:

1. Resolves its own directory path (so it works regardless of where it's
   called from).
2. Creates `~/.local/bin/` if it doesn't exist.
3. For each executable script in the toolset, creates a symlink: `ln -sf
   <repo-path> ~/.local/bin/<script-name>`.
4. Detects pre-existing real files (not symlinks) and skips them with a
   warning — it won't overwrite a genuine file.
5. Is idempotent — re-running reports "already linked" for existing
   symlinks.

The corresponding `uninstall.sh` reverses step 3 by removing the
symlink, leaving the repo file intact.

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
