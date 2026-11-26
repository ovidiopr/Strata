# Strata commands

Everything Strata does can be set with Geant4 macro commands. The panels of
the window send the same commands, so a set-up can be prepared either way.

---

## Geometry

The target is a stack of layers, each of one material, normal to the beam
(the x axis), placed in a *world*.

| Command | Sets |
| --- | --- |
| `/strata/geometry/setWorldMat <material>` | the material of the world |
| `/strata/geometry/setTemperature <T> <unit>` | the target temperature |
| `/strata/geometry/setSizeYZ <size> <unit>` | the transverse size of the stack |
| `/strata/geometry/layerNumber <n>` | the number of layers |
| `/strata/geometry/layerThickness <i> <t> <unit>` | the thickness of layer i (from 0) |
| `/strata/geometry/layerMaterial <i> <material> [<density> <unit>]` | the material of layer i, optionally at another density |
| `/strata/geometry/setField <Bz> <unit>` | a uniform magnetic field along z |

The default is one layer of silica (amorphous SiO2), 20 um thick. The number
of layers is set before their thicknesses and materials. Layer count,
thicknesses and transverse size cannot be changed after `/run/initialize`;
materials can.

Fields in any direction, electric or magnetic, and the stepper used to
integrate them:

```
/strata/BField/setValue 0 0 1 tesla
/strata/EField/setValue 5 0 0 megavolt/m
/strata/BField/setStepperType 4
/strata/BField/setMinStep 0.01 mm
```

### Test volumes

Boxes inside the target in which the dose is scored (*voxels*). Each one
lies inside a single layer, which gives it its material; the position is
that of its centre, in the frame of the target.

```
/strata/geometry/voxelNumber 2
/strata/geometry/voxelDefinition 0 1 1 1 mm      # sides
/strata/geometry/voxelPosition   0 -5 0 0 mm     # centre
```

The deposited energy and the dose in gray are printed at the end of each run
and shown on the Results tab.

---

## Materials

A layer or the world can be any material Geant4 knows: the NIST catalogue
(`G4_WATER`, `G4_SILICON_DIOXIDE`, ...) and Strata's own (`Silica`, `Quartz`,
`NaI`, `Vacuum`, `StripperGas`, ...). Others are built from a density and a
list of constituents:

```
/strata/material/create            <name> <density> <unit>
/strata/material/addMaterial       <material> <massFraction>
/strata/material/addElement        <symbol> <massFraction>
/strata/material/addElementByAtoms <symbol> <atoms>
/strata/material/build
```

`/strata/material/cancel` abandons a definition, `/strata/material/list`
lists everything defined and `/strata/material/print <name>` shows one.

Constituents are given either as mass fractions, which add up to 1, or as
numbers of atoms, as in a chemical formula, but not both in one material.

```
# a glass, by weight
/strata/material/create Borosilicate 2.23 g/cm3
/strata/material/addMaterial G4_SILICON_DIOXIDE 0.81
/strata/material/addMaterial G4_BORON_OXIDE 0.13
/strata/material/addMaterial G4_SODIUM_MONOXIDE 0.04
/strata/material/addMaterial G4_ALUMINUM_OXIDE 0.02
/strata/material/build

# a compound, from its formula
/strata/material/create SiliconNitride 3.17 g/cm3
/strata/material/addElementByAtoms Si 3
/strata/material/addElementByAtoms N 4
/strata/material/build
```

A definition that cannot be built (a name already taken, fractions that do
not add up, ...) is refused with the reason and stays open to be corrected.
`macros/materials.mac` is a worked example.

---

## Physics lists

```
/strata/physics/addPhysics <list>
```

Strata's own lists:

* **local**: standard EM physics with Strata's choice of options.
* **standardSS**: standard EM physics with single Coulomb scattering instead
  of multiple scattering.
* **standardNR**: standard EM physics with the screened nuclear recoil process
  of M. H. Mendenhall and R. A. Weller ([NIMB 227 (2005) 420](https://dx.doi.org/10.1016/j.nimb.2004.08.014))
  for ions below 100 MeV/nucleon. This is the list for nuclear stopping,
  recoils and displacement damage.
* **srim**: standardNR with the ZBL screening function, and electronic
  stopping from tables you supply. See [srim-comparison.md](srim-comparison.md).

Geant4's lists: **standard_opt0** to **standard_opt4**, **standardATIMA**,
**ionGasModels**, **standardWVI**, **standardGS**, **standard5D**,
**livermore**, **penelope**, **lowenergy**, **dna**, **dna_opt2**,
**dna_opt4** and **dna_opt6**.

For hadron therapy: **hadron_therapy** and **hadron_therapy_hp**. For
neutrons: **neutron_hp**, which brings everything a neutron needs
(`standard_opt4`, `elastic_hpt`, `qgsp_bic_hp`, `stopping` and `rad_decay`).

Optional components, added with the same command: **rad_decay**,
**binary_cascade**, **extra_physics**, **elastic**, **elastic_hp**,
**elastic_hpt** (scattering off bound nuclei), **DElastic**, **HElastic**,
**binary**, **binary_ion**, **gamma_nuc**, **stopping**, **qgsp_bic**,
**qgsp_bic_hp** and **neutron_tracking**.

The lists and components ending in `_hp` or `_hpt` need the G4NDL data file
(1.1 GB, not preselected by the Geant4 installers). Without it they are not
added, and a message says so.

Production cuts and step limits:

```
/run/setCut 1 um
/run/setCutForAGivenParticle gamma 0.5 um
/strata/stepMax 10 nm
/strata/stack/killSecondaries 1       # 0 track, 1 kill and record, 2 kill
```

Atomic de-excitation (Auger electrons, fluorescence, PIXE) is off by
default. It is switched on **before** `/run/initialize`:

```
/process/em/fluo true
/process/em/auger true
/process/em/augerCascade true
/process/em/pixe true
/process/em/deexcitationIgnoreCut true
```

---

## Beam

The beam is a single particle per event that hits the centre of the
entrance face, set with Geant4's gun commands:

```
/gun/particle proton
/gun/energy 1 MeV
/gun/particle ion
/gun/ion 6 12            # Z A
```

The default is a 1 MeV proton. Strata adds:

```
/strata/gun/angle 7.5 deg     # tilt from the normal, in the x-y plane, -90 to 90
/strata/gun/rndBeam 1 mm      # beam size: side of a square spot, uniform
/strata/gun/charge -1         # charge state in units of e, or auto
/strata/gun/setDefault        # back to the default beam
```

A tilted beam still arrives at the centre of the entrance face.

`/strata/gun/charge` is needed for a negative ion, since `/gun/ion` does not
take a negative charge. The beam keeps its charge state in vacuum (any
material below 1e-9 g/cm3, such as `Vacuum`); in matter it takes the
equilibrium effective charge, and keeps the charge it left with when it is
back in vacuum. Protons and other light particles take their nominal charge
in matter, so an H- beam leaves a foil as H+.

---

## Random numbers

```
/strata/random/engine ranecu      # ranecu mixmax mtwist ranlux64 ranluxpp james
/strata/random/randomize true     # new seeds for every run (default)
/strata/random/seeds 12345 67890  # fixed seeds, for a repeatable run
/strata/random/print              # what is in use
```

Each run prints the seeds it used as the command that repeats it. The
engine is chosen before `/run/initialize`; the seeds at any time.

A run with fixed seeds repeats exactly on one thread. On several threads
the events are the same but the sums are added in a different order, so the
last digits can change; use one thread for a bit-for-bit comparison.

---

## Histograms

All histograms are off by default. One is switched on by giving it bins and
a range:

```
/analysis/h1/set <id> <bins> <min> <max> <unit> [log10]
```

| id | |
| --- | --- |
| 1 | Ionizing energy deposited along the track of the projectile (Se) |
| 2 | Non-ionizing energy deposited along the track of the projectile (Sn) |
| 3 | Projectile range |
| 4 | Displacements per atom per unit fluence (NRT) |
| 5 | Displacements per atom per unit fluence (arc-dpa) |
| 6 | Energy of primary knock-on atoms |
| 10 | Energy deposited in the target |
| 11, 13 | Energy of charged secondaries at creation (linear, log10) |
| 12, 14 | Energy of gamma secondaries at creation (linear, log10) |
| 15 | x vertex of charged secondaries (all) |
| 16 | x vertex of charged secondaries (not absorbed) |
| 17, 18 | Energy of neutron secondaries at creation (linear, log10) |
| 20 to 25 | Charged particles transmitted: energy, dE/dOmega, dN/dOmega, projected angle, projected position, radius |
| 30 to 33 | Neutral particles transmitted (not neutrons): energy, dE/dOmega, dN/dOmega, projected angle |
| 34 to 37 | Neutrons transmitted: energy, dE/dOmega, dN/dOmega, projected angle |
| 40 to 43 | Charged particles reflected: energy, dE/dOmega, dN/dOmega, projected angle |
| 50 to 53 | Neutral particles reflected (not neutrons): energy, dE/dOmega, dN/dOmega, projected angle |
| 54 to 57 | Neutrons reflected: energy, dE/dOmega, dN/dOmega, projected angle |
| 60 to 63 | Auger electrons and fluorescence gammas at creation (linear, log) |
| 64 to 67 | PIXE Auger electrons and gammas at creation (linear, log) |
| 68 to 71 | Geant4-DNA Auger electrons and gammas at creation (linear, log) |
| 80 | Rutherford backscattering spectrum |

dN/dOmega and dE/dOmega are per steradian, whatever the unit of the angle
axis.

**When a histogram stays empty or flat.** Each histogram collects only what
the run produces:

* 2 is non-zero only with `standardNR` or `srim`, the lists that produce
  nuclear recoils; 4 to 6 need them too.
* 60 to 63 need atomic de-excitation, 64 to 67 PIXE, and 68 to 71 a `dna`
  list.
* 20 to 25 need particles leaving through the far face, 40 to 43 particles
  coming back out; a beam that stops in the target fills neither.
* Values outside the range go to the underflow and overflow bins, which are
  not drawn.

---

## Displacement damage

Histograms 4, 5 and 6 need `standardNR` or `srim` and are switched on with:

```
/strata/damage/enable true
/strata/damage/setEd G4_Si 15 eV          # displacement threshold energy
/strata/damage/setArc G4_Si -0.5 0.3      # arc-dpa constants b and c
/strata/damage/print                      # what is in use
```

Every recoil the projectile makes is a primary knock-on atom. Its damage
energy is the Lindhard partition of its kinetic energy, and the
displacements it produces are counted as NRT (h1[4]) and with the athermal
recombination correction of Nordlund et al. (h1[5]), at the depth where the
recoil started. h1[6] is the spectrum of knock-on atoms above Ed per
incident ion.

h1[4] and h1[5] are dpa per unit fluence: multiplied by a fluence in
ions/cm2, they give the dpa at each depth. For the target as a whole,
average the curve over depth rather than integrating it.

Ed, b and c are built in for G4_Fe, G4_Cu, G4_Ni, G4_Pd, G4_Pt and G4_W
(Table 1 of Nordlund et al., *Nature Communications* **9** (2018) 1084). Any
other material needs `setEd`, and `setArc` for the correction; without
`setArc`, h1[5] equals h1[4].

NRT on a Lindhard partition is what SRIM calls Kinchin-Pease mode.

---

## Rutherford backscattering

Histogram 80 is a backscattering spectrum: counts per incident ion against
the energy an ion reaches the detector with. It is computed by forced
detection: at every step of the projectile, the probability of scattering
into the detector from each element of the material is added at the energy
the ion would reach the detector with. A few thousand ions give a smooth
spectrum.

```
/strata/rbs/enable true          # off by default
/strata/rbs/angle 165 deg        # scattering angle
/strata/rbs/solidAngle 1 msr     # solid angle of the detector
/strata/rbs/resolution 15 keV    # detector resolution, FWHM
/strata/rbs/tilt 0 deg           # target tilt; follows the beam angle if not set
/strata/rbs/screening true       # Andersen screening correction
```

The cross-section is Rutherford's, with Andersen's screening correction, and
the energy loss on the way out is Geant4's electronic stopping. A run with
the detector on takes several times longer.

---

## Output

```
/analysis/setFileName name       # histogram file (default strata)
/analysis/h1/setAscii <id>       # also write histogram id as text
/strata/files/writeHistograms true|false
```

The batch program writes the histograms; the window keeps them in memory
and exports them on request.

Every step of every track can be written as text, the primaries and the
secondary cascades to separate files:

```
/strata/files/savePrimaries true
/strata/files/saveCascades true
/strata/files/setPrimariesName primaries.txt
/strata/files/setCascadesName cascades.txt
```

Each line is one step: event, step, track, parent, particle, time, position,
momentum, kinetic energy and process. The files are large (about 10 kB per
event), so they are for looking at a few events.

`strataSpecies.py` summarises them: which species are present, with what
energy and angle, optionally only those past a plane:

```sh
python strataSpecies.py stripper_primaries.txt stripper_recoils.txt --past 50
```

`plotHisto.py` plots histogram files.

---

## Visualisation

`Strata` started without a macro, or with `-g`, opens the Geant4 viewer and
runs `macros/vis.mac`. Tracks are drawn at the end of each event. `-v` makes
the visualisation available in batch, to write a picture with a file
driver (`/vis/open VRML2FILE`, `HepRepFile`, `RayTracer`):

```sh
Strata -v -n 1 setup.mac vis-to-file.mac
```
