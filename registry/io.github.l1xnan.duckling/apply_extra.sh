#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is one self-contained Tauri binary
# (usr/bin/duckling, with DuckDB and frontend assets embedded). Keep only that
# binary at the stable path used by the wrapper: /app/extra/duckling.
# The desktop file, icon and AppStream metainfo are installed by the manifest at
# build time because extra-data is fetched later on the user's machine.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f duckling.deb ] || {
  echo "missing extra-data: duckling.deb" >&2
  exit 1
}

# org.gnome.Platform has no ar/dpkg, but bsdtar reads the .deb ar container;
# pipe its data member into a second bsdtar for the inner archive.
rm -rf stage duckling
mkdir stage
# --no-same-owner is required because system-wide apply_extra runs as root with
# all capabilities dropped and cannot restore archive ownership.
bsdtar -xOf duckling.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/duckling ] || {
  echo "duckling binary not found in .deb" >&2
  exit 1
}

mv stage/usr/bin/duckling duckling
rm -rf stage duckling.deb
chmod +x duckling
