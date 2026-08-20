#!/usr/bin/env bash
set -euo pipefail

repo="harborstremio-linux/harbor-linux-builds"

releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/${repo}/releases?per_page=100")"

release="$(jq -c '[.[] | select(.prerelease and (.tag_name | test("^beta-v[0-9]+\\.[0-9]+\\.[0-9]+$")))] | sort_by(.published_at) | last' <<<"$releases")"
version="$(jq -r '.tag_name | ltrimstr("beta-v")' <<<"$release")"
date="$(jq -r '.published_at | split("T")[0]' <<<"$release")"
# Upstream re-cuts the .deb without changing the app version, and the rebuild
# carries a Debian revision suffix while the original name is DELETED: 0.9.115
# shipped first as "Harbor_0.9.115_amd64.deb", then as
# "Harbor_0.9.115-2_amd64.deb", and the pinned URL started 404ing mid-release.
# So match the suffix as optional, take the highest revision (an unsuffixed
# build counts as revision 0), and report the revision as part of the version.
# update-pins.mjs anchors on the version: without the suffix in it a re-cut is
# "no change" and the app stays pinned to a URL that no longer exists.
asset="$(jq -c --arg version "$version" '
  [ .assets[]
    | select(.name | test("^Harbor_" + ($version | gsub("\\."; "\\.")) + "(-[0-9]+)?_amd64\\.deb$"))
    | { rev: ((.name | capture("-(?<r>[0-9]+)_amd64\\.deb$") // {r: "0"} | .r | tonumber)),
        url: .browser_download_url } ]
  | sort_by(.rev) | last // {}' <<<"$release")"
url="$(jq -r '.url // ""' <<<"$asset")"
rev="$(jq -r '.rev // 0' <<<"$asset")"
[ "$rev" = "0" ] || version="${version}-${rev}"

[ "$version" != "null" ] && [ -n "$url" ] || { echo "failed to resolve Harbor beta release" >&2; exit 1; }
echo "resolved Harbor Beta $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"harbor-beta.deb", url:$u}]}'
