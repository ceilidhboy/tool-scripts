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
3. **Shares `.serena`** across worktrees (opt-in) — pass `--serena` or create
   a `.serena` at the bundle root yourself to share one project.yml + memories
   across all of the repo's worktrees; each worktree symlinks to the bundle
   copy. Seeds `project.yml` with `php`/`typescript`/`bash` and adds
   `/.serena/` to `.gitignore` (idempotent). Without `--serena` and without a
   bundle copy, worktrees keep the repo's tracked `.serena` and no symlink or
   `.gitignore` change is made — team members who don't opt in are unaffected.
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

### Assumptions

- The worktree is inside a Laravel project that uses a bare git repo
  structure (the project root contains `.bare/` and shared `.env`).
- Parent `.env` has a valid `APP_KEY` — no new key is generated (shared
  database).

## Package

This toolset includes the `ceilidhboy/laravel-worktree-autoload` Composer
package at `laravel-worktree-autoload/`. Install it into any Laravel
project to enable worktree-aware autoloading:

```bash
composer require --dev ceilidhboy/laravel-worktree-autoload
php artisan worktree:init
```

This patches the project's entry points (`public/index.php`, `artisan`,
`phpunit.xml`, `.gitignore`) and creates `project_autoload.php`. All
operations are idempotent.

## Install the scripts

```bash
cd ~/programming/tools/tool-scripts
./worktree-setup/install.sh
```

Creates symlinks in `~/.local/bin/`. Run `worktree-setup/uninstall.sh`
to remove them.
