#!/bin/sh
#=============================================================================
# Builds the Free Pascal side of Strata: the binding units, the two console
# tests and the Lazarus GUI.
#
# The backend (libstrata) is built separately with CMake, see
# ../BUILDING.md.  This script does not need it to be present, because the
# library is loaded at run time, but the tests do.
#
#   ./build.sh                 build everything that is available
#   ./build.sh tests           binding units and console tests only
#   ./build.sh gui             the Lazarus application only
#
# Override the tool locations if they are not on PATH:
#   FPC=/usr/local/bin/fpc LAZARUS_DIR=/Applications/Lazarus ./build.sh
#=============================================================================

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/build"
FPC=${FPC:-fpc}
LAZBUILD=${LAZBUILD:-lazbuild}
LAZARUS_DIR=${LAZARUS_DIR:-}

TARGET=${1:-all}
mkdir -p "$OUT"

build_tests() {
    echo "== binding units and console tests =="
    "$FPC" -MObjFPC -Scghi -O2 \
        -Fu"$HERE/src" -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataSmoke.pas" > "$OUT/StrataSmoke.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataSmoke.buildlog"; exit 1; }
    echo "   $OUT/StrataSmoke"

    "$FPC" -MObjFPC -Scghi -O1 \
        -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataLfmCheck.pas" > "$OUT/StrataLfmCheck.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataLfmCheck.buildlog"; exit 1; }
    echo "   $OUT/StrataLfmCheck"

    "$FPC" -MObjFPC -Scghi -O2 \
        -Fu"$HERE/src" -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataH1Probe.pas" > "$OUT/StrataH1Probe.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataH1Probe.buildlog"; exit 1; }
    echo "   $OUT/StrataH1Probe"

    "$FPC" -MObjFPC -Scghi -O2 \
        -Fu"$HERE/src" -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataConfigCheck.pas" > "$OUT/StrataConfigCheck.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataConfigCheck.buildlog"; exit 1; }
    echo "   $OUT/StrataConfigCheck"

    "$FPC" -MObjFPC -Scghi -O2 \
        -Fu"$HERE/src" -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataAppCheck.pas" > "$OUT/StrataAppCheck.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataAppCheck.buildlog"; exit 1; }
    echo "   $OUT/StrataAppCheck"

    "$FPC" -MObjFPC -Scghi -O2 \
        -Fu"$HERE/src" -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataMacroCheck.pas" > "$OUT/StrataMacroCheck.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataMacroCheck.buildlog"; exit 1; }
    echo "   $OUT/StrataMacroCheck"

    "$FPC" -MObjFPC -Scghi -O2 \
        -Fu"$HERE/src" -FU"$OUT" -FE"$OUT" \
        "$HERE/tests/StrataCommandsCheck.pas" > "$OUT/StrataCommandsCheck.buildlog" 2>&1 \
        || { tail -20 "$OUT/StrataCommandsCheck.buildlog"; exit 1; }
    echo "   $OUT/StrataCommandsCheck"
}

build_gui() {
    echo "== Lazarus application =="
    if ! command -v "$LAZBUILD" > /dev/null 2>&1 && [ -z "$LAZARUS_DIR" ]; then
        echo "   lazbuild not found; skipping the GUI."
        echo "   Set LAZBUILD, or open pascal/gui/StrataGUI.lpi in the IDE."
        return 0
    fi

    set -- "$HERE/gui/StrataGUI.lpi"
    if [ -n "$LAZARUS_DIR" ]; then
        set -- --lazarusdir="$LAZARUS_DIR" "$@"
    fi
    if ! "$LAZBUILD" "$@" > "$OUT/StrataGUI.buildlog" 2>&1; then
        tail -20 "$OUT/StrataGUI.buildlog"
        if grep -q 'Broken dependency' "$OUT/StrataGUI.buildlog"; then
            cat <<'EOF'

The GUI depends on four Lazarus packages that are not part of Lazarus and
not vendored here.  Register each .lpk once, then build again:

    LazScience        https://github.com/ovidiopr/LazScience
                      components/lazscience.lpk       (TSciEdit, TSciRestorer)
    ExtSVGImageList   https://github.com/ovidiopr/ExtSVGImageList
                      component/extsvgimagelist.lpk   (the toolbar icons)
    BGRAControls      https://github.com/bgrabitmap/bgracontrols
                      bgracontrols.lpk                (needed by the above)
    BGRABitmap        https://github.com/bgrabitmap/bgrabitmap
                      bgrabitmap/bgrabitmappack.lpk   (needed by BGRAControls)

    lazbuild --add-package-link /path/to/<name>.lpk
    lazbuild /path/to/<name>.lpk

LazControls and LazControlDsgn come with Lazarus and need nothing.
EOF
        fi
        exit 1
    fi
    echo "   $OUT/StrataGUI"
}

case "$TARGET" in
    tests) build_tests ;;
    gui)   build_gui ;;
    all)   build_tests; build_gui ;;
    *)     echo "usage: $0 [all|tests|gui]"; exit 2 ;;
esac

echo
echo "Done. Run the static form check with:"
echo "    $OUT/StrataLfmCheck $HERE/gui"
echo "and the end-to-end binding test (needs libstrata and the Geant4 data"
echo "environment) with:"
case "$(uname -s 2>/dev/null)" in
    Darwin) LIB=libstrata.dylib ;;
    MINGW*|MSYS*|CYGWIN*) LIB=strata.dll ;;
    *)      LIB=libstrata.so ;;
esac
echo "    $OUT/StrataSmoke /path/to/$LIB 300 2"
