#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the Linux build as a gzip tarball whose single top-level directory is stamped
# with the version — DeepChat-<ver>-linux-x64 — holding a standard
# electron-builder tree: deepchat.bin (the Chromium launcher), a small
# deepchat launcher script beside it, resources/app.asar and
# app.asar.unpacked, locales, and the bundled ffmpeg/ANGLE/SwiftShader libs.
#
# The version-stamped name is renamed to a stable path the wrapper execs,
# /app/extra/deepchat, so an automated pin refresh to the next release does not
# have to touch the wrapper. Contents are left exactly as shipped.
#
# Not staged: the .desktop file and the icon — upstream's tarball carries
# neither, and Flatpak has to export both at *build* time while extra-data is
# only fetched later on the user's machine, so the manifest ships its own.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f deepchat.tar.gz ] || { echo "missing extra-data: deepchat.tar.gz" >&2; exit 1; }

rm -rf stage deepchat
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf deepchat.tar.gz -C stage

# Exactly one top-level directory, whose name carries the version.
top="$(cd stage && ls -1 | head -n1)"
[ -n "$top" ] && [ -d "stage/$top" ] \
    || { echo "no top-level directory in tarball" >&2; exit 1; }
[ -x "stage/$top/deepchat.bin" ] \
    || { echo "deepchat.bin not found in tarball" >&2; exit 1; }

mv "stage/$top" deepchat
rm -rf stage deepchat.tar.gz
[ -x deepchat/deepchat.bin ] || { echo "deepchat.bin missing after stage" >&2; exit 1; }
