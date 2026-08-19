#!/usr/bin/env bash
set -euo pipefail

repo="SubtitleEdit/subtitleedit"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/${repo}/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at | split("T")[0]' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name == "SubtitleEdit-Linux-x64.tar.gz") | .browser_download_url' <<<"$rel")"

[ "$version" != "null" ] && [ -n "$url" ] || { echo "failed to resolve Subtitle Edit release" >&2; exit 1; }
echo "resolved Subtitle Edit $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"subtitleedit.tar.gz", url:$u}]}'
