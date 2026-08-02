#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v ostree >/dev/null || { echo "test_drop_dangling_refs: SKIP (no ostree)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

registry="$tmp/registry"
mkdir -p "$registry/still.Listed"
touch "$registry/still.Listed/flatpark.yml"      # only the path is consulted

repo="$tmp/repo"
ostree --repo="$repo" init --mode=archive-z2
commit_branch() {   # <branch> <payload>
    local tree="$tmp/tree"
    rm -rf "$tree"; mkdir -p "$tree/files"; printf '%s\n' "$2" > "$tree/files/x"
    ostree --repo="$repo" commit --branch="$1" --subject=t "$tree" >/dev/null
}
commit_branch app/live.App/x86_64/stable live
commit_branch app/dead.App/x86_64/stable dead
commit_branch app/still.Listed/x86_64/stable listed

# Reproduce the R2 state after a de-list: the ref file is still served, but the
# commit it points at was reclaimed by a prune. still.Listed gets the same
# treatment while remaining in the registry — a half-finished object sync.
break_ref() {
    local c; c="$(ostree --repo="$repo" rev-parse "$1")"
    rm -f "$repo/objects/${c:0:2}/${c:2}.commit"
}
break_ref app/dead.App/x86_64/stable
break_ref app/still.Listed/x86_64/stable

env OUT_DIR="$tmp/out" REGISTRY_DIR="$registry" RECLAIM_REFS="$tmp/out/refs.txt" \
    "$ROOT/scripts/drop-dangling-refs.sh" "$repo" >/dev/null

refs="$tmp/refs-now.txt"
ostree --repo="$repo" refs > "$refs"
assert_contains "$refs" "app/live.App/x86_64/stable"
grep -q "dead.App" "$refs" && { echo "FAIL: dangling ref survived"; exit 1; }
grep -q "still.Listed" "$refs" && { echo "FAIL: dangling ref survived"; exit 1; }
assert_contains "$tmp/out/refs.txt" "refs/heads/app/dead.App/x86_64/stable"
grep -q "live.App" "$tmp/out/refs.txt" && { echo "FAIL: live ref queued for deletion"; exit 1; }
# Still in the registry => dropped locally, but R2 keeps its copy: the next
# build re-exports the ref, so a bad object sync costs nothing permanent.
grep -q "still.Listed" "$tmp/out/refs.txt" && { echo "FAIL: listed app queued for R2 deletion"; exit 1; }

# With the dangling ref gone, a summary regeneration succeeds again — the exact
# step that hard-failed in CI ("No such metadata object <commit>.commit").
ostree --repo="$repo" summary --update
assert_file "$repo/summary"

echo "test_drop_dangling_refs: PASS"
