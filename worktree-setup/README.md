# worktree-setup

Automates Laravel worktree setup after `git worktree add`.

## Scripts

### `gaw`

Wrapper around `git worktree add`. Creates the worktree and immediately
runs `setup-worktree` from it.

```
gaw feat/new-feature              # path only — branch name matches path
gaw develop main                  # path + explicit branch
gaw --detach feat/experiment HEAD~3  # flags pass through to git
```

Arguments are forwarded verbatim to `git worktree add`. The path argument
is extracted to determine where to cd to for the setup step.

### `setup-worktree`

Standalone setup logic that can be run from any existing worktree root.

```
setup-worktree                            # auto-detect frontend
setup-worktree --dry-run                  # preview without executing
setup-worktree --bun                      # force bun install
setup-worktree --npm                      # force npm install
setup-worktree --no-frontend              # skip frontend deps
setup-worktree /path/to/worktree          # run from a specific path
```

### What it does

1. **Traverses up** from the worktree root looking for the project parent
   root (defined by the presence of `.env`). If `.env` exists in the
   worktree itself, it is skipped during traversal.
2. **Symlinks `.env`** from the parent root into the worktree. Aborts if
   `.env` already exists in the worktree (safety guard).
3. **Copies `.mcp.json`** from the parent root if the worktree doesn't
   already have one. Skips if the worktree has its own (e.g., a branch
   with custom MCP config).
4. **Runs `composer install`** if `composer.json` exists.
5. **Runs `php artisan storage:link`** if `artisan` exists.
6. **Installs frontend dependencies** — auto-detects lockfile
   (`bun.lock` → bun, `package-lock.json` → npm, `yarn.lock` → yarn,
   `pnpm-lock.yaml` → pnpm). Override with `--bun`, `--npm`, or
   `--no-frontend`.

### Assumptions

- The worktree is inside a Laravel project that uses a bare git repo
  structure (the project root contains `.bare/` and shared `.env`).
- Parent `.env` has a valid `APP_KEY` — no new key is generated (shared
  database).

## Install

```bash
cd ~/programming/tools/tool-scripts
./worktree-setup/install.sh
```

Creates symlinks in `~/.local/bin/`. Run `worktree-setup/uninstall.sh`
to remove them.
