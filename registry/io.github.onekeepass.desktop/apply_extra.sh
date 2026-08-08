#!/bin/sh
set -eu

# The unpack below is a pipeline, and a plain `set -e` only sees the exit status
# of its LAST command - a first-stage failure part-way through would hand the
# second stage a truncated stream, which can still exit 0 and leave a partial
# tree. Flatpak verifies the extra-data digest before this script runs, so a
# corrupt download cannot get here, but a full disk mid-unpack can. /bin/sh is
# bash in org.gnome.Platform; the subshell probe keeps this a no-op rather than
# a hard failure on a shell without pipefail.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform.
#
# The upstream Debian package is a plain FHS tree holding three things: the Tauri
# binary (usr/bin/OneKeePass), a native-messaging helper for browser integration
# (usr/bin/onekeepass-proxy) and a resource tree under
# usr/lib/OneKeePass/_up_/resources/public (UI translations for 10 languages,
# diceware wordlists for the password generator, custom SVG icons).
#
# The relative layout is load-bearing - the binary resolves those resources
# through ../lib/ and refers to the proxy through a relative path as well - so
# the whole usr tree is kept as-is at /app/extra/usr rather than cherry-picking
# the binary. Flattening it to a single executable would still start, but silently
# lose every translation and the password generator's wordlists.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time: extra-data is fetched later on the user's machine, so anything
# Flatpak has to export cannot come from here.

# The apply_extra sandbox has no locale configured, and bsdtar prints
# "Failed to set default locale" twice on every install without this. Harmless,
# but it is the only output a user sees from this script, so it reads like a
# packaging fault.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f onekeepass.deb ] || { echo "missing extra-data: onekeepass.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage usr
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf onekeepass.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/OneKeePass ] || {
  echo "OneKeePass binary not found in .deb" >&2
  exit 1
}
# Guard the resource tree explicitly: losing it is the failure mode that would
# otherwise pass this script and only surface as a half-broken app.
[ -f stage/usr/lib/OneKeePass/_up_/resources/public/translations/en.json ] || {
  echo "UI translations not found in .deb" >&2
  exit 1
}
[ -d stage/usr/lib/OneKeePass/_up_/resources/public/wordlists ] || {
  echo "password-generator wordlists not found in .deb" >&2
  exit 1
}

mv stage/usr usr
rm -rf stage onekeepass.deb
chmod +x usr/bin/OneKeePass
[ -e usr/bin/onekeepass-proxy ] && chmod +x usr/bin/onekeepass-proxy || true
