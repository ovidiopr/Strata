# Strata for developers

A starting point for working on the code. The headers of the files named
here say more; this page only says where things are and how they fit.

## Architecture

Strata is a Geant4 application with two front ends:

```
Strata (Geant4 UI, macros)                StrataGUI (Lazarus)
        |                                         |
        |                         uStrataEngine -> uStrataApi
        |                                         |  (loaded at run time)
        |                              libstrata: strata_client.cc
        |                                         |  two pipes
        |                         strata_engine: strata_server.cc
        |                                         |
        |                                    strata_api.cc (engine thread)
        |                                         |
        +-------------- StrataCore (src/, include/) --------------+
                                   |
                                Geant4
```

* **StrataCore** is the Geant4 application itself, compiled once as an
  object library and linked into every executable.
* **Strata** (`Strata.cc`) is the classic Geant4 executable: interactive
  session or batch macro.
* **strata_api.h** is a flat C interface (plain types, opaque handles, no
  exceptions) because Free Pascal can only call C. `strata_api.cc`
  implements it on a private engine thread, where the run manager lives.
* **strata_engine** runs `strata_api.cc` in its own process and serves it
  over two pipes (`strata_server.cc`, `strata_protocol.*`, `strata_pipe.*`).
* **libstrata** (`strata_client.cc`) exposes the same C interface to the GUI
  and forwards every call to the engine process. It links no Geant4, so a
  Geant4 crash cannot take the window down and the engine can be restarted.

## Directories

| Path | Contents |
| --- | --- |
| `src/`, `include/` | Geant4 application: geometry, physics lists, actions, messengers, histograms, damage, RBS, SRIM tables |
| `api/` | C interface, engine process and client library, C test drivers |
| `tools/` | Command-line tools built on StrataCore: stopping-power tables (`strata_dedx`), damage and RBS checks |
| `pascal/src/` | Front-end units without widgets: binding, engine wrapper, configuration, macros, command tree, datasets |
| `pascal/gui/` | Lazarus forms and frames |
| `pascal/tests/` | Console checks of the Pascal units and of the forms |
| `macros/`, `configs/` | Example macros and the equivalent `.scf` configurations |
| `doc/` | User documentation |
| `debian/`, `macos/`, `windows/`, `.github/` | Packaging and the release workflow |

`GEANT4_VERSION` names the Geant4 release Strata is built and packaged with.

## Geant4 application (StrataCore)

* `DetectorConstruction`: layered target (`/strata/geometry/`), voxels,
  fields. `MaterialBuilder`: user materials (`/strata/material/`).
* `PhysicsList`: catalogue of EM lists and hadronic components
  (`/strata/physics/addPhysics`). Strata's own lists are
  `PhysListEmStandard` (`local`), `PhysListEmStandardNR` (`standardNR`),
  `PhysListEmStandardSRIM` (`srim`), `PhysListEm19DStandard`
  (`standardATIMA`) and `PhysListEm5DStandard` (`standard5D`).
  `StrataIonMsc` sets their multiple scattering for hadrons and ions.
* `G4ScreenedNuclearRecoil` and `G4LindhardPartition`: Strata's copy of the
  screened nuclear recoil process and of its NIEL partition.
* `RunAction`, `EventAction`, `TrackingAction`, `SteppingAction`,
  `StackingAction`: scoring. `Run` and `StrataResults` hold run statistics;
  `HistoManager` defines the histograms.
* `DamageCalculator`: NRT and arc-dpa from the recoils (`/strata/damage/`).
* `RBSDetector`: RBS spectrum (`/strata/rbs/`).
* `SRIMStoppingData` and `SRIMIonisationModel`: stopping tables for `srim`.
* Each `*Messenger` holds the UI commands of its class.

## Front end (pascal/)

* `uStrataApi`: mechanical translation of `strata_api.h`; the library is
  loaded at run time so the window can report a missing backend.
* `uStrataEngine`: object wrapper; errors become exceptions and the polled
  log and progress become events, fired from a timer on the main thread.
* `uStrataConfig`: a whole set-up as plain data, read and written as `.scf`
  (XML) and as a Geant4 macro. `uStrataMacro`, `uStrataCommands`: macro
  parsing and the command tree used by the editor.
* `uStrataApp`: preferences, Geant4 location, datasets, terminal and viewer.
  `uStrataFetch`, `uStrataDatasets`: downloading Geant4 datasets.
* `uMain`: main window. Its notebook `nbMain` holds two frames, one per
  mode: `TPanelsFrame` (set-up pages, `.scf` document) and `TEditorFrame`
  (macro editor, `.mac` document).

The panels hold no state of their own: Apply turns widgets into UI commands
and the pages are refilled from what the engine reports.

## Adding a command

1. Add it to the messenger in `src/` and implement it.
2. If the panels should show it, add the field to `uStrataConfig` (XML and
   macro), the widgets to `upanelsframe.lfm/.pas`, and a case to
   `pascal/tests/StrataConfigCheck.pas`.
3. Document it in `doc/commands.md`.

The macro editor learns new commands from the engine's command tree.

## Building and testing

See [BUILDING.md](../BUILDING.md). Besides the GUI and the engine, the build
produces the checks:

* C: `strata_smoke`, `strata_restart_check` (C interface and engine process),
  `strata_dpa_check`, `strata_rbs_check`.
* Pascal (`pascal/build.sh`): `StrataLfmCheck` (every `.lfm` against its
  unit, no display needed), `StrataConfigCheck`, `StrataMacroCheck`,
  `StrataCommandsCheck`, `StrataAppCheck`, `StrataSmoke` and
  `StrataH1Probe`.

Run `StrataLfmCheck` after editing a form: an `.lfm` is only read when the
form is created, so a mismatch compiles cleanly and fails at start-up.
