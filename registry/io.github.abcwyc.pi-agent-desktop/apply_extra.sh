#!/bin/sh
set -eu

# The unpack below is a pipeline, and a plain `set -e` only sees the exit status
# of its LAST command — a first-stage failure part-way through would hand the
# second stage a truncated stream, which can still exit 0 and leave a partial
# tree. Flatpak verifies the extra-data digest before this script runs, so a
# corrupt download cannot get here, but a full disk mid-unpack can. /bin/sh is
# bash in org.gnome.Platform; the subshell probe keeps this a no-op rather than
# a hard failure on a shell without pipefail.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform.
#
# The upstream Debian package is a plain FHS tree holding the Tauri binary
# (usr/bin/pi-agent-desktop) and its resource tree under
# usr/lib/<product name>/resources: the bundled Node.js runtime, the standalone
# Next.js server and the Pi SDK the agent runs on.
#
# The relative layout is load-bearing. Tauri resolves its resource directory as
# <exe dir>/../lib/<product name>, so the whole usr tree is staged as-is at
# /app/extra/usr rather than cherry-picking the binary; flattening it would
# leave the app with no server and no Node runtime to start it with. We
# deliberately do not set APPDIR/APPIMAGE, which Tauri takes as a signal that it
# is running from an AppImage and resolves resources down a path that does not
# exist in this layout.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time: extra-data is fetched later on the user's machine, so anything
# Flatpak has to export cannot come from here.

# The apply_extra sandbox has no locale configured, and bsdtar prints
# "Failed to set default locale" twice on every install without this. Harmless,
# but it is the only output a user sees from this script, so it reads like a
# packaging fault.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="pi-agent.deb"
[ -f "$deb" ] || { echo "missing extra-data: $deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage usr
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name is read out of the .deb's own desktop entry rather than
# hardcoded, so a rename upstream cannot ship a pin nobody can install.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n 1 || true)"
[ -n "$desktop" ] || { echo "no desktop entry found in .deb" >&2; exit 1; }
exec_line="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1)"
launcher="$(basename "$(printf '%s\n' "$exec_line" | awk '{print $1}')")"

[ -n "$launcher" ] && [ -x "stage/usr/bin/$launcher" ] || {
  echo "Pi Agent binary not found in .deb: ${launcher:-<unset>}" >&2
  exit 1
}

# Guard the resource tree explicitly — the product directory name belongs to
# upstream, so find it rather than spelling it out. Losing this tree is the
# failure mode that would otherwise pass this script and only surface as an app
# that opens a window and never serves anything into it.
resources="$(ls -d stage/usr/lib/*/resources 2>/dev/null | head -n 1 || true)"
[ -n "$resources" ] || { echo "resource tree not found in .deb" >&2; exit 1; }
[ -x "$resources/node/node" ] || { echo "bundled Node runtime not found in .deb" >&2; exit 1; }
[ -f "$resources/server/server.js" ] || { echo "bundled server not found in .deb" >&2; exit 1; }

mv stage/usr usr
rm -rf stage "$deb"
chmod +x "usr/bin/$launcher"

# Record the launcher name for the wrapper, which cannot read the .deb itself.
printf '%s\n' "$launcher" > pi-agent-launcher
