#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f subtitleedit.tar.gz ] || { echo "missing extra-data: subtitleedit.tar.gz" >&2; exit 1; }

rm -rf stage app
mkdir stage
tar --no-same-owner -xf subtitleedit.tar.gz -C stage
[ -x stage/SubtitleEdit ] || { echo "SubtitleEdit binary not found in tarball" >&2; exit 1; }
mv stage app
rm -f subtitleedit.tar.gz
