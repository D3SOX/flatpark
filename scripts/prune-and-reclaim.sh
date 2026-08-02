#!/usr/bin/env bash
# Reclaim repo space with prune-diff targeted deletes (never a blind mirror):
#   1. delete refs for apps no longer in the registry (delist) — the app/<id>
#      ref and the runtime/<id>.{Debug,Locale,Sources} extensions exported with
#      it, and record them so their ref files can be deleted from R2 too,
#   2. prune to the current commit of every remaining ref (keep current only —
#      fix forward, no rollback retention),
#   3. write the exact set of objects pruning removed to a reclaim list.
#
# The caller then re-signs the summary (publish-repo.sh) and runs sync-r2.sh
# with RECLAIM_LIST + RECLAIM_REFS pointed at the files written here, so the new
# summary goes live BEFORE the stale refs and orphaned objects are deleted from
# R2. Deleting the ref files matters: the refs upload is additive (rclone copy),
# so a ref only removed locally comes back with the next publish's R2 reconcile
# — dangling, since its objects are gone by then. See drop-dangling-refs.sh,
# which owns (and truncates) RECLAIM_REFS; this script appends to it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need ostree
repo="${1:-$REPO_DIR}"
[ -d "$repo/objects" ] || die "not an ostree repo: $repo"
# Object stores do not preserve empty directories. A bare OSTree repository
# normally has refs/remotes/, but R2 omits it when empty; `ostree refs` then
# fails before it can list the locally published refs.
mkdir -p "$repo/refs/remotes" "$OUT_DIR"
reclaim="${RECLAIM_LIST:-$OUT_DIR/reclaim-objects.txt}"
reclaim_refs="${RECLAIM_REFS:-$OUT_DIR/reclaim-refs.txt}"

before="$(mktemp)"; after="$(mktemp)"
refs_before="$(mktemp)"; refs_after="$(mktemp)"
trap 'rm -f "$before" "$after" "$refs_before" "$refs_after"' EXIT

# 1. Delist: drop the refs of apps whose registry entry is gone
#    (ref_registry_id / ref_is_delisted live in lib/common.sh).
( cd "$repo" && find refs -type f 2>/dev/null | sort ) > "$refs_before"
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in *:*) continue ;; esac      # remote ref, not ours to touch
    ref_is_delisted "$ref" || continue
    log "delist: removing ref $ref (no registry entry for $(ref_registry_id "$ref"))"
    ostree --repo="$repo" refs --delete "$ref"
done < <(ostree --repo="$repo" refs)
( cd "$repo" && find refs -type f 2>/dev/null | sort ) > "$refs_after"

# The ref files that just disappeared => delete the same keys from R2.
comm -23 "$refs_before" "$refs_after" >> "$reclaim_refs"
refs_n="$(wc -l < "$reclaim_refs" | tr -d ' ')"
log "reclaim: $refs_n stale ref file(s) queued for deletion -> $reclaim_refs"

( cd "$repo" && find objects -type f 2>/dev/null | sort ) > "$before"

# 2. Keep only the current commit of each ref.
log "pruning to current commit (depth=0, refs-only)"
ostree --repo="$repo" prune --refs-only --depth=0 >&2

( cd "$repo" && find objects -type f 2>/dev/null | sort ) > "$after"

# 3. removed = before - after => the orphaned objects to delete from R2.
comm -23 "$before" "$after" > "$reclaim"
removed_n="$(wc -l < "$reclaim" | tr -d ' ')"
before_n="$(wc -l < "$before" | tr -d ' ')"
log "reclaim: $removed_n of $before_n object(s) pruned -> $reclaim"
printf '%s\n' "$reclaim"
