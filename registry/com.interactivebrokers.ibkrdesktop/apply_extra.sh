#!/bin/sh
set -eu

# Runs offline at install time. Stages the read-only bootstrap into /app/extra:
# the install4j installer script and an extracted JRE. IBKR Desktop itself is
# installed into the writable per-app data dir on first launch (see
# ibkr-desktop-wrapper), where install4j downloads and self-updates its jars.
# /app stays read-only; the real home is never touched.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ntws-installer.sh ] || { echo "missing extra-data: ntws-installer.sh" >&2; exit 1; }
[ -f zulu-jre.tar.gz ]   || { echo "missing extra-data: zulu-jre.tar.gz" >&2; exit 1; }
[ -f krb5-gss.tar.xz ]   || { echo "missing extra-data: krb5-gss.tar.xz" >&2; exit 1; }

# GSSAPI libraries the payload's bundled Qt links against (see the manifest).
# --strip-components=1 drops the archive's single top-level directory, leaving
# lib/ at the root of krb5-gss/; the wrapper points LD_LIBRARY_PATH there.
rm -rf krb5-gss
mkdir -p krb5-gss
tar --no-same-owner --strip-components=1 -xJf krb5-gss.tar.xz -C krb5-gss
[ -e krb5-gss/lib/libgssapi_krb5.so.2 ] || { echo "krb5-gss.tar.xz has no lib/libgssapi_krb5.so.2" >&2; exit 1; }
rm -f krb5-gss.tar.xz

# Extract the JRE to a stable path the wrapper expects: /app/extra/jre.
rm -rf jre jre-stage
mkdir -p jre-stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
tar --no-same-owner -xzf zulu-jre.tar.gz -C jre-stage
jre_java="$(find jre-stage -path '*/bin/java' -type f | head -n 1)"
[ -n "$jre_java" ] || { echo "failed to find java in zulu-jre.tar.gz" >&2; exit 1; }
mv "$(dirname "$(dirname "$jre_java")")" jre
rm -rf jre-stage zulu-jre.tar.gz

chmod +x ntws-installer.sh
