#!/usr/bin/env bash
# Update resolver for CodeBurn.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "0.9.20", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "codeburn.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="getagentseal/codeburn"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# The repo cuts three tag series from one version: `v<ver>` for the npm CLI,
# `mac-v<ver>` for the macOS menubar app and `desktop-v<ver>` for the desktop
# builds. Only the last one carries Linux assets, and /releases/latest can point
# at either of the others, so walk the release list and take the newest
# published `desktop-v` release that actually ships the amd64 .deb. Draft and
# pre-release tags are skipped: those have appeared with no assets at all.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=50" \
      | jq '[ .[]
              | select(.draft == false and .prerelease == false)
              | select(.tag_name | startswith("desktop-v"))
              | select([.assets[] | select(.name | test("_amd64\\.deb$"))] | length > 0) ]
            | sort_by(.published_at) | last')"

[ "$rel" != "null" ] || { echo "no desktop release with an amd64 .deb found" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("desktop-v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# `codeburn-desktop_<ver>_amd64.deb`. Matching the suffix exactly keeps the
# .rpm, the AppImage, the arm64 build and the macOS assets out.
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve CodeBurn release" >&2; exit 1; }
echo "resolved CodeBurn $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"codeburn.deb", url:$u}]}'
