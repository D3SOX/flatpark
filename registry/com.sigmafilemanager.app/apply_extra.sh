#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships Sigma
# File Manager as a Tauri-built .deb: a plain FHS tree whose payload is the
# single GUI binary in usr/bin, next to the hicolor icons and a .desktop file.
# Stage the binary at a stable path the wrapper execs,
# /app/extra/sigma-file-manager/bin. The desktop file, app icon and AppStream
# metainfo are shipped by the manifest at *build* time — extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come from
# here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f sigma-file-manager.deb ] || { echo "missing extra-data: sigma-file-manager.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage sigma-file-manager launcher
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf sigma-file-manager.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Which file in usr/bin is the launcher? Read the name out of the .desktop file
# shipped in the same .deb (Tauri writes `Exec=<binary>` there) instead of
# writing it down here: pin refreshes are automated, so any name upstream can
# change between releases has to come from the payload, not from this script.
desktop="$(find stage/usr/share/applications -maxdepth 1 -name '*.desktop' -print | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/usr/bin/$launcher" ] || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mkdir -p sigma-file-manager/bin
mv "stage/usr/bin/$launcher" "sigma-file-manager/bin/$launcher"
# A Tauri .deb puts sidecar binaries and bundled resources under usr/lib/<name>,
# which the application resolves relative to its own executable
# (<exe_dir>/../lib/<name>). This release ships none, but keep bin/ and lib/ as
# siblings so a release that adds one stays whole.
if [ -d "stage/usr/lib/$launcher" ]; then
    mkdir -p sigma-file-manager/lib
    mv "stage/usr/lib/$launcher" "sigma-file-manager/lib/$launcher"
fi

# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as shipped.
printf '%s\n' "$launcher" > launcher
chmod +x "sigma-file-manager/bin/$launcher"
rm -rf stage sigma-file-manager.deb
[ -x "sigma-file-manager/bin/$launcher" ] || { echo "launcher missing after stage" >&2; exit 1; }
