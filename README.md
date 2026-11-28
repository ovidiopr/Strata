Strata
======

**Strata** is a Monte Carlo program, built on [Geant4](https://geant4.web.cern.ch/),
for the irradiation of layered targets: the energy deposited along the track,
ionizing and non-ionizing, the range of the projectile, the spectra of what
leaves the target, displacement damage, the dose in test volumes, and
Rutherford backscattering spectra. It started from Geant4's example *TestEm7*.

It can be used three ways: a window with panels for every setting, an editor
for Geant4 macros with completion and help, and a batch program that runs
macros.

The program is academic. A lot of effort has gone into making its results
correct, but **use it at your own risk**.

---

## Installing

1. **Geant4.** Strata 1.1.0 needs Geant4 11.4.3, from the
   [Geant4 installers](https://github.com/ovidiopr/geant4-installers/releases). The installer asks which data files to download;
   the preselected ones are the ones Geant4 cannot run without.
2. **Strata.** From the [releases](https://github.com/ovidiopr/strata/releases):

| | |
| --- | --- |
| Windows | `Install-Strata-<version>-win64-x86_64.exe` |
| macOS (Apple silicon) | `strata_<version>_arm64.dmg`: drag Strata to Applications |
| Debian, Ubuntu (amd64) and Raspberry Pi OS (arm64) | `strata_<version>_<arch>.deb` |

On Linux both packages can be installed together:

```sh
sudo apt install ./geant4_<version>_amd64.deb ./strata_<version>_amd64.deb
```

If Geant4 is missing, the Windows installer stops and offers the download
page, the Debian package names it as a dependency, and the window says so
when it starts.

Data files left out at installation can be added later from the window,
**Geant4 datasets...** on the Geant4 menu, or with

```sh
sudo <geant4-prefix>/share/Geant4/fetch-datasets.sh --one G4NDL
```

To build Strata from source, see [BUILDING.md](BUILDING.md).

---

## Getting started

Open the window (**StrataGUI**) and then one of the examples:

* `configs/*.scf`: configurations for the panels;
* `macros/*.mac`: the same examples as Geant4 macros, for the macro editor
  or the batch program.

Every macro has a configuration of the same name, so an example can be run
either way. A macro with several runs has one configuration per run
(`nucl-1.scf` to `nucl-5.scf`).

In the panels: **Initialise**, then **Beam on**. The spectra fill on the
Histograms tab while the run goes, and the Results tab shows the summary at
the end. In the macro editor: **Run**.

The batch program runs a macro:

```sh
Strata proton.mac            # batch
Strata                       # interactive, with the Geant4 viewer
Strata -g setup.mac          # run setup.mac, then open the viewer
```

---

## Documentation

* [doc/gui.md](doc/gui.md): the window, the panels and the macro editor.
* [doc/commands.md](doc/commands.md): geometry, materials, physics lists,
  beam, random numbers, histograms, displacement damage, RBS and output.
* [doc/srim-comparison.md](doc/srim-comparison.md): the `srim` physics list
  and how Strata compares with SRIM/TRIM.
* [doc/physics.md](doc/physics.md): the physics models, where each applies,
  and references.
* [doc/developers.md](doc/developers.md): how the code is organised.

---

## Licence

Strata is distributed under the GNU General Public License, version 3; see
[LICENSE](LICENSE). The parts taken from Geant4 keep the Geant4 Software
Licence stated in their headers.
