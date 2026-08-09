#!/usr/bin/env bash
# Update resolver for zux.
#
# Prints the current version + the unbundled Linux x86_64 executable as JSON on
# stdout:
#   { "version": "1.1.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "zux_linux_x64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# The unbundled executable is picked out of the release's assets by name. The
# upstream maintainer asked that FlatPak repackage the unbundled binary rather
# than the .deb payload: it comes from the same build before the Tauri
# auto-update tags are patched in, so it never phones home for updates.
set -euo pipefail

repo="hrzlgnm/zux"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is `zux_linux_x64`, a single self-contained Tauri
# binary. The exact name is the anchor — the release also ships .deb/.rpm
# packages, .sig files and other-platform bundles, none of which we want.
url="$(jq -r '.assets[] | select(.name == "zux_linux_x64") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve zux release" >&2; exit 1; }
echo "resolved zux $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"zux_linux_x64", url:$u}]}'
