#!/usr/bin/env bash
# Update resolver for the ChatGPT desktop app.
#
# OpenAI publishes the Linux build as a Debian repository; the documented
# download links (learn.chatgpt.com/docs/linux/linux-app) point at a rolling
# "latest" path, so read the versioned pool URLs out of the repo index instead.
#
# Prints the current version + the official amd64 Debian package URL:
#   { "version": "26.810.52044", "sources": [
#       { "filename": "chatgpt-amd64.deb", "url": "..." }
#   ] }
# Only x86_64 is packaged, so only binary-amd64 is read.
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq
need sort

base="https://persistent.oaistatic.com/codex-app-prod/linux/deb"

resolve_arch() {
  local arch="$1"
  local index_url="$base/dists/stable/main/binary-$arch/Packages"
  curl -fsSL "$index_url" | awk -v RS='' -v base="$base" '
    /(^|\n)Package: chatgpt(\n|$)/ {
      version = filename = ""
      n = split($0, lines, "\n")
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^Version: /) version = substr(lines[i], 10)
        else if (lines[i] ~ /^Filename: /) filename = substr(lines[i], 11)
      }
      if (version != "" && filename != "")
        printf "%s\t%s/%s\n", version, base, filename
    }' | sort -V -k1,1 | tail -n1
}

amd64="$(resolve_arch amd64)"

[ -n "$amd64" ] || {
  echo "failed to resolve the ChatGPT package" >&2
  exit 1
}

IFS=$'\t' read -r version_amd64 url_amd64 <<<"$amd64"

echo "resolved ChatGPT $version_amd64" >&2

jq -n \
  --arg v "$version_amd64" \
  --arg u_amd64 "$url_amd64" \
  '{version:$v, sources:[
    {filename:"chatgpt-amd64.deb", url:$u_amd64}
  ]}'
