#!/usr/bin/env bash
set -euo pipefail

repo="harborstremio-linux/harbor-linux-builds"

releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/${repo}/releases?per_page=100")"

release="$(jq -c '[.[] | select(.prerelease and (.tag_name | test("^beta-v[0-9]+\\.[0-9]+\\.[0-9]+$")))] | sort_by(.published_at) | last' <<<"$releases")"
version="$(jq -r '.tag_name | ltrimstr("beta-v")' <<<"$release")"
date="$(jq -r '.published_at | split("T")[0]' <<<"$release")"
url="$(jq -r '.assets[] | select(.name == ("Harbor_" + $version + "_amd64.deb")) | .browser_download_url' --arg version "$version" <<<"$release")"

[ "$version" != "null" ] && [ -n "$url" ] || { echo "failed to resolve Harbor beta release" >&2; exit 1; }
echo "resolved Harbor Beta $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"harbor-beta.deb", url:$u}]}'
