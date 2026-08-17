#!/usr/bin/env bash
# Update resolver for MotrixNext.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "3.9.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "motrix-next.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Stable channel only. Upstream also publishes frequent `-beta.<n>` prereleases,
# and `/releases/latest` already excludes them, so the plain endpoint is what we
# want here — unlike the Motrix 2.x package, whose stable line has not moved
# since 2023.
set -euo pipefail

repo="AnInsomniacy/motrix-next"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Match the asset by its exact name. Each release also carries the arm64 .deb,
# both .rpm builds, the AppImages, the macOS/Windows bundles and a detached .sig
# for most of them, and a loose suffix match would let sort order decide.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("MotrixNext_" + $v + "_amd64.deb")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve motrix-next release" >&2; exit 1; }
echo "resolved motrix-next $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"motrix-next.deb", url:$u}]}'
