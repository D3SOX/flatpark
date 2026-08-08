#!/usr/bin/env bash
# Update resolver for Authme.
#
# Prints the latest release version/date and the Linux x64 .deb asset as JSON
# on stdout. Logs go to stderr. The upstream tag has no "v" prefix (for
# example, "7.1.1"), so tag_name is used directly.
set -euo pipefail

repo="Levminer/authme"
api="https://api.github.com/repos/$repo/releases/latest"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

if [ -n "${GITHUB_TOKEN:-}" ]; then
  rel="$(curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$api")"
else
  rel="$(curl -fsSL "$api")"
fi

version="$(jq -r '.tag_name // empty' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
# Select the release asset by its published name; do not construct a URL from
# the tag or filename because upstream asset names can change.
url="$(jq -r '.assets[] | select(.name | test("linux-x64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Authme Linux x64 .deb release" >&2
  exit 1
}

echo "resolved Authme $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"authme.deb", url:$u}]}'
