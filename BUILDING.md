# Building Strata from source

Strata has two parts: the simulation (C++, CMake, Geant4) and the window
(Free Pascal, Lazarus). The window loads the simulation library at run time
and runs Geant4 in a separate process, `strata_engine`.

## Requirements

* Geant4, in the version given in `GEANT4_VERSION`, either installed from
  [geant4-installers](https://github.com/ovidiopr/geant4-installers) or built
  from source. Its Qt6 interface is needed only for the Geant4 viewer
  (`Strata -g` and **Geant4 viewer...** in the window).
* CMake 3.17 or later and a C++17 compiler.
* Free Pascal 3.2 and Lazarus 4, with four packages that do not come with
  Lazarus:

| | |
| --- | --- |
| [LazScience](https://github.com/ovidiopr/LazScience) | `components/lazscience.lpk` |
| [ExtSVGImageList](https://github.com/ovidiopr/ExtSVGImageList) | `component/extsvgimagelist.lpk` |
| [BGRAControls](https://github.com/bgrabitmap/bgracontrols) | `bgracontrols.lpk` |
| [BGRABitmap](https://github.com/bgrabitmap/bgrabitmap) | `bgrabitmap/bgrabitmappack.lpk` |

Register and compile them once, in this order:

```sh
for lpk in bgrabitmap/bgrabitmap/bgrabitmappack.lpk \
           bgracontrols/bgracontrols.lpk \
           ExtSVGImageList/component/extsvgimagelist.lpk \
           LazScience/components/lazscience.lpk; do
    lazbuild --add-package-link "$lpk"
    lazbuild "$lpk"
done
```

Install them in the Lazarus IDE too to open the form in the designer.

## The simulation

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
      -DGeant4_DIR=<geant4-prefix>/lib/cmake/Geant4
cmake --build build --parallel
```

This builds `Strata` (the batch program), `libstrata` (the library the
window loads), `strata_engine` and the tools `strata_dedx`,
`strata_rbs_check` and `strata_dpa_check`. Options:

| | |
| --- | --- |
| `-DSTRATA_BUILD_SHARED=OFF` | only the batch program |
| `-DWITH_GEANT4_UIVIS=OFF` | no Geant4 user interface or visualisation |

## The window

```sh
cd pascal
./build.sh                                     # tests and the window
LAZARUS_DIR=/Applications/Lazarus ./build.sh   # if lazbuild needs the Lazarus folder
```

`./build.sh gui` and `./build.sh tests` build one of the two. The window can
also be built from `pascal/gui/StrataGUI.lpi` in the Lazarus IDE.

The window looks for `libstrata` next to its executable first. To run it
from the build tree, point the loader at the CMake build folder:

```sh
export DYLD_LIBRARY_PATH=/path/to/strata/build   # macOS
export LD_LIBRARY_PATH=/path/to/strata/build     # Linux
```

or set **Strata Library** in the preferences.

## Tests

From the CMake build folder:

```sh
./strata_smoke 300 2
./strata_restart_check
./strata_rbs_check
./strata_dpa_check
```

From `pascal`, after `./build.sh tests`:

```sh
build/StrataLfmCheck gui
build/StrataConfigCheck
build/StrataAppCheck ../build
build/StrataMacroCheck
build/StrataCommandsCheck
build/StrataSmoke ../build/libstrata.dylib 300 2
build/StrataH1Probe ../build/libstrata.dylib 2
```

(`libstrata.so` on Linux, `strata.dll` on Windows.)

## Packages

```sh
make build_deb GEANT4_DIR=<geant4-prefix>/lib/cmake/Geant4   # Debian package
make build_dmg GEANT4_DIR=<geant4-prefix>/lib/cmake/Geant4   # macOS disk image
make nsis_cmd                                                # the makensis command for Windows
```

`VERSION` defaults to the current version. Publishing a release on GitHub
builds all of them (`.github/workflows/release.yml`) and attaches them to
the release.
