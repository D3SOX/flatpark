#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships Antigravity as a tarball
# (Antigravity-x64). Unpack it and rename that directory to a stable path the wrapper execs.
# Everything Electron needs (Chromium, ffmpeg, app.asar) is inside; only the
# system GTK3/NSS/CUPS/X11 stack comes from the runtime.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f Antigravity.tar.gz ] || { echo "missing extra-data: Antigravity.tar.gz" >&2; exit 1; }

# org.freedesktop.Platform ships tar + gzip.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack.
tar --no-same-owner -xzf Antigravity.tar.gz
# The top-level directory is arch-stamped (Antigravity-x64), so glob for it
# rather than hardcoding a name the payload owns.
d="$(echo Antigravity-*)"
[ -d "$d" ] || { echo "Antigravity app dir not found in tarball" >&2; exit 1; }
rm -rf antigravity
mv "$d" antigravity
[ -x antigravity/antigravity ] || { echo "antigravity binary not found" >&2; exit 1; }

rm -f Antigravity.tar.gz
