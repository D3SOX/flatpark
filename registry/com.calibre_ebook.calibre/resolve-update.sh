#!/usr/bin/env bash
# Update resolver for calibre.
#
# Prints the current version + the official Linux binary bundles as JSON on
# stdout:
#   { "version": "9.13.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "calibre.txz", "url": "..." },
#                  { "filename": "calibre-arm64.txz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="kovidgoyal/calibre"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease tag; calibre tags every stable
# release as v<major>.<minor>.<patch>.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

# The Linux bundles are `calibre-<ver>-x86_64.txz` and `calibre-<ver>-arm64.txz`.
# Match them exactly so the source tarball (calibre-<ver>.tar.xz), the Windows
# .msi/.exe and the macOS .dmg are all excluded.
asset_url() {
  jq -r --arg re "$1" '.assets[] | select(.name | test($re)) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url '^calibre-[0-9.]+-x86_64\.txz$')"
url_arm64="$(asset_url '^calibre-[0-9.]+-arm64\.txz$')"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_arm64" ] || {
  echo "failed to resolve calibre release" >&2
  exit 1
}
echo "resolved calibre $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_arm64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"calibre.txz",       url:$ux},
     {filename:"calibre-arm64.txz", url:$ua}
   ]}'
