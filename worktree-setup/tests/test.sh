#!/bin/bash
# test.sh — behaviour tests for the worktree tooling.
#
#   bash worktree-setup/tests/test.sh          # run, clean up, exit nonzero on failure
#   KEEP=1 bash worktree-setup/tests/test.sh   # leave fixtures in a temp dir to inspect
#
# Every test builds its own throwaway bare + worktree bundle (see build.sh)
# under a mktemp directory, so nothing touches a real project. That matters:
# these tests remove vendor/ trees and run git merges.
#
# The relink decision tests copy post-merge-relink into a private toolset
# whose setup-worktree is a stub, so they can assert on decisions without
# running a real composer install.
set -uo pipefail

SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
REPO="$(dirname "$SELF_DIR")"
BUILD="$SELF_DIR/build.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/gaw-tests.XXXXXX")"
if [ "${KEEP:-0}" = "1" ]; then
    echo "fixtures: $T (KEEP=1, not removed)"
else
    trap 'rm -rf "$T"' EXIT
fi

PASS=0; FAIL=0; FAILED=()

t() {  # t <name> <0 for pass>
    if [ "$2" -eq 0 ]; then
        PASS=$((PASS+1)); printf '  \e[32mPASS\e[0m %s\n' "$1"
    else
        FAIL=$((FAIL+1)); FAILED+=("$1"); printf '  \e[31mFAIL\e[0m %s\n' "$1"
    fi
}

section() { printf '\n=== %s ===\n' "$1"; }

# ---------------------------------------------------------------- helper
section "helper: bundle root + peer resolution"
bash "$BUILD" "$T/with-master" >/dev/null

# a directory nested two levels below the bundle root
mkdir -p "$T/with-master/bundle/deep/nested"

out=$( bash -c "source '$REPO/worktree-lib' 2>/dev/null; find_bundle_root '$T/with-master/bundle/deep/nested'" 2>/dev/null )
t "find_bundle_root walks up from a nested dir" $([ "$out" = "$T/with-master/bundle" ] && echo 0 || echo 1)

# a plain directory with no .bare ancestor anywhere on the path
mkdir -p "$T/standalone"
out=$( bash -c "source '$REPO/worktree-lib' 2>/dev/null; find_bundle_root '$T/standalone'" 2>/dev/null; echo "rc=$?" )
t "find_bundle_root fails outside any bundle" $(echo "$out" | grep -q 'rc=1' && echo 0 || echo 1)

out=$( bash -c "source '$REPO/worktree-lib' 2>/dev/null; find_peer_worktree '$T/with-master/bundle'" 2>/dev/null )
t "find_peer_worktree prefers master" $([ "$out" = "$T/with-master/bundle/master" ] && echo 0 || echo 1)

bash "$BUILD" "$T/dev-only" --no-master >/dev/null
out=$( bash -c "source '$REPO/worktree-lib' 2>/dev/null; find_peer_worktree '$T/dev-only/bundle'" 2>/dev/null )
t "find_peer_worktree falls back to develop" $([ "$out" = "$T/dev-only/bundle/develop" ] && echo 0 || echo 1)

# a symlinked vendor must not be used as a package source
bash "$BUILD" "$T/symlinked" >/dev/null
rm -rf "$T/symlinked/bundle/master/vendor"
mkdir -p "$T/symlinked/elsewhere"
printf '<?php\n' > "$T/symlinked/elsewhere/autoload.php"
ln -s ../../elsewhere "$T/symlinked/bundle/master/vendor"
out=$( bash -c "source '$REPO/worktree-lib' 2>/dev/null; find_peer_worktree '$T/symlinked/bundle'" 2>/dev/null )
t "find_peer_worktree skips a symlinked vendor (falls to develop)" \
    $([ "$out" = "$T/symlinked/bundle/develop" ] && echo 0 || echo 1)

# ---------------------------------------------------------------- relink
section "post-merge-relink decisions (private toolset, stubbed setup-worktree)"
mkdir -p "$T/tools/hooks"
cp -a "$REPO/post-merge-relink" "$REPO/worktree-lib" "$T/tools/"
cp -a "$REPO/hooks/." "$T/tools/hooks/"
cat > "$T/tools/setup-worktree" <<'STUB'
#!/bin/bash
echo "STUB setup-worktree called: $*" >> "$STUB_LOG"
exit 0
STUB
chmod +x "$T/tools/setup-worktree"
export STUB_LOG="$T/stub.log"
: > "$STUB_LOG"

mk_worktree() {  # mk_worktree <bundle> <name> <lock-content>
    git -C "$1" worktree add -q -b "$2" "$2" master 2>/dev/null || \
        git -C "$1" worktree add -q "$2" "$2" 2>/dev/null
    printf '%s\n' "$3" > "$1/$2/composer.lock"
    cp -al "$1/master/vendor" "$1/$2/vendor" 2>/dev/null || \
        cp -a "$1/develop/vendor" "$1/$2/vendor" 2>/dev/null || true
}

# develop-only bundle: relink must not demand a master worktree
bash "$BUILD" "$T/relink-dev" --no-master >/dev/null
mk_worktree "$T/relink-dev/bundle" feat/a '{"packages":[],"version":2}'
out=$( "$T/tools/post-merge-relink" "$T/relink-dev/bundle/feat/a" 2>&1 )
t "relink works on a develop-only bundle" $(echo "$out" | grep -q "master composer.lock not found" && echo 1 || echo 0)
t "relink uses develop as the peer and relinks" $(grep -q "STUB setup-worktree" "$STUB_LOG" && echo 0 || echo 1)

# out-of-bundle worktree path: clear error, no raw 'cd' failure
: > "$STUB_LOG"
mkdir -p "$T/outside"
printf '{"name":"x"}\n' > "$T/outside/composer.json"
echo 'gitdir: nowhere' > "$T/outside/.git"
out=$( "$T/tools/post-merge-relink" "$T/outside" 2>&1 )
t "relink on an out-of-bundle path gives a clear error" \
    $(echo "$out" | grep -q "Could not find a .bare" && echo 0 || echo 1)
t "relink on an out-of-bundle path emits no raw 'cd:' error" \
    $(echo "$out" | grep -q "cd: " && echo 1 || echo 0)

# asked to relink with a vendor present: does the work (the hook decides if it is needed)
bash "$BUILD" "$T/relink-same" >/dev/null
mk_worktree "$T/relink-same/bundle" feat/b '{"packages":[],"content-hash":"HASH1"}'
: > "$STUB_LOG"
out=$( "$T/tools/post-merge-relink" "$T/relink-same/bundle/feat/b" 2>&1 )
t "relink does the work when a vendor is present" $(grep -q "STUB setup-worktree" "$STUB_LOG" && echo 0 || echo 1)
t "relink removes the old vendor before relinking" $(echo "$out" | grep -q "Removed vendor/" && echo 0 || echo 1)

# no vendor at all (--no-ceremony worktree): no-op, must not create vendor
bash "$BUILD" "$T/relink-novendor" >/dev/null
mk_worktree "$T/relink-novendor/bundle" feat/c '{"packages":[],"version":3}'
rm -rf "$T/relink-novendor/bundle/feat/c/vendor"
: > "$STUB_LOG"
out=$( "$T/tools/post-merge-relink" "$T/relink-novendor/bundle/feat/c" 2>&1 )
t "relink no-ops for a worktree with no vendor/" $(echo "$out" | grep -qi "no vendor" && echo 0 || echo 1)
t "relink does not call setup-worktree for a vendorless worktree" $([ ! -s "$STUB_LOG" ] && echo 0 || echo 1)

# ---------------------------------------------------------------- setup-worktree
section "setup-worktree resolves the package source (via worktree-lib)"
bash "$BUILD" "$T/sw-master" >/dev/null
SW="$T/sw-master/bundle"
git -C "$SW" worktree add -q -b feat/z "$SW/feat/z" master
out=$( cd "$SW/feat/z" && "$REPO/setup-worktree" --dry-run --no-key --no-frontend . 2>&1 )
t "setup-worktree finds bundle root" $(echo "$out" | grep -q "Bundle root: $SW" && echo 0 || echo 1)
t "setup-worktree picks master as package source" $(echo "$out" | grep -q "Found package source: $SW/master" && echo 0 || echo 1)

bash "$BUILD" "$T/sw-dev" --no-master >/dev/null
SD="$T/sw-dev/bundle"
git -C "$SD" worktree add -q -b feat/z2 "$SD/feat/z2" develop
out=$( cd "$SD/feat/z2" && "$REPO/setup-worktree" --dry-run --no-key --no-frontend . 2>&1 )
t "setup-worktree falls back to develop (no master worktree)" $(echo "$out" | grep -q "Found package source: $SD/develop" && echo 0 || echo 1)

# ---------------------------------------------------------------- hooks
section "post-merge hook: gate on composer.lock"
bash "$BUILD" "$T/hook" >/dev/null
B="$T/hook/bundle"
mkdir -p "$B/.bare/hooks"
cp "$REPO/hooks/relink-vendor-if-lock-changed" "$B/.bare/hooks/post-merge"
chmod +x "$B/.bare/hooks/post-merge"

# absolute paths throughout: a silently failing cd would make these vacuous
git -C "$B" worktree add -q -b feat/h "$B/feat/h" master || echo "  (worktree setup failed)"
mkdir -p "$B/feat/h/vendor"
cp -al "$B/master/vendor"/. "$B/feat/h/vendor"/ 2>/dev/null || true
export PATH="$T/tools:$PATH"

# merge that does NOT touch composer.lock
cd "$B/master" || exit 1
printf 'src\n' > src.php
git add -A
git -c user.name=T -c user.email=t@e commit -qm "no lock change"
cd "$B/feat/h" || exit 1
: > "$STUB_LOG"
git -c user.name=T -c user.email=t@e merge -q master --no-edit >/dev/null 2>&1
t "hook does not relink when composer.lock is unchanged" $([ ! -s "$STUB_LOG" ] && echo 0 || echo 1)

# merge that DOES touch composer.lock
cd "$B/master" || exit 1
printf '{"packages":[],"version":9}\n' > composer.lock
git add -A
git -c user.name=T -c user.email=t@e commit -qm "lock change"
cd "$B/feat/h" || exit 1
: > "$STUB_LOG"
git -c user.name=T -c user.email=t@e merge -q master --no-edit >/dev/null 2>&1
t "hook relinks when composer.lock changed" $(grep -q "STUB setup-worktree" "$STUB_LOG" && echo 0 || echo 1)

# ---------------------------------------------------------------- gaw --init
section "gaw --init installs the hooks"
bash "$BUILD" "$T/init" >/dev/null
"$REPO/gaw" --init "$T/init/bundle" >/dev/null 2>&1
t "gaw --init creates .bare/hooks/post-merge" $([ -x "$T/init/bundle/.bare/hooks/post-merge" ] && echo 0 || echo 1)
t "gaw --init creates .bare/hooks/post-rewrite" $([ -x "$T/init/bundle/.bare/hooks/post-rewrite" ] && echo 0 || echo 1)
t "gaw --init is idempotent" $("$REPO/gaw" --init "$T/init/bundle" >/dev/null 2>&1 && echo 0 || echo 1)

# ---------------------------------------------------------------- summary
printf '\n=== %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    printf 'failed:\n'; printf '  - %s\n' "${FAILED[@]}"
    exit 1
fi
