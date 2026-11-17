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

### `post-merge-relink`

Re-links a worktree's hardlinked `vendor/` after a merge, pull or rebase
changes `composer.lock`.

```
post-merge-relink                 # current directory
post-merge-relink /path/to/wt     # specific worktree
```

Hardlinks bind to inodes. When the source worktree runs `composer install`
after a lock change, child worktrees' `vendor/` keeps pointing at orphaned
inodes — stale autoload maps and confusing "class not found" errors.

The script relinks whenever it is asked to. It deliberately does not try to
work out *by itself* whether a relink is needed, because there is no reliable
local record of which lock a vendor tree was installed from: composer writes
its `content-hash` into `composer.lock` only, not into
`vendor/composer/installed.json`. The tempting substitute — comparing this
worktree's lock against the source worktree's lock — is actively wrong, since
the two are identical immediately after merging the source in, which is
exactly when the hardlinks have gone stale. The caller supplies the evidence:
the hook's `git diff` check is the gate.

### Automatic relinking (git hooks)

`gaw --init` installs two hooks into `.bare/hooks/`:

- `post-merge` — after `git merge` / `git pull`
- `post-rewrite` — after `git rebase` / commit rewrites

Worktrees share the bare repo's hooks directory, so one install covers every
worktree in the bundle. Both run the same body
(`hooks/relink-vendor-if-lock-changed`), which gates on one cheap check:

```
git diff --name-only HEAD@{1} HEAD | grep -qx composer.lock
```

Only a changed `composer.lock` can invalidate `vendor/`, so any other merge
costs one `git diff` and nothing else. The hook exits silently when
`post-merge-relink` is not on `PATH` (a fresh clone on another machine).

### `worktree-lib`

Sourced, not executed. Single source of truth for the two questions shared by
`setup-worktree` and `post-merge-relink`:

- `find_bundle_root <dir>` — walks *up* looking for `.bare/`, so worktrees
  created outside the bundle (`gaw -b feat/x ../elsewhere`) still resolve.
- `find_peer_worktree <bundle>` — the worktree to hardlink packages from: the
  first of `master`, `develop` whose `vendor/` is a real directory containing
  `autoload.php`.

### `setup-worktree`

Standalone setup logic that can be run from any existing worktree root.

```
setup-worktree                            # auto-detect frontend
setup-worktree --dry-run                  # preview without executing
setup-worktree --bun                      # force bun install
setup-worktree --npm                      # force npm install
setup-worktree --no-frontend              # skip frontend deps
setup-worktree /path/to/worktree          # run from a specific path
setup-worktree --no-ceremony /path/to/wt  # packages only (no env/MCP/Serena/artisan)
```

### Review / CI worktrees

`--no-ceremony` (alias `--review`) runs the package step and nothing else. It skips the
`.env` symlink, `.mcp.json`, `.serena`, `storage:link`, `key:generate` and the TIA
`skip-worktree` bits, so a worktree created for an automated job never inherits a
developer's environment nor mutates the git index. Packages are still hard-linked from
the master worktree; the composer reconcile is skipped with a warning when `composer`
is not on `PATH`.

### What it does

1. **Shares `.env`** across worktrees — symlinks from bundle root.
2. **Symlinks `.mcp.json`** from bundle root or master copy.
3. **Shares `.serena`** across worktrees (opt-out) — by default, creates a
   shared `.serena` at the bundle root and symlinks it into each worktree,
   seeding `project.yml` with `php`/`typescript`/`bash` and adding `/.serena`
   to `.gitignore`. Pass `--no-serena` or set `share_serena=false` in
   `~/.config/gaw/config` to disable.
4. **Manages packages** — hardlink-copies `vendor/` and `node_modules/` from an
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

## Tests

Behaviour tests for `worktree-lib`, `post-merge-relink`, the git hooks and
`gaw --init`:

```bash
bash worktree-setup/tests/test.sh          # run; exit nonzero on failure
KEEP=1 bash worktree-setup/tests/test.sh   # keep the fixtures to inspect
```

Each test builds its own throwaway bare + worktree bundle under `mktemp -d`
(`tests/build.sh`), so no real project is touched — which matters, because
these tests delete `vendor/` trees and run merges. Relink decisions are
asserted against a private copy of the tooling whose `setup-worktree` is a
stub, so no real composer install runs. The fixtures use fake
`composer.lock` contents as a result.
