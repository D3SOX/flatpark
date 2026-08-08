#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships the
# x86_64 Linux build as a gzip tarball holding exactly one member: the
# `thclaws` executable. Everything the app needs is linked or embedded in that
# single binary — the GUI, the CLI REPL, the agent loop and the web frontend —
# so staging is just "unpack the one file to a stable path the wrapper execs":
# /app/extra/thclaws/thclaws.
#
# Not staged: the .desktop file and the icon. Upstream's tarball carries
# neither, and Flatpak has to export both at *build* time while extra-data is
# only fetched later on the user's machine, so the manifest ships its own.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f thclaws.tar.gz ] || { echo "missing extra-data: thclaws.tar.gz" >&2; exit 1; }

rm -rf stage thclaws
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine. This
# tarball records uid/gid 1001, so the flag is load-bearing here rather than
# merely defensive.
bsdtar --no-same-owner -xf thclaws.tar.gz -C stage

[ -f stage/thclaws ] || { echo "thclaws binary not found in tarball" >&2; exit 1; }

mkdir thclaws
mv stage/thclaws thclaws/thclaws
rm -rf stage thclaws.tar.gz

chmod +x thclaws/thclaws
[ -x thclaws/thclaws ] || { echo "thclaws binary missing after stage" >&2; exit 1; }
