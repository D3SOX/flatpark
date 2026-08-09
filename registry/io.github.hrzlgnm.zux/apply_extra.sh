#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships the
# Linux x86_64 build as a single self-contained Tauri binary
# (zux_linux_x64; the frontend assets are embedded in the binary), so there is
# nothing to unpack — extra-data has already fetched that exact file here. We
# just move it to the stable path the wrapper expects: /app/extra/zux. The
# desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f zux_linux_x64 ] || {
  echo "missing extra-data: zux_linux_x64" >&2
  exit 1
}

mv zux_linux_x64 zux
chmod +x zux
