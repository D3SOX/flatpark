#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f harbor-beta.deb ] || { echo "missing extra-data: harbor-beta.deb" >&2; exit 1; }

rm -rf stage usr
mkdir stage
bsdtar -xOf harbor-beta.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/harbor ] || { echo "Harbor binary not found in .deb" >&2; exit 1; }
mv stage/usr usr
rm -rf stage harbor-beta.deb
