#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# tldraw offline as an electron-builder .deb: a plain FHS tree with the whole
# app under "/opt/tldraw offline" (the Chromium launcher, its .pak resources,
# libffmpeg/ANGLE/SwiftShader and the bundled SDK type stubs) plus icons, a
# .desktop and a shared-mime-info file. Unpack the .deb's data member and keep
# just the app directory at a stable, space-free path the wrapper execs:
# /app/extra/tldraw-offline. The directory is renamed but its contents are
# untouched — the launcher keeps its upstream name. The desktop file, icons,
# MIME definition and AppStream metainfo are shipped by the manifest at *build*
# time — extra-data is fetched later on the user's machine, so anything Flatpak
# must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f tldraw-offline.deb ] || { echo "missing extra-data: tldraw-offline.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage tldraw-offline
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf tldraw-offline.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -d "stage/opt/tldraw offline" ] || { echo "app directory not found in .deb: /opt/tldraw offline" >&2; exit 1; }

# Which file in there is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb, whose Exec is an absolute path into the app directory:
#
#   Exec="/opt/tldraw offline/tldraw-offline" %U
#
# Naming it here instead broke every install once: v1.11.0 shipped the launcher
# as `@tldesktop`, v1.12.0 renamed it to `tldraw-offline`, and because pin
# refreshes are automated the rename reached users as `apply_extra script
# failed, exit status 256` (issue #130). Taking the name from the payload
# survives the next rename.
desktop="stage/usr/share/applications/tldraw-offline.desktop"
[ -f "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/opt/tldraw offline/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mv "stage/opt/tldraw offline" tldraw-offline
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage tldraw-offline.deb
[ -x "tldraw-offline/$launcher" ] || { echo "tldraw offline launcher missing after stage" >&2; exit 1; }
