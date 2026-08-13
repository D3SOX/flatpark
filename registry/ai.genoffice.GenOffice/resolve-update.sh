#!/usr/bin/env bash
# Update resolver for GenOffice.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "0.6.279", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "genoffice.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="genspark-ai/genoffice"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# electron-builder names the Debian package `genoffice_<version>_amd64.deb`.
# Match it exactly so the .rpm, the .AppImage (not an accepted artifact) and the
# Windows/macOS installers are all excluded.
asset="$(jq -r '.assets[] | select(.name | test("^genoffice_.*_amd64\\.deb$")) | .name' <<<"$rel" | head -n1)"
url="$(jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
# Take the version from the asset name rather than the tag: upstream tags are
# mostly `v<version>`, but at least one release was tagged `linux-v0.5.149`,
# and the filename is the one place the version always appears plainly.
version="$(sed -n 's/^genoffice_\(.*\)_amd64\.deb$/\1/p' <<<"$asset")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve genoffice release" >&2; exit 1; }
echo "resolved genoffice $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"genoffice.deb", url:$u}]}'
