#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package contains a single self-contained Tauri binary at usr/bin/authme.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# build time; extra-data is fetched later on the user's machine.

if (set -o pipefail) 2>/dev/null; then
    set -o pipefail
fi

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f authme.deb ] || { echo "missing extra-data: authme.deb" >&2; exit 1; }

rm -rf stage authme
mkdir stage
# --no-same-owner: system-wide Flatpak runs apply_extra as root with all
# capabilities dropped, so restoring archive ownership can fail with EPERM.
bsdtar -xOf authme.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/authme ] || { echo "authme binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/authme authme
rm -rf stage authme.deb
chmod +x authme
