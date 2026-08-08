#!/usr/bin/env bash
# Update resolver for mDNS Browser.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.15.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "mdns-browser.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# The .deb is picked out of the release's assets by name. Upstream changed its
# tag/release naming once (older tags like mdns-browser-v1.9.19 vs the current
# v1.15.0), so the URL is never assembled from the tag — it is read from the
# GitHub releases API asset whose name ends in _amd64.deb.
set -euo pipefail

repo="hrzlgnm/mdns-browser"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is `mdns-browser_<version>_amd64.deb`. Every release
# also ships a `<...>.deb.sig` sibling, so anchor the match on `.deb` at the end
# of the asset name to pick the package, never the signature.
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve mdns-browser release" >&2; exit 1; }
echo "resolved mdns-browser $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"mdns-browser.deb", url:$u}]}'
