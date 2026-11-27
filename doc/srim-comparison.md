# Strata's `srim` physics list, and how it relates to SRIM/TRIM

```
/strata/physics/addPhysics srim
```

This document is for people who know what TRIM does and want to know, before
they trust a number, exactly where Strata agrees with it and where it does
not. It is deliberately specific about the second part.

---

## 1. What the list is

`srim` is **not** a reimplementation of TRIM. It is Geant4's `standardNR`
configuration with two changes:

* the screened-nuclear-recoil process is constructed with the **ZBL universal
  screening function** named explicitly rather than inherited as a default;
* ionisation for protons, light ions and generic ions runs through model
  wrappers that consult an **externally supplied electronic stopping table**
  where you have loaded one, and fall back to Geant4's own parameterisation
  everywhere else.

With no table loaded it is a complete, self-consistent Geant4 physics list —
`standardNR` with the screening choice made visible. It is not a broken or
half-configured state, and it is a perfectly reasonable thing to run.

**Strata ships no SRIM data.** The stopping powers in SRIM are the product of
decades of fitting by its authors and are theirs to distribute. What Strata
provides is the mechanism to use a table you generated yourself, from your own
SRIM installation, for your own materials. If you intend to publish numbers
produced this way, settle the attribution and licensing question first; cite
SRIM for the stopping powers and Geant4 for the transport.

---

## 2. The three pieces of SRIM, one at a time

It helps to stop thinking of SRIM as one thing. It is three, and Strata
relates to each differently.

| | SRIM/TRIM | Strata `srim` | Same? |
| --- | --- | --- | --- |
| **Nuclear stopping** | ZBL universal screening, binary collisions, MAGIC formula for the scattering integral | ZBL universal screening, binary collisions, numerically integrated cross-section (`G4ScreenedNuclearRecoil`) | Same physics, different evaluation |
| **Electronic stopping** | Semi-empirical fit, distributed as coefficient tables | Your table if loaded; otherwise ICRU49/ICRU73/ASTAR with Brandt–Kitagawa effective charge | Same only if you supply SRIM's table |
| **Damage** | Kinchin–Pease or full cascade, against a displacement threshold you type in | NIEL via the Lindhard–Robinson partition, plus full secondary transport | **Different quantities** |

### 2.1 Nuclear stopping — the close match

Both use the ZBL universal screening function, with the universal screening
length

  a_U = 0.8854 · a₀ / (Z₁^0.23 + Z₂^0.23)

and both treat the collision as a classical two-body scattering event off a
screened nucleus. `G4ScreenedNuclearRecoil` is the Mendenhall–Weller process
(NIMB **227** (2005) 420–430), written for exactly this energy regime.

Three differences remain, all of them in the numerics rather than the physics:

* **Scattering integral.** TRIM uses Biersack's MAGIC closed-form
  approximation. Strata integrates the classical scattering integral
  numerically and interpolates it.
* **Free-flight sampling.** TRIM samples an impact parameter up to a p_max
  fixed by the atomic density, advancing by about one atomic spacing per
  collision. Geant4 samples an interaction length from a cross-section with a
  physics cutoff (10 eV by default in this process) below which collisions are
  not generated. The two estimators converge on the same mean stopping power
  but not on the same step-by-step history, so straggling and the tails of a
  depth distribution can differ slightly.
* **Screening alternatives.** Strata also offers Lenz–Jensen (`lj`), Molière
  (`mol`) and a ZBL/Lenz–Jensen hybrid (`ljzbl`). Edit
  `PhysListEmStandardSRIM.cc` to pick one; it is the second constructor
  argument to `G4ScreenedNuclearRecoil`.

### 2.2 Electronic stopping — where you have to act

Geant4's low-energy ion stopping comes from `G4BraggModel`,
`G4BraggIonModel` and `G4IonParametrisedLossModel`, built on ICRU49, ICRU73
and ASTAR with a Brandt–Kitagawa effective charge. That is the same lineage as
ZBL — Ziegler contributed to those compilations — but it is not the same fit.

To use SRIM's numbers instead:

```
/strata/physics/srim/loadTable proton G4_SILICON_DIOXIDE  H-in-SiO2.txt
/strata/physics/srim/loadTable alpha  G4_SILICON_DIOXIDE  He-in-SiO2.txt
/strata/physics/addPhysics srim
/run/initialize
```

Tables must be loaded **before** `/run/initialize`. Use the Geant4 particle
name (`proton`, `alpha`, `He3`, `deuteron`, `triton`, or `GenericIon` as a
catch-all for every ion) and the Geant4 material name exactly as it appears in
the material table. `/strata/physics/srim/list` reports what is loaded and —
after a run — which particle/material pairs were actually served from a table
and which quietly fell back to Geant4. Read it before trusting a comparison; a
typo in a material name is otherwise invisible.

**Accepted formats.** Either the text output of SRIM's *Stopping and Range
Tables* module, in any of the length-normalised units (eV/Å, keV/µm, MeV/mm,
…) or mass-normalised units (MeV/(mg/cm²), keV/(µg/cm²), …), or a plain
columnar file:

```
# energy_unit keV
# dedx_unit keV/um
#  energy      electronic     nuclear
   1.0         0.0856         0.0421
   1.2         0.0934         0.0398
```

SRIM's `eV / (1E15 atoms/cm²)` and L.S.S. reduced units are **not** accepted:
converting them needs the areal atom density or the reduced-energy scaling
rather than a mass density. Re-export choosing one of the supported units.

`strata_dedx`, installed with Strata (`/usr/bin` on Linux,
`StrataGUI.app/Contents/MacOS` on macOS, the installation folder on Windows),
writes the columnar format with `--dump`, so

```
strata_dedx --dump proton G4_SILICON_DIOXIDE geant4.tbl 1 10000 200
```

gives you Geant4's own curve on the same footing, ready to plot against
SRIM's.

**Restricted versus unrestricted stopping power.** This subtlety is worth
understanding, because getting it wrong silently biases every range you
compute. A tabulated stopping power is the *total* energy lost to electrons.
Geant4 wants the *restricted* loss, excluding the part carried off by delta
electrons that it transports explicitly, because counting both double-counts.
The models therefore scale the tabulated value by the restricted/unrestricted
ratio the underlying Geant4 model gives at the same point.

When the production cut is above the maximum delta-electron energy, no deltas
are made, the ratio is one, and the table is used exactly as supplied. **That
is the configuration to use when comparing against SRIM**, because TRIM has no
delta transport at all. If you want the strict TRIM analogue, raise the cut
until the range stops changing.

**Nuclear column.** If your file carries SRIM's nuclear stopping column it is
parsed and kept, but it is **not** used for transport. A tabulated average
nuclear stopping power would throw away the recoil spectrum, which is the main
thing Strata can tell you and TRIM's tabulated S_n cannot. It is retained for
reporting and for plotting against what the explicit collisions produce.

### 2.3 Damage — different quantities, not different numbers

This is the one that most often causes confusion in print.

TRIM reports **vacancies**, counted against a displacement threshold energy
E_d you supply per element, either in Kinchin–Pease mode or by following the
full cascade. Strata reports **NIEL** — non-ionizing energy loss — obtained
from the Lindhard–Robinson partition of each recoil's energy, and transports
every recoil above the recoil cutoff (100 eV per nucleon of the recoil) as a
real particle. With `/strata/damage/enable` it also counts NRT displacements
from every knock-on atom above E_d, tracked or not (see *Displacement
damage* in [commands.md](commands.md)).

The two are related through the NRT expression (Norgett, Robinson & Torrens,
*Nucl. Eng. Des.* **33** (1975) 50), but NIEL is not a displacement count:
NRT is applied per knock-on atom and gives nothing below E_d, so
0.8·NIEL/(2·E_d) over-counts whenever much of the NIEL comes from collisions
near or under E_d, as it does for light ions. Stoller and co-workers (*NIMB* **310** (2013) 75) set out at
length why SRIM's two modes disagree with NRT and with each other; the same
cautions apply to any comparison you make here.

Nor does Strata model:

* **lattice binding energy** — TRIM subtracts it at every collision;
* **surface binding energy** — TRIM's route to sputtering yields. Strata
  predicts no sputtering.

So the shallow end of a depth profile is where the two codes should be
expected to differ most, and sputtering comparisons are out of scope.

---

## 3. Everything else that differs

| Aspect | SRIM/TRIM | Strata |
| --- | --- | --- |
| Target structure | Amorphous, no channeling | Amorphous, no channeling — **the same** |
| Electronic straggling | Chu/Yang parameterisation | Urban / universal fluctuation model |
| Secondary electrons | Not transported | Transported, down to the production cut |
| Photons, X-rays | Not modelled | Full EM cascade, fluorescence on by default |
| Nuclear reactions | None | Available if a hadronic component is added |
| Target geometry | Flat layers only | Flat layers, plus scoring voxels and fields |
| Charge-state evolution | Effective-charge scaling | Brandt–Kitagawa, or your table |

The row that matters most here: Strata transports secondaries and SRIM does
not. With a low production cut a stopping proton generates tens of tracked
electrons per event. That is why Strata can give you a resolved dose map in a voxel and TRIM cannot, and
also why comparing "energy deposited at depth x" between the two compares two
different definitions unless the cut is raised.

---

## 4. A comparison recipe

1. In SRIM, run *Stopping and Range Tables* for your ion and target. Choose a
   length- or mass-normalised stopping unit. Save as text.
2. Check that SRIM's target density matches the Geant4 material's. If you are
   using a NIST material it probably does not match your sample; define your
   own material rather than scaling the table.
3. Load it, select `srim`, initialise.
4. Run `/strata/physics/srim/list` and confirm your pair appears under
   "served from a table". If it appears under "fell back to Geant4", the name
   or the energy range is wrong.
5. Raise the production cut above the maximum delta-electron energy if you want
   the strict TRIM analogue, and say so in your methods.
6. Compare the projected range first — it is the most robust number in both
   codes. Compare S_e(x) next. Leave vacancy counts for last, and state
   explicitly which definition you are using.

Things that will *not* agree, and should not be presented as discrepancies:
sputtering yields (Strata has none), vacancy counts against NRT (a different
quantity), dose in the first few nanometres (lattice and surface binding), and
anything involving secondary-electron transport (SRIM has none).

---

## 5. References

* J. F. Ziegler, J. P. Biersack and U. Littmark, *The Stopping and Range of
  Ions in Solids*, Pergamon, 1985.
* J. F. Ziegler, M. D. Ziegler and J. P. Biersack, *SRIM — The stopping and
  range of ions in matter (2010)*, NIMB **268** (2010) 1818.
* M. H. Mendenhall and R. A. Weller, *An algorithm for computing screened
  Coulomb scattering in Geant4*, NIMB **227** (2005) 420.
* J. Lindhard, V. Nielsen, M. Scharff and P. V. Thomsen, *Integral equations
  governing radiation effects*, Mat. Fys. Medd. Dan. Vid. Selsk. **33** (1963)
  no. 10.
* M. J. Norgett, M. T. Robinson and I. M. Torrens, *A proposed method of
  calculating displacement dose rates*, Nucl. Eng. Des. **33** (1975) 50.
* R. E. Stoller et al., *On the use of SRIM for computing radiation damage
  exposure*, NIMB **310** (2013) 75.
