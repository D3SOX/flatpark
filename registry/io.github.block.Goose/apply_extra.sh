#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# goose Desktop as an electron-builder .deb — a zstd-compressed one, which the
# runtime's bsdtar reads (libarchive is built with libzstd here). It is a plain
# FHS tree with the whole app under /usr/lib/goose: the Chromium launcher, its
# .pak resources, libffmpeg/ANGLE/SwiftShader, and resources/ holding app.asar,
# the goose CLI binary and the node/npx/uvx shims the agent uses for MCP
# extensions. Unpack the data member and keep just the app directory at a
# stable path the wrapper execs: /app/extra/goose.
#
# Not staged: the .desktop file, the icon and the AppStream metainfo. Flatpak
# has to export those at *build* time, and extra-data is only fetched later on
# the user's machine, so the manifest ships its own copies.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f goose.deb ] || { echo "missing extra-data: goose.deb" >&2; exit 1; }

rm -rf stage goose
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf goose.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -d stage/usr/lib/goose ] || { echo "app directory not found in .deb: /usr/lib/goose" >&2; exit 1; }

# Which file in there is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb, whose Exec is an absolute path into the app directory:
#
#   Exec=/usr/lib/goose/Goose %U
#
# Pin refreshes are automated, so a name upstream owns must come from the
# payload rather than be written down here.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1 || true)"
[ -n "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/usr/lib/goose/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mv stage/usr/lib/goose goose
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage goose.deb
[ -x "goose/$launcher" ] || { echo "goose launcher missing after stage" >&2; exit 1; }
