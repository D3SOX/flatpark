#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: the Tauri binary at usr/bin/cockpit-tools, the Go
# sidecar that backs the local Codex API service at usr/bin/cockpit-cliproxy, and
# the resource tree (auth helper script, native menu icons) at
# "usr/lib/Cockpit Tools". Tauri resolves resources as
# <exe dir>/../lib/<product name>, and it resolves a sidecar as a sibling of the
# executable, so the whole bin/ + lib/ pair has to be staged together and keep
# its relative layout — hence usr/ is moved wholesale to /app/extra/cockpit-tools
# rather than reduced to a single binary.
#
# usr/share is dropped: the desktop file, icon and AppStream metainfo are shipped
# by the manifest at *build* time, because extra-data is fetched later on the
# user's machine and anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f cockpit-tools.deb ] || { echo "missing extra-data: cockpit-tools.deb" >&2; exit 1; }

rm -rf stage cockpit-tools
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf cockpit-tools.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/cockpit-tools ] || { echo "cockpit-tools binary not found in .deb" >&2; exit 1; }
[ -d "stage/usr/lib/Cockpit Tools" ] || { echo "resource tree not found in .deb" >&2; exit 1; }

mv stage/usr cockpit-tools
rm -rf stage cockpit-tools.deb cockpit-tools/share
chmod +x cockpit-tools/bin/cockpit-tools
if [ -f cockpit-tools/bin/cockpit-cliproxy ]; then
  chmod +x cockpit-tools/bin/cockpit-cliproxy
fi
