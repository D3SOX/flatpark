#!/usr/bin/env bash
# Update resolver for Sigma File Manager.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "2.2.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "sigma-file-manager.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="aleksey-hoffman/sigma-file-manager"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Each release carries five artifacts: the Debian package, an AppImage, a bare
# linux binary, an upstream-built .flatpak bundle and a Windows installer. Match
# the Debian package exactly — `-linux.deb` at end of name — so a future
# per-architecture or per-variant asset cannot be picked up by accident.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name | test("-" + $v + "-linux\\.deb$")) | .browser_download_url' \
        <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve sigma-file-manager release" >&2; exit 1; }
echo "resolved sigma-file-manager $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"sigma-file-manager.deb", url:$u}]}'
