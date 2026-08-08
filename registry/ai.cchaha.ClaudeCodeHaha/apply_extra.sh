#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Claude Code Haha as an electron-builder .deb: a plain FHS tree with the whole
# app under "/opt/Claude Code Haha" (the Chromium launcher, its .pak resources,
# app.asar with the bundled CLI engine and ripgrep, libffmpeg/ANGLE/SwiftShader)
# plus hicolor icons and a .desktop. Unpack the .deb's data member and keep just
# the app directory at a stable, space-free path the wrapper execs:
# /app/extra/cc-haha. The directory is renamed but its contents are untouched —
# the launcher keeps its upstream name.
#
# Not staged: the .desktop file, the icon and the AppStream metainfo. Flatpak
# has to export those at *build* time, and extra-data is only fetched later on
# the user's machine, so the manifest ships its own copies.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f cc-haha.deb ] || { echo "missing extra-data: cc-haha.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage cc-haha
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf cc-haha.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -d "stage/opt/Claude Code Haha" ] \
    || { echo "app directory not found in .deb: /opt/Claude Code Haha" >&2; exit 1; }

# Which file in there is the launcher? Read it out of the .desktop file upstream
# ships in the same .deb, whose Exec is an absolute path into the app directory:
#
#   Exec="/opt/Claude Code Haha/claude-code-desktop" %U
#
# Pin refreshes are automated, so a name upstream owns must come from the
# payload rather than be written down here.
desktop="stage/usr/share/applications/claude-code-desktop.desktop"
[ -f "$desktop" ] || { echo "no .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
launcher="${launcher##*/}"
[ -n "$launcher" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
[ -x "stage/opt/Claude Code Haha/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $launcher" >&2; exit 1; }

mv "stage/opt/Claude Code Haha" cc-haha
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage cc-haha.deb
[ -x "cc-haha/$launcher" ] || { echo "Claude Code Haha launcher missing after stage" >&2; exit 1; }
