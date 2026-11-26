#!/bin/sh
# Point every non-system library a binary links at @rpath, so it is found in the Geant4 folder.
#
#   use-rpath.sh <binary>...

set -eu

for f in "$@"; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    otool -L "$f" | tail -n +2 | awk '{print $1}' | while read -r dep; do
        case $dep in
            @*|/usr/lib/*|/System/*) continue ;;
            */*.framework/*) new="@rpath/${dep#*/lib/}" ;;
            *) new="@rpath/$(basename "$dep")" ;;
        esac
        install_name_tool -change "$dep" "$new" "$f"
        echo "  $(basename "$f"): $dep -> $new"
    done
done
