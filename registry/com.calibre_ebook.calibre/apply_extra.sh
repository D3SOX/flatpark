#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# calibre for Linux as a self-contained .txz: the launchers (calibre,
# ebook-viewer, ebook-edit, ebook-convert, calibredb, ...) sit at the top level
# next to lib/ (its own Python, Qt 6 and QtWebEngine), plugins/, resources/,
# share/ and libexec/QtWebEngineProcess. There is no top-level directory in the
# archive, so unpack it into one at a stable path the wrapper execs:
# /app/extra/calibre. The desktop files, icons, MIME definitions and AppStream
# metainfo are shipped by the manifest at *build* time — extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come from
# here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=""
for f in calibre.txz calibre-arm64.txz; do
  if [ -f "$f" ]; then archive="$f"; break; fi
done
[ -n "$archive" ] || { echo "missing extra-data: calibre.txz" >&2; exit 1; }

# The Platform runtime has no xz-aware GNU tar wrapper guarantee, but bsdtar
# (libarchive, built with liblzma here) reads the .txz directly.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
rm -rf calibre
mkdir calibre
bsdtar --no-same-owner -xf "$archive" -C calibre
rm -f "$archive"

[ -x calibre/calibre ] || { echo "calibre launcher missing after unpack" >&2; exit 1; }
[ -d calibre/resources ] || { echo "calibre resources missing after unpack" >&2; exit 1; }
