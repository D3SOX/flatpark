#!/usr/bin/env bash
# Update resolver for Duckling.
#
# Prints the latest version, release date and official Linux x86_64 .deb asset
# as JSON on stdout. Logs go to stderr; hashing and manifest updates are handled
# by FlatPark's update automation.
set -euo pipefail

repo="l1xnan/duckling"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Duckling release" >&2
  exit 1
}
echo "resolved Duckling $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"duckling.deb", url:$u}]}'
