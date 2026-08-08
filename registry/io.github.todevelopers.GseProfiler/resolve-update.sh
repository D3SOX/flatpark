#!/usr/bin/env bash
# Update resolver for GSE Profiler.
#
# Prints the current version + the installable .deb as JSON on stdout:
#   { "version": "1.2.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "gse-profiler.deb", "url": "..." } ],
#     "releaseUrl": "...", "releaseNotes": "<p>…</p>" }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# releaseUrl and releaseNotes are the optional per-app opt-in described in
# scripts/update-pins.mjs. Upstream ships its own AppStream metainfo, so its
# release notes already exist in exactly the form the registry copy wants:
# read them off the tag and hand them over untouched. Nothing here reformats
# upstream's prose, and nothing downloads the .deb to find it.
#
# Upstream publishes GitHub Releases only for stable tags (prerelease rc/beta
# tags create no Release at all), so /releases/latest is always a stable build.
set -euo pipefail

repo="todevelopers/gseprofiler"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // ""' <<<"$rel")"
# The thin arch-independent package is `gse-profiler_<ver>_all.deb`. Match it
# exactly so the source tarball and the self-hosted .flatpak bundle attached
# to the same Release are excluded.
url="$(jq -r 'first(.assets[] | select(.name | test("^gse-profiler_.*_all\\.deb$")) | .browser_download_url)' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve GSE Profiler release" >&2; exit 1; }
echo "resolved GSE Profiler $version ($date): $url" >&2

# Lift this version's <description> out of upstream's metainfo at the tag.
# Best-effort on purpose: if the file moves, the tag is missing, or the version
# has no entry, the notes are simply omitted and the release still gets its
# details link. Notes are never worth failing an update over.
notes=""
meta_url="https://raw.githubusercontent.com/$repo/$tag/data/io.github.todevelopers.GseProfiler.metainfo.xml"
if meta="$(curl -fsSL "$meta_url")"; then
    notes="$(printf '%s\n' "$meta" | awk -v v="$version" '
        index($0, "<release version=\"" v "\"") { rel = 1; next }
        rel && /<description>/  { desc = 1; next }
        rel && /<\/description>/ { exit }
        rel && /<\/release>/     { exit }
        desc { print }
    ')"
    [ -n "$notes" ] || echo "no <description> for $version in upstream metainfo" >&2
else
    echo "could not fetch upstream metainfo ($meta_url)" >&2
fi

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
      --arg ru "$release_url" --arg rn "$notes" \
  '{version:$v, releaseDate:$d, sources:[{filename:"gse-profiler.deb", url:$u}]}
   + (if $ru == "" then {} else {releaseUrl:$ru} end)
   + (if $rn == "" then {} else {releaseNotes:$rn} end)'
