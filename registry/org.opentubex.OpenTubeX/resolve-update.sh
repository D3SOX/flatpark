#!/usr/bin/env bash
set -euo pipefail

repo="OpenTubeX/OpenTubeX"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need gh
need jq

# GitHub's latest endpoint selects the newest beta release and ignores nightly
# prereleases. Both supported Linux architectures use the portable ZIP.
release="$(gh api "repos/$repo/releases/latest")"
tag="$(jq -r '.tag_name' <<<"$release")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$release" | cut -c1-10)"

asset_url() {
    jq -r --arg name "$1" \
        '.assets[] | select(.name == $name) | .browser_download_url' \
        <<<"$release" | head -n1
}

url_x86_64="$(asset_url "opentubex-${version}-linux-x64-portable.zip")"
url_aarch64="$(asset_url "opentubex-${version}-linux-arm64-portable.zip")"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_aarch64" ] || {
    echo "failed to resolve OpenTubeX release" >&2
    exit 1
}
echo "resolved OpenTubeX $version ($date): $url_x86_64" >&2

jq -n --arg version "$version" --arg date "$date" \
    --arg x86_64 "$url_x86_64" --arg aarch64 "$url_aarch64" \
    '{version:$version, releaseDate:$date, sources:[
       {filename:"opentubex-x86_64.zip", url:$x86_64},
       {filename:"opentubex-aarch64.zip", url:$aarch64}
     ]}'
