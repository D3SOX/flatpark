#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# CodeBurn as an electron-builder .deb: a plain FHS tree with the whole app
# under /opt/CodeBurn (the Chromium launcher, its .pak resources, app.asar, the
# bundled CLI under resources/cli, libffmpeg/ANGLE/SwiftShader) plus a hicolor
# icon and a .desktop file. Unpack the .deb's data member and keep just the app
# directory at a stable path the wrapper execs: /app/extra/codeburn.
#
# Not staged: the .desktop file, the icon and the AppStream metainfo. Flatpak
# has to export those at *build* time, and extra-data is only fetched later on
# the user's machine, so the manifest ships its own copies.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f codeburn.deb ] || { echo "missing extra-data: codeburn.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage codeburn
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf codeburn.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -d stage/opt/CodeBurn ] \
    || { echo "app directory not found in .deb: /opt/CodeBurn" >&2; exit 1; }

# Which file in there is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb, whose Exec is an absolute path into the app directory:
#
#   Exec=/opt/CodeBurn/codeburn %U
#
# Pin refreshes are automated, so a name upstream owns must come from the
# payload rather than be written down here.
desktop="stage/usr/share/applications/codeburn.desktop"
[ -f "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/opt/CodeBurn/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mv stage/opt/CodeBurn codeburn
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage codeburn.deb
[ -x "codeburn/$launcher" ] || { echo "CodeBurn launcher missing after stage" >&2; exit 1; }
# The bundled CLI the app runs in Node mode has to be there too, or every
# provider would report no sessions.
[ -f codeburn/resources/cli/dist/launch.js ] \
    || { echo "bundled CLI missing after stage: resources/cli/dist/launch.js" >&2; exit 1; }
