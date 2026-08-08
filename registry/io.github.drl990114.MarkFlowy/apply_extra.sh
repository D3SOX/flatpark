#!/bin/sh
set -eu

# The unpack below is a pipeline, and a plain `set -e` only sees the exit status
# of its LAST command - a first-stage failure part-way through would hand the
# second stage a truncated stream, which can still exit 0 and leave a partial
# tree. Flatpak verifies the extra-data digest before this script runs, so a
# corrupt download cannot get here, but a full disk mid-unpack can. /bin/sh is
# bash in org.gnome.Platform; the subshell probe keeps this a no-op rather than
# a hard failure on a shell without pipefail.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single self-contained Tauri
# binary (usr/bin/markflowy; the frontend assets are embedded in the binary).
# We keep only that binary at a stable path the wrapper expects:
# /app/extra/markflowy. The desktop file, icon and AppStream metainfo are
# shipped by the manifest at *build* time - extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here.

# The apply_extra sandbox has no locale configured, and bsdtar prints
# "Failed to set default locale" twice on every install without this. Harmless,
# but it is the only output a user sees from this script, so it reads like a
# packaging fault.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f markflowy.deb ] || { echo "missing extra-data: markflowy.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage markflowy
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf markflowy.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/markflowy ] || { echo "markflowy binary not found in .deb" >&2; exit 1; }

mv stage/usr/bin/markflowy markflowy
rm -rf stage markflowy.deb
chmod +x markflowy
