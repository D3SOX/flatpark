#!/usr/bin/env bash
# Update resolver for Vibe.
#
# Prints the latest version, release date and official Linux x86_64 .deb asset
# as JSON on stdout. Logs go to stderr; hashing and manifest updates are handled
# by FlatPark's update automation.
set -euo pipefail

repo="thewh1teagle/vibe"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Upstream also ships an arm64 .deb and .rpm/.tar.gz variants; match the x86_64
# Debian package exactly so a new artifact name cannot be picked up by accident.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == "vibe_" + $v + "_amd64.deb") | .browser_download_url' \
        <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Vibe release" >&2
  exit 1
}
echo "resolved Vibe $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"vibe.deb", url:$u}]}'
