#!/usr/bin/env bash
# Update resolver for Bottles.
#
# The payload is not an upstream binary. Bottles publishes no official Linux
# binary, and the only prebuilt artifact is Flathub's OSTree, which is not a
# stable URL that extra-data can point at. So FlatPark builds the whole /app tree
# itself via CI in flatpark/bottles-release and attaches it to a release; this
# script resolves that.
#
# Prints JSON on stdout:
#   { "version": "66.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "bottles.tar.zst", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="flatpark/bottles-release"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

api=(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"})

rel="$("${api[@]}" "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^bottles-.*-x86_64\\.tar\\.zst$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve bottles-release" >&2; exit 1; }

# The shell manifest hardcodes the symlink lists for /app/lib and /app/share
# (both have to be real directories, since extensions mount inside them). If the
# payload grows a subdirectory the shell has not caught up with, users end up
# with a path that silently resolves to nothing — so compare against the
# layout.json published alongside the payload and fail the pin refresh here,
# rather than letting the problem ship.
layout_url="$(jq -r '.assets[] | select(.name == "layout.json") | .browser_download_url' <<<"$rel")"
if [ -n "$layout_url" ] && [ "$layout_url" != "null" ]; then
    layout="$("${api[@]}" "$layout_url")"
    manifest="$(dirname "$0")/com.usebottles.bottles.yml"
    for top in lib share; do
        want="$(jq -r --arg t "$top" '.[$t][]' <<<"$layout" | sort | tr '\n' ' ')"
        have="$(sed -n "s|.*for d in \(.*\); do ln -s \.\./extra/bottles/$top/.*|\1|p" \
                "$manifest" | tr ' ' '\n' | sort | tr '\n' ' ')"
        if [ "$want" != "$have" ]; then
            echo "layout drift in /app/$top: payload and shell manifest symlink lists disagree" >&2
            echo "  payload: $want" >&2
            echo "  shell:   $have" >&2
            exit 1
        fi
    done
    echo "layout.json matches the shell manifest" >&2
else
    echo "warning: release has no layout.json, skipping layout check" >&2
fi

echo "resolved Bottles $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"bottles.tar.zst", url:$u}]}'
