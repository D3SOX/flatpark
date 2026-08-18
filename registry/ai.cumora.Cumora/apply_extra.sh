#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Cumora as an electron-builder .deb: a plain FHS tree with the whole official
# Electron application under /opt/Cumora (the Chromium binary, app.asar, the
# bundled libffmpeg/ANGLE/SwiftShader libraries), plus an icon and a .desktop.
# Keep only the application tree, at the stable path the wrapper executes:
# /app/extra/cumora. The exported desktop file, icon and AppStream metainfo are
# shipped by the manifest at *build* time, because extra-data is fetched later
# on the user's machine and nothing Flatpak must export can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="cumora-amd64.deb"
[ -f "$deb" ] || {
  echo "missing extra-data: $deb" >&2
  exit 1
}

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage cumora app.env
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Locate the application tree through the Electron layout rather than through
# upstream's install path or binary name: /opt/Cumora and the executable inside
# it are both names upstream can rename between releases, and pin refreshes are
# automated, so nothing the payload owns is hardcoded here.
asar="$(find stage -type f -name app.asar -print 2>/dev/null | head -n 1)"
[ -n "$asar" ] || { echo "no app.asar in the .deb: upstream layout changed" >&2; exit 1; }
resources="$(dirname "$asar")"
[ "$(basename "$resources")" = "resources" ] || {
  echo "unexpected layout: app.asar is not in a resources/ directory ($asar)" >&2
  exit 1
}
appdir="$(dirname "$resources")"

# The Electron binary is the largest executable ELF next to resources/; the
# crashpad handler, the SUID sandbox helper and the bundled .so files are the
# other ELF candidates.
app_bin=""
app_size=0
for f in "$appdir"/*; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  case "${f##*/}" in
    *.so | *.so.* | *crashpad* | *sandbox*) continue ;;
  esac
  LC_ALL=C head -c 4 "$f" 2>/dev/null | grep -q 'ELF' || continue
  size="$(wc -c <"$f")"
  [ "$size" -gt "$app_size" ] || continue
  app_bin="$f"
  app_size="$size"
done
[ -n "$app_bin" ] || { echo "no Electron binary found in $appdir" >&2; exit 1; }
bin_name="${app_bin##*/}"

mv "$appdir" cumora
rm -rf stage "$deb"
[ -x "cumora/$bin_name" ] || {
  echo "Cumora binary missing after stage" >&2
  exit 1
}

# The wrapper reads the resolved binary name from here.
printf 'APP_BIN=%s\n' "$extra_root/cumora/$bin_name" >app.env
