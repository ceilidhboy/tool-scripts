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

1. **Shares `.env`** across worktrees — symlinks from bundle root.
2. **Symlinks `.mcp.json`** from bundle root or master copy.
3. **Shares `.serena`** across worktrees (opt-out) — by default, creates a
   shared `.serena` at the bundle root and symlinks it into each worktree,
   seeding `project.yml` with `php`/`typescript`/`bash` and adding `/.serena`
   to `.gitignore`. Pass `--no-serena` or set `share_serena=false` in
   `~/.config/gaw/config` to disable.
4. **Manages packages** — symlinks vendor/ and node_modules/ from an
   existing master/develop worktree, or performs a full install if no
   source is available.
5. **Bootstraps worktree autoload** — if the
   `ceilidhboy/laravel-worktree-autoload` package is installed, runs
   `php artisan worktree:init` to create `project_autoload.php`, which
   corrects autoloader paths when vendor is symlinked. Warns if the
   package is missing.
6. **Runs `php artisan storage:link`** if artisan exists.
7. **Generates application key** — prompts or auto-generates as needed.

### Per-user configuration

`setup-worktree` reads an optional per-user config file at
`~/.config/gaw/config` (key=value, one per line, `#` comments allowed). It is
read before CLI flags, so flags win. Supported keys:

```
share_serena=false  # disable sharing .serena at bundle root (default: share)
```

The file is optional and machine-local — team members who don't have it get
the default behaviour (no symlink).

### Assumptions

- The worktree is inside a Laravel project that uses a bare git repo
  structure (the project root contains `.bare/` and shared `.env`).
- Parent `.env` has a valid `APP_KEY` — no new key is generated (shared
  database).

## Install the scripts

```bash
cd ~/programming/tools/tool-scripts
./worktree-setup/install.sh
```

Creates symlinks in `~/.local/bin/`. Run `worktree-setup/uninstall.sh`
to remove them.
