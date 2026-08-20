#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships
# Longbridge Pro as a .deb with the application binary at /usr/local/bin.
# Flatpak-exported metadata (desktop entry, icon, AppStream) is installed by the
# manifest at build time; extra-data stages the proprietary app binary and the
# two Noto faces into /app/extra.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f longbridgepro.deb ] || { echo "missing extra-data: longbridgepro.deb" >&2; exit 1; }

# The app's whole font set. /app/share/fonts/fonts.conf — which the wrapper
# points FONTCONFIG_FILE at — declares this directory and nothing else, so a
# missing face here means a tofu UI rather than a fallback.
rm -rf fonts
mkdir fonts
for face in NotoSans-Regular.ttf NotoSansCJK-Regular.ttc; do
    [ -f "$face" ] || { echo "missing extra-data: $face" >&2; exit 1; }
    mv "$face" fonts/
done

rm -rf stage longbridge
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf longbridgepro.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/local/bin/longbridge ] || { echo "Longbridge binary not found in .deb" >&2; exit 1; }
mv stage/usr/local/bin/longbridge longbridge
rm -rf stage longbridgepro.deb
[ -x longbridge ] || { echo "Longbridge binary missing after stage" >&2; exit 1; }
