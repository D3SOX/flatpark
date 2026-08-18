#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Upstream ships Vibe as
# a Tauri .deb: a plain FHS tree holding two executables in usr/bin — the Tauri
# front end and "sona", the whisper.cpp engine it runs as a sidecar — plus a
# .desktop file and icons. Vibe locates sona by looking next to its own
# executable, so the whole usr/bin directory is staged as one unit at
# /app/extra/bin and the two stay siblings; nothing inside is modified.
# The desktop file, icon and AppStream metainfo are installed by the manifest at
# build time because extra-data is fetched later on the user's machine.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f vibe.deb ] || {
  echo "missing extra-data: vibe.deb" >&2
  exit 1
}

# org.gnome.Platform has no ar/dpkg, but bsdtar reads the .deb ar container;
# pipe its data member into a second bsdtar for the inner archive.
rm -rf stage bin launcher
mkdir stage
# --no-same-owner is required because system-wide apply_extra runs as root with
# all capabilities dropped and cannot restore archive ownership.
bsdtar -xOf vibe.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Which executable is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb rather than naming it here, so that a rename upstream
# is picked up by the automated pin refresh instead of reaching users as a
# failed install.
desktop=""
for candidate in stage/usr/share/applications/*.desktop; do
  [ -f "$candidate" ] || continue
  [ -z "$desktop" ] || {
    echo "more than one .desktop file in .deb; cannot resolve the launcher" >&2
    exit 1
  }
  desktop="$candidate"
done
[ -n "$desktop" ] || {
  echo "no .desktop file in .deb to resolve the launcher from" >&2
  exit 1
}

launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || {
  echo "no Exec= line in the .deb's .desktop file" >&2
  exit 1
}
[ -x "stage/usr/bin/$launcher" ] || {
  echo "launcher from Exec= not executable in .deb: $launcher" >&2
  exit 1
}

mv stage/usr/bin bin
# The wrapper reads the resolved name from here rather than hardcoding it.
printf '%s\n' "$launcher" > launcher
rm -rf stage vibe.deb

[ -x "bin/$launcher" ] || {
  echo "vibe launcher missing after stage" >&2
  exit 1
}
