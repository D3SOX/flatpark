#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# GenOffice as an electron-builder .deb: a plain FHS tree with the whole app
# under /opt/GenOffice (the Chromium launcher, its .pak resources,
# libffmpeg/ANGLE/SwiftShader, app.asar, the per-module renderers, the
# xlsx-engine sidecar binary and the pdfium/harfbuzz wasm blobs) plus an icon,
# a .desktop file and a shared-mime-info file. Unpack the .deb's data member
# and keep just the app directory at a stable path the wrapper execs:
# /app/extra/genoffice. The directory is moved but its contents are untouched.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f genoffice.deb ] || { echo "missing extra-data: genoffice.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage genoffice
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf genoffice.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -d stage/opt/GenOffice ] || { echo "app directory not found in .deb: /opt/GenOffice" >&2; exit 1; }

# Which file in there is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb, whose Exec is an absolute path into the app directory:
#
#   Exec=/opt/GenOffice/genoffice %U
#
# Pin refreshes are automated, so a launcher rename upstream would otherwise
# reach users as a broken install; taking the name from the payload survives it.
desktop="stage/usr/share/applications/genoffice.desktop"
[ -f "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/opt/GenOffice/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mv stage/opt/GenOffice genoffice
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher

# chrome-sandbox is the SUID helper for Chromium's own sandbox on a host
# install. Inside Flatpak the app is launched through zypak-wrapper, which
# redirects the sandbox onto the Flatpak sandbox instead, and the file can
# never be SUID here anyway. It is left in place, unmodified, exactly as
# upstream shipped it.

rm -rf stage genoffice.deb
[ -x "genoffice/$launcher" ] || { echo "genoffice launcher missing after stage" >&2; exit 1; }
[ -f genoffice/resources/app.asar ] || { echo "app.asar missing after stage" >&2; exit 1; }
