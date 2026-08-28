#!/bin/sh
set -eu

# FlatPark fetches one architecture-specific portable ZIP at install time. Its
# root is the complete electron-builder application tree, so stage it at the
# stable path used by the wrapper without changing the upstream files.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=""
for candidate in opentubex-*.zip; do
    [ -f "$candidate" ] || continue
    [ -z "$archive" ] || { echo "multiple OpenTubeX archives found" >&2; exit 1; }
    archive="$candidate"
done
[ -n "$archive" ] || { echo "missing OpenTubeX extra-data archive" >&2; exit 1; }

rm -rf stage opentubex
mkdir stage
bsdtar --no-same-owner -xf "$archive" -C stage
[ -x stage/opentubex ] || { echo "OpenTubeX launcher not found in archive" >&2; exit 1; }
[ -f stage/resources/app.asar ] || { echo "OpenTubeX app.asar not found in archive" >&2; exit 1; }

mv stage opentubex
rm -f "$archive"
