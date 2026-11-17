#!/bin/bash
# build.sh — build a synthetic bare + worktree bundle for the test suite.
#
#   build.sh <dir> [--no-master] [--no-develop]
#
# Creates <dir>/bundle: a bare repo at .bare/, a .git pointer, an initial
# commit with composer.json/composer.lock/.gitignore, and master and/or
# develop worktrees carrying a fake vendor/ tree. No real composer install
# ever runs; the fixtures only need the shape that package sharing inspects.
set -euo pipefail

ROOT="${1:?usage: build.sh <dir> [--no-master] [--no-develop]}"
shift
NO_MASTER=false
NO_DEVELOP=false
for a in "$@"; do
    case "$a" in
        --no-master)  NO_MASTER=true ;;
        --no-develop) NO_DEVELOP=true ;;
        *) echo "build.sh: unknown option $a" >&2; exit 1 ;;
    esac
done

rm -rf "$ROOT"
mkdir -p "$ROOT"

GIT="git -c user.name=Test -c user.email=test@example.com -c init.defaultBranch=master"

# ---- seed repo with an initial commit ----
mkdir -p "$ROOT/seed"
cd "$ROOT/seed"
$GIT init -q
printf '{"name":"test/app"}\n' > composer.json
printf '{"packages":[],"content-hash":"HASH1"}\n' > composer.lock
printf 'APP_NAME=test\n' > .env.example
printf '/vendor\n/node_modules\n' > .gitignore
$GIT add -A
$GIT commit -qm "initial"

# ---- bare repo at the bundle root ----
mkdir -p "$ROOT/bundle"
git clone -q --bare . "$ROOT/bundle/.bare"
cd "$ROOT/bundle"
echo 'gitdir: .bare' > .git
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'

# develop exists in the bare repo whether or not it gets a worktree
git --git-dir=.bare branch develop master

# ---- peer worktrees, each with a "real" (non-symlinked) vendor ----
if ! $NO_MASTER; then
    git worktree add -q master master
    mkdir -p master/vendor/composer master/vendor/laravel
    printf '<?php // autoload\n' > master/vendor/autoload.php
    printf 'shared package code\n' > master/vendor/laravel/file.php
    printf '{"content-hash":"HASH1","packages":[]}\n' > master/vendor/composer/installed.json
fi

if ! $NO_DEVELOP; then
    git worktree add -q develop develop
    mkdir -p develop/vendor/composer develop/vendor/laravel
    printf '<?php // autoload\n' > develop/vendor/autoload.php
    printf 'shared package code\n' > develop/vendor/laravel/file.php
    printf '{"content-hash":"HASH1","packages":[]}\n' > develop/vendor/composer/installed.json
fi

echo "bundle built at $ROOT/bundle"
