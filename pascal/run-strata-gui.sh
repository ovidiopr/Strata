#!/bin/sh
#=============================================================================
# Launches the Strata GUI with the environment Geant4 needs.
#
# Two things have to be in place before the window opens, and neither is
# inherited when an application is started from Finder:
#
#   * the Geant4 dataset variables (G4LEDATA and friends).  A missing dataset
#     is a fatal G4Exception, which aborts the process (GUI included) the
#     moment the physics tables are built;
#   * a path to libstrata.
#
# Usage:
#   ./run-strata-gui.sh                        # uses the defaults below
#   G4_DIR=/opt/geant4/11.4.3 ./run-strata-gui.sh
#   STRATA_BUILD=../build-release ./run-strata-gui.sh
#=============================================================================

set -e

HERE=$(cd "$(dirname "$0")" && pwd)

# Where Geant4 is installed: the directory containing bin/geant4.sh.
G4_DIR=${G4_DIR:-/usr/local/geant4/$(cat "$HERE/../GEANT4_VERSION")}

# Where CMake built libstrata.
STRATA_BUILD=${STRATA_BUILD:-$HERE/../build}

GUI=$HERE/build/StrataGUI
if [ ! -x "$GUI" ]; then
    echo "$GUI not found. Build it first:  cd $HERE && ./build.sh" >&2
    exit 1
fi

if [ -f "$G4_DIR/bin/geant4.sh" ]; then
    # Sets PATH and every G4*DATA variable for this install.
    . "$G4_DIR/bin/geant4.sh"
else
    echo "warning: $G4_DIR/bin/geant4.sh not found." >&2
    echo "         Set G4_DIR to your Geant4 11 install, or export the" >&2
    echo "         G4*DATA variables yourself before running this." >&2
fi

case "$(uname -s)" in
    Darwin) DYLD_LIBRARY_PATH="$STRATA_BUILD:$G4_DIR/lib:$DYLD_LIBRARY_PATH"
            export DYLD_LIBRARY_PATH ;;
    *)      LD_LIBRARY_PATH="$STRATA_BUILD:$G4_DIR/lib:$LD_LIBRARY_PATH"
            export LD_LIBRARY_PATH ;;
esac

# Geant4 writes its output files into the working directory, so run from a
# place where that is wanted rather than from the source tree.
WORKDIR=${STRATA_WORKDIR:-$HERE/build/run}
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "Geant4      : $G4_DIR"
echo "libstrata   : $STRATA_BUILD"
echo "output dir  : $WORKDIR"
echo

exec "$GUI" --strata-lib="$STRATA_BUILD" "$@"
