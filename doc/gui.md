# The Strata window

**StrataGUI** sets up and runs a simulation in two ways: with panels, one
tab per part of the set-up, or with an editor for Geant4 macros. **Macro
editor** on the toolbar switches to the editor, and the same button, then
called **Panels**, goes back.

Geant4 runs in a separate process, the *engine*, so the window stays
responsive while it works.

---

## A session

1. **Start engine**.
2. **Geometry**: the world, the layers and, optionally, test volumes for the
   dose. **Apply geometry**.
3. **Beam/Physics**: the physics list and its optional components, and,
   if needed, fields, displacement damage and the backscattering detector.
   **Apply physics**.
4. **Initialize** builds the geometry and the physics tables from what the
   pages show. Pressing the Apply buttons first is optional. The window
   stays usable meanwhile and the Log tab shows Geant4's progress; **New
   session** stops an initialisation that takes too long.
5. **Beam/Physics**: particle, energy, angle and beam size. **Apply beam**.
   For a heavy ion choose `ion` and fill Z, A and charge (-1 for a bare
   nucleus).
6. **Histograms**: pick a spectrum, set bins, range and unit, and press
   **Activate / update**. All histograms are off until switched on here.
7. Set the number of events and press **Beam on**. **Abort** stops the run
   at the end of the current event; the results are those of the events
   that ran.
8. **Results** shows the summary at the end of the run; the Histograms tab
   draws the spectra while they fill.

The leftmost panel of the status bar says which stage the session is in
and what comes next:

| | |
| --- | --- |
| `Backend not loaded` | the Strata library was not found |
| `Engine stopped` | everything can be set; next, Start engine |
| `Engine started` | geometry and physics still open; next, Initialize |
| `Kernel built` | geometry and physics fixed; set the beam, then Beam on |
| `Running` | only Abort is available |
| `Stopping after the current event` | an abort is in progress |

### What can still be changed after Initialize

Geant4 fixes part of the set-up when the kernel is built, and the window
disables what can no longer be changed.

| | after Initialize |
| --- | --- |
| Beam particle, energy, size | only after Initialize |
| Layer and world materials | yes |
| Defining new materials | yes |
| Spectra: bins, range, unit, on/off | yes |
| Displacement damage and its constants | yes |
| Output folder and file name | yes |
| Random seeds | yes |
| Layer count, thicknesses, transverse size | needs a new session |
| Test volumes | needs a new session |
| Physics list | needs a new session |
| Random generator | needs a new session |

**New session** closes the engine and keeps everything on the pages; the
next **Start engine** opens a new one. **New configuration**, **Open...**
and **Import settings from macro...** start a new session too.

---

## The pages

### Geometry

**Layers** lists the layers in the order the beam meets them. Thickness and
density are a value and a unit in one cell (`20 um`, `2.32 g/cm3`). An empty
density means the material's own.

The material cell has a button that opens the material catalogue, grouped
as Geant4 groups it (elements, NIST compounds, HEP and nuclear, space,
bio-chemical), plus the materials defined in this session, with a search
box. Picking one shows its elements, their shares of the mass and of the
atoms, the density and the number of atoms per cubic centimetre.

**Test volumes for the dose** are boxes inside the target in which the dose
is scored. Each one is given its three sides and the position of its centre
in the frame of the target (the beam enters at -X/2), and has to lie inside
a single layer, whose material it takes. The deposited energy, its fraction
of the beam energy and the dose in gray appear on the Results tab.

### Beam/Physics

* **Primary generator**: particle, energy, beam size and angle of
  incidence, and Z, A and charge for an ion.
* The physics list, and **Optional components**.
* **Magnetic field** and **Electric field**.
* **Displacement damage**: **Count displacements** switches on histograms 4
  to 6. The table has one row per material in the layers, with the
  displacement threshold energy Ed, in any energy unit (eV when none is
  typed), and the two arc-dpa constants.
  The rows for materials Strata knows come filled in; edit a cell to change
  it, and give Ed for the others. Leave b and c empty for no arc-dpa
  correction.
* **Backscattering detector**: histogram 80, with the scattering angle,
  solid angle, resolution and target tilt.

See [commands.md](commands.md) for what each setting means.

### Materials

**Define a material**: a name and a density, the composition by mass
fraction or by number of atoms, one constituent per row, and **Create
material**. The name cell opens the periodic table for an element and the
catalogue for a material. The running total shows whether the mass
fractions add up. A new material appears at once wherever a material can be
chosen.

Materials defined this way are shown in green in **Materials currently
defined**. Double-click one to edit its recipe and press **Create material**
again to replace it; a running engine keeps the material it already built
until the next session.

### Histograms

The list shows every spectrum, or only the active ones. The chart is
redrawn several times a second during a run. **Export CSV** writes the
spectrum shown, and **Export all** writes every active one, asking for each
file in turn. The suggested name is `<name>_h1_<id>.csv`, where `<name>` is
the output name, or the configuration's name when the output name is empty
or still `strata`. The macro editor's **Histograms** tab does the same, with
the macro's `/analysis/setFileName` and the macro's name.

A spectrum that is switched on can still be drawn flat: either the quantity
is zero for the physics chosen, or every value fell outside the range and
went to the underflow and overflow bins. The status line says which. See
*Histograms* in [commands.md](commands.md) for what each spectrum needs.

### Options

* **Random numbers**: by default every run gets new seeds. Clearing **New
  seeds for every run** fixes them. **Take the seeds of the last run** puts
  the seeds of the last run in the boxes, so the next run repeats it. A run
  repeats exactly on one thread; on several the last digits can change.
* **Output**: the folder and file name for results, and the track output
  files (every step of every track, as text; about 10 kB per event, so for a
  few events only). With the track files on, the run uses one thread.
* **Atomic de-excitation**: fluorescence, Auger electrons, Auger cascade and
  PIXE.
* **Production cuts** and **Tracking** (maximum step length).
* Four boxes for extra Geant4 commands, sent at fixed points of the set-up:
  after the geometry, before initialisation, after initialisation and just
  before the run.

### Results and Log

**Results** shows the summary of the last run and the test volumes.

**Log** shows what Geant4 prints. Its command box takes anything that can go
in a macro, and **Run macro...** sends a macro file to the engine as it is.

---

## Files

| | |
| --- | --- |
| **Open...** | a configuration (`.scf`) for the panels, or a macro (`.mac`) for the editor |
| **Save configuration** | the panels as a configuration file (`.scf`) |
| **Export settings as macro...** | the panels as a Geant4 macro |
| **Import settings from macro...** | a Geant4 macro into the panels |

A configuration holds the threads, geometry, materials, beam, physics,
active spectra, seeds and output settings. An exported macro is a complete
set-up that also runs with the batch program:

```sh
Strata strata-setup.mac
```

Commands in an imported macro that have no place in the panels are listed
in the Log tab.

Opening or saving a file makes its folder the working folder, so results
are written next to it. When the open file is changed by another program,
Strata offers to read it again on returning to the window.

The **Edit** menu (Undo, Redo, Cut, Copy, Paste, Select all) and the
Cut/Copy/Paste buttons act on the field, text or table that has the focus.

---

## The macro editor

The editor has its own **Macro**, **Histograms**, **Results** and **Log**
tabs.

* **Run** starts a new engine, with the threads on the toolbar, in the
  macro's folder, and sends the macro one command at a time. A command
  Geant4 refuses stops the macro: its line is marked in red and the reason
  is written to the Log tab. `/run/beamOn` runs like Beam on, with its line
  marked in yellow and the spectra drawn as they fill. **Abort** stops the
  run and the rest of the macro.
* **Step** (F8) sends one command at a time; the next one is marked in
  green. **Run to cursor** (F4) sends everything above the cursor's line.
  While the macro is stopped the text cannot be changed.

The editor colours comments, numbers, strings, `{aliases}` and commands, and
marks in red a command Geant4 does not have. Typing `/` lists the commands
and directories one level down; letters filter the list, another `/` goes
down a level, and Return takes the selected entry. **Ctrl+Space** lists what
can be typed at the cursor. A space after a command or parameter offers the
choices of the next parameter: units, particles, materials, `true`/`false`.
The strip under the text describes the command on the cursor's line and its
parameters.

---

## Geant4 menu

* **Geant4 viewer...** shows the current set-up in Geant4's own viewer, with
  a few events drawn. In the editor it runs the macro without its
  `/run/beamOn`, then the number of events asked for.
* **Preview geometry** shows the geometry alone, without a run.
* **Terminal...** opens a terminal with Strata and Geant4 ready to use, in the
  output folder.
* **Geant4 datasets...** lists the Geant4 data files, says which are
  missing, and downloads them, by default to
  `~/Library/Application Support/Strata/data` (macOS),
  `~/.local/share/strata/data` (Linux) or `%LOCALAPPDATA%\Strata\data`
  (Windows). No administrator rights are needed. An interrupted download
  resumes where it stopped.

---

## Preferences

**Options** on the toolbar:

| | |
| --- | --- |
| Output Directory | where results are written |
| Geant4 Directory | the Geant4 installation |
| Geant4 Datasets | the folder with the Geant4 data files; empty for the one in the Geant4 installation |
| Strata Library | the folder with the Strata library |
| Strata Executable | the batch program, used by the viewer and the terminal |
| Terminal Command (Unix) | the terminal to open, with `%s` for the script, e.g. `alacritty -e %s` |

A change of datasets folder while an engine is open takes effect in a new
session.
