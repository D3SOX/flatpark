#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Whalebird as an electron-builder .deb: a plain FHS tree with the whole app
# under /opt/Whalebird (the Chromium launcher, resources/app.asar, its .pak
# resources, libffmpeg/ANGLE/SwiftShader) plus icons and a .desktop. Unpack the
# .deb's data member and keep just the app directory at a stable path the
# wrapper execs: /app/extra/whalebird. The directory keeps its contents exactly
# as shipped. The desktop file, icon and AppStream metainfo are shipped by the
# manifest at *build* time — extra-data is fetched later on the user's machine,
# so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f whalebird.deb ] || { echo "missing extra-data: whalebird.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage whalebird
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf whalebird.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -d stage/opt/Whalebird ] || { echo "app directory not found in .deb: /opt/Whalebird" >&2; exit 1; }

# Which file in there is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb, whose Exec is an absolute path into the app directory:
#
#   Exec=/opt/Whalebird/whalebird %U
#
# Pin refreshes are automated, so a rename upstream would otherwise reach users
# as a failed install (com.tldraw.Offline hit exactly that, issue #130). Taking
# the name from the payload survives the next rename.
# The .desktop file is located by glob rather than by name: it is named after the
# Debian package, which is upstream's to change just as much as the binary is.
desktop=""
for f in stage/usr/share/applications/*.desktop; do
    [ -f "$f" ] || continue
    desktop="$f"
    break
done
[ -n "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/opt/Whalebird/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mv stage/opt/Whalebird whalebird
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage whalebird.deb
[ -x "whalebird/$launcher" ] || { echo "Whalebird launcher missing after stage" >&2; exit 1; }
