#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v ostree >/dev/null || { echo "test_prune_and_reclaim: SKIP (no ostree)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

registry="$tmp/registry"
mkdir -p "$registry/keep.App"
touch "$registry/keep.App/flatpark.yml"      # only the path is consulted

repo="$tmp/repo"
ostree --repo="$repo" init --mode=archive-z2
commit_branch() {   # <branch> <payload>
    local tree="$tmp/tree"
    rm -rf "$tree"; mkdir -p "$tree/files"; printf '%s\n' "$2" > "$tree/files/x"
    ostree --repo="$repo" commit --branch="$1" --subject=t "$tree" >/dev/null
}
# An app commit the way Flatpak writes one: /metadata next to /files, listing
# the extensions the build actually exported.
commit_app() {      # <branch> <metadata-body>
    local tree="$tmp/tree"
    rm -rf "$tree"; mkdir -p "$tree/files"; printf 'x\n' > "$tree/files/x"
    printf '%s\n' "$2" > "$tree/metadata"
    ostree --repo="$repo" commit --branch="$1" --subject=t "$tree" >/dev/null
}
commit_branch app/keep.App/x86_64/stable keep
commit_branch runtime/keep.App.Debug/x86_64/stable keep-debug
commit_branch app/gone.App/x86_64/stable gone
commit_branch runtime/gone.App.Debug/x86_64/stable gone-debug
commit_branch runtime/org.example.Platform/x86_64/50 platform

# Still in the registry, still exports its .Debug: nothing to reclaim.
mkdir -p "$registry/full.App"; touch "$registry/full.App/flatpark.yml"
commit_app app/full.App/x86_64/stable "[Application]
name=full.App

[Extension full.App.Debug]
directory=lib/debug"
commit_branch runtime/full.App.Debug/x86_64/stable full-debug

# Still in the registry, but the manifest gained no-debuginfo, so the current
# commit no longer declares the extension the previous build published.
mkdir -p "$registry/strip.App"; touch "$registry/strip.App/flatpark.yml"
commit_app app/strip.App/x86_64/stable "[Application]
name=strip.App"
commit_branch runtime/strip.App.Debug/x86_64/stable strip-debug

env OUT_DIR="$tmp/out" REGISTRY_DIR="$registry" \
    RECLAIM_LIST="$tmp/out/objects.txt" RECLAIM_REFS="$tmp/out/refs.txt" \
    "$ROOT/scripts/prune-and-reclaim.sh" "$repo" >/dev/null

refs="$tmp/refs-now.txt"
ostree --repo="$repo" refs > "$refs"

# The de-listed app loses its app ref AND the .Debug extension exported with it.
assert_contains "$refs" "app/keep.App/x86_64/stable"
assert_contains "$refs" "runtime/keep.App.Debug/x86_64/stable"
grep -q "gone.App" "$refs" && { echo "FAIL: de-listed refs survived"; exit 1; }
# A runtime that is not an app extension is never touched, registry or not.
assert_contains "$refs" "runtime/org.example.Platform/x86_64/50"

# An extension the app still declares survives; one it no longer declares does
# not, and the app itself is untouched either way.
assert_contains "$refs" "app/full.App/x86_64/stable"
assert_contains "$refs" "runtime/full.App.Debug/x86_64/stable"
assert_contains "$refs" "app/strip.App/x86_64/stable"
grep -q "runtime/strip.App.Debug" "$refs" && { echo "FAIL: orphaned extension ref survived"; exit 1; }
# keep.App's commit carries no /metadata at all, so orphanhood is unprovable and
# the extension is left alone rather than deleted on absence of evidence.
assert_contains "$refs" "runtime/keep.App.Debug/x86_64/stable"

# Both ref files are queued for deletion from R2, at their on-disk paths.
assert_contains "$tmp/out/refs.txt" "refs/heads/app/gone.App/x86_64/stable"
assert_contains "$tmp/out/refs.txt" "refs/heads/runtime/gone.App.Debug/x86_64/stable"
assert_contains "$tmp/out/refs.txt" "refs/heads/runtime/strip.App.Debug/x86_64/stable"
grep -q "full.App" "$tmp/out/refs.txt" && { echo "FAIL: live extension ref queued for deletion"; exit 1; }
grep -q "keep.App" "$tmp/out/refs.txt" && { echo "FAIL: live ref queued for deletion"; exit 1; }

# ...and the objects they pinned are queued too, without touching live ones.
assert_file "$tmp/out/objects.txt"
[ -s "$tmp/out/objects.txt" ] || { echo "FAIL: nothing reclaimed after a de-list"; exit 1; }
keep="$(ostree --repo="$repo" rev-parse app/keep.App/x86_64/stable)"
assert_file "$repo/objects/${keep:0:2}/${keep:2}.commit"

echo "test_prune_and_reclaim: PASS"
