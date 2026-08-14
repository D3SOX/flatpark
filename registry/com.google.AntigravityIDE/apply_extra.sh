#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships Antigravity IDE as a tarball
# ("Antigravity IDE"). Unpack it and rename that directory to a stable path the wrapper execs.
# Everything Electron needs (Chromium, ffmpeg, app.asar) is inside; only the
# system GTK3/NSS/CUPS/X11 stack comes from the runtime.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive="$(echo Antigravity*.tar.gz)"
[ -f "$archive" ] || { echo "missing extra-data archive" >&2; exit 1; }

# org.freedesktop.Platform ships tar + gzip.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack.
tar --no-same-owner -xzf "$archive"
rm -f "$archive"

# Glob for top-level Antigravity directory rather than hardcoding payload directory.
d="$(echo Antigravity*)"
[ -d "$d" ] || { echo "Antigravity app dir not found in tarball" >&2; exit 1; }
rm -rf antigravity
mv "$d" antigravity

# The tarball records chrome-sandbox setuid. Chromium goes through zypak here, so
# that helper is never used, and a system-wide install would otherwise write a
# setuid-root binary into the deploy tree. Clear the bits explicitly rather than
# via tar --no-same-permissions, which would put every mode at the mercy of the
# umask apply_extra happens to run under.
chmod -R a-s antigravity
[ -x antigravity/antigravity-ide ] || [ -x antigravity/antigravity ] || { echo "antigravity binary not found" >&2; exit 1; }
