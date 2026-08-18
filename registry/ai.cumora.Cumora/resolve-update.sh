#!/usr/bin/env bash
# Update resolver for Cumora.
#
# Upstream publishes the desktop builds to the yetone/cumora-releases GitHub
# repository (the source lives at yetone/cumora). Only an amd64 Debian package
# is built for Linux, so only x86_64 is packaged here.
#
# Prints the current version + the official .deb URL as JSON on stdout:
#   { "version": "0.1.64", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cumora-amd64.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="yetone/cumora-releases"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

# releases/latest is the newest non-prerelease tag.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchor the asset name so the .AppImage, the Windows .exe and the macOS
# .dmg/.zip assets (and their .blockmap sidecars) can never be picked up.
url="$(jq -r --arg re '^cumora_[0-9][^/]*_amd64\.deb$' \
        '.assets[] | select(.name | test($re)) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve the Cumora release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "ambiguous amd64 .deb assets:" >&2; echo "$url" >&2; exit 1; }

echo "resolved Cumora $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"cumora-amd64.deb", url:$u}]}'
