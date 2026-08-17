#!/usr/bin/env bash
# Update resolver for Whalebird.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "6.3.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "whalebird.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="h3poteto/whalebird-desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop build is `Whalebird-<ver>-linux-amd64.deb`. Anchor the match
# so the same release's `-linux-x64.tar.bz2`, `-linux-arm64.tar.bz2`,
# `-linux-x86_64.rpm`, `-linux-x86_64.AppImage` and the macOS/Windows installers
# are all excluded. Only amd64 is packaged: upstream ships no arm64 .deb.
url="$(jq -r '.assets[] | select(.name | test("^Whalebird-[^/]*-linux-amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Whalebird release" >&2; exit 1; }
echo "resolved Whalebird $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"whalebird.deb", url:$u}]}'
