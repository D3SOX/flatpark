#!/usr/bin/env bash
# Update resolver for Antigravity (the agent command center, "antigravity-hub").
#
# Upstream publishes no version page, but it does publish the electron-updater
# feed the app itself checks: resources/app-update.yml sets the base URL and the
# app sets a `latest-<arch>` channel, which on Linux resolves to the file below.
# That YAML carries the version and the opaque build id, and every asset of a
# release shares one directory — so the tarball is that directory with the
# filename swapped. The feed lists only the AppImage and the .deb; we pin the
# .tar.gz that the download page links.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed="https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/latest-x64-linux.yml"
y="$(curl -fsSL "$feed")"

version="$(sed -n 's/^version:[[:space:]]*//p' <<<"$y" | head -n1)"
dir="$(grep -oE 'https://storage\.googleapis\.com/antigravity-public/antigravity-hub/[^/]+/linux-x64/' <<<"$y" | head -n1)"
[ -n "$version" ] && [ -n "$dir" ] || { echo "failed to resolve Antigravity release from $feed" >&2; exit 1; }

url="${dir}Antigravity.tar.gz"
# -f so a release that ever stops shipping the tarball fails loudly here instead
# of pinning a URL that doesn't exist.
date="$(date -u -d "$(curl -fsSI "$url" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r')" +%Y-%m-%d)"

echo "resolved Antigravity $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version: $v, releaseDate: $d, sources: [{filename: "Antigravity.tar.gz", url: $u}]}'
