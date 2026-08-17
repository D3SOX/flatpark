#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: the Tauri GUI at usr/bin/motrix-next, its engine
# sidecar at usr/bin/motrix-next-engine, and the application's resource tree at
# usr/lib/MotrixNext (the aria2 config, the BitTorrent peer blocklist, the
# GeoIP database and the ED2K bootstrap caches).
#
# Stage the two together at a stable path: /app/extra/motrix-next/{bin,lib}.
# Keeping bin/ and lib/ as siblings is load-bearing — Tauri resolves its resource
# directory as <exe_dir>/../lib/<ProductName>, so flattening the tree to a single
# binary silently drops every resource the engine reads at runtime.
#
# The desktop file, app icon and AppStream metainfo are shipped by the manifest
# at *build* time — extra-data is fetched later on the user's machine, so
# anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f motrix-next.deb ] || { echo "missing extra-data: motrix-next.deb" >&2; exit 1; }

rm -rf stage motrix-next
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf motrix-next.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher name out of the artifact rather than hardcoding it: pin
# refreshes are automated, and the .deb's own desktop entry is the authoritative
# answer for what upstream called the binary. Record it for the wrapper to exec.
exec_line="$(sed -n 's/^Exec=//p' stage/usr/share/applications/*.desktop | head -n1)"
launcher="${exec_line%% *}"
launcher="$(basename "$launcher")"
[ -x "stage/usr/bin/$launcher" ] || { echo "launcher not found in .deb: $launcher" >&2; exit 1; }
[ -d stage/usr/lib ] || { echo "resource tree not found in .deb" >&2; exit 1; }

mkdir -p motrix-next
mv stage/usr/bin motrix-next/bin
mv stage/usr/lib motrix-next/lib
printf '%s\n' "$launcher" > motrix-next/.launcher

rm -rf stage motrix-next.deb
