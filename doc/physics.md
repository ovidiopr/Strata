# Physics models in Strata

A short guide to choosing physics. It names what each option contains and
where it does and does not apply; the references and the Geant4 Physics List
Guide [1] give the details.

Physics is chosen with `/strata/physics/addPhysics <name>` before
`/run/initialize`: one electromagnetic (EM) list, plus any hadronic
components. Production cuts (`/run/setCut`) and the `/process/em/` commands
of Geant4 refine any list.

## Strata's EM lists

| List | Contents | Use for | Not for |
| --- | --- | --- | --- |
| `standardNR` | Standard EM; explicit screened nuclear collisions with recoils [2]; ICRU 49/73 electronic stopping [3,4] | Ion implantation, ranges, recoils, NIEL and dpa | Ions slower than 100 eV/nucleon (they are stopped) |
| `srim` | `standardNR` with ZBL screening [5] and electronic stopping from SRIM tables you load | Comparisons with SRIM/TRIM ([srim-comparison.md](srim-comparison.md)) | Results meant to be independent of SRIM's stopping |
| `local` | Standard EM with Urban multiple scattering [6], ICRU 73 ion stopping and continuous nuclear stopping | General work with electrons, photons and light ions | Recoils or displacement damage |
| `standardATIMA` | Standard EM with ATIMA energy loss for ions [7] | Swift heavy ions (MeV/nucleon to GeV/nucleon) | Low-energy ions |
| `standard5D` | Standard EM with 5D Bethe–Heitler pair conversion [8] | Pair-conversion kinematics, γ polarisation | Anything else, where it only costs time |

### Nuclear stopping in `standardNR` and `srim`

The screened nuclear recoil process [2] samples individual collisions with a
screened Coulomb potential (ZBL universal screening [5]) and creates the
recoiling atoms, which are then transported themselves. This is the
binary-collision picture of TRIM, inside Geant4. Points to keep in mind:

* Collisions transferring less than 10 eV are not sampled (but see the next
  point), and recoils below 100 eV are not created: their energy is
  deposited on the spot.
* Between 1 and 100 MeV/nucleon, p, d, t, He3 and alpha also get WentzelVI
  multiple scattering [6] for the small momentum transfers; above 100
  MeV/nucleon all ions use Urban multiple scattering and no explicit recoils.
* Geant4 stops charged hadrons and ions below `lowestMuHadEnergy` (1 keV by
  default). For keV ions set `/process/em/lowestMuHadEnergy 100 eV`.
* NIEL is split with the Lindhard–Robinson partition [9] of the most
  abundant element of the material, an approximation for compounds.
* The material is amorphous: no channelling, no crystal structure.

## Geant4 EM lists

| List | Contents | Use for |
| --- | --- | --- |
| `standard_opt0` | Geant4 default EM | High-energy work, speed |
| `standard_opt1`, `standard_opt2` | Faster, less precise variants | Large high-energy simulations |
| `standard_opt3` | Urban multiple scattering for all charged particles, finer steps | Medical and space applications |
| `standard_opt4` | Most accurate standard and low-energy models combined | Precision for e±, γ and light ions |
| `standardSS` | Single Coulomb scattering instead of multiple scattering | Reference angular distributions (slow) |
| `standardWVI`, `standardGS` | Default with WentzelVI or Goudsmit–Saunderson for e± | Electron transport studies |
| `livermore`, `penelope`, `lowenergy` | Low-energy photon and electron models with atomic shell structure | X-rays, fluorescence, PIXE, photon attenuation |
| `dna`, `dna_opt2`, `dna_opt4`, `dna_opt6` | Geant4-DNA track structure [10] | Nanometre-scale tracks in liquid water (G4_WATER) only |
| `ionGasModels` | Adds effective-charge models for ions in gases | Ions in gas targets |

None of these includes the screened nuclear recoil process, so the damage
histograms stay empty; `standard_opt4` has no nuclear stopping at all.

## Hadronic physics

| Name | Contents | Use for |
| --- | --- | --- |
| `hadron_therapy` | `standard_opt4`, QGSP_BIC, binary ion cascade, elastic, stopping, radioactive decay, neutron cut | Proton and ion beams with nuclear reactions |
| `hadron_therapy_hp` | As above, with high-precision (HP) neutron models below 20 MeV | The same, when neutron transport matters |
| `neutron_hp` | `standard_opt4`, HP neutrons with thermal scattering [11], stopping, radioactive decay; no neutron cut | Shielding, moderators, activation |

Components can be added one by one (`rad_decay`, `elastic`, `elastic_hp`,
`elastic_hpt`, `qgsp_bic`, `qgsp_bic_hp`, `binary`, `binary_ion`,
`binary_cascade`, `gamma_nuc`, `extra_physics`, `stopping`,
`neutron_tracking`); see [commands.md](commands.md). HP models need the
G4NDL dataset.

## Displacement damage

With `standardNR` or `srim`, every recoil above the displacement threshold
Ed is scored as:

* **NRT-dpa** [12], from the damage energy of the Lindhard–Robinson
  partition [9]. This is what SRIM calls Kinchin–Pease mode; compare with
  SRIM's quick calculation, not with its full-cascade vacancy count [13].
* **arc-dpa** [14], which corrects NRT for athermal recombination. Its
  constants b and c are built in for Fe, Cu, Ni, Pd, Pt and W; other
  materials need `/strata/damage/setArc`.

Both are binary-collision estimates of primary damage, not of the defects
that survive.

## References

1. Geant4 Collaboration, *Physics List Guide*,
   https://geant4.web.cern.ch/documentation/ ; S. Agostinelli et al.,
   Nucl. Instrum. Methods A 506 (2003) 250,
   https://doi.org/10.1016/S0168-9002(03)01368-8 ; J. Allison et al.,
   Nucl. Instrum. Methods A 835 (2016) 186,
   https://doi.org/10.1016/j.nima.2016.06.125
2. M. H. Mendenhall, R. A. Weller, Nucl. Instrum. Methods B 227 (2005) 420,
   https://doi.org/10.1016/j.nimb.2004.08.014
3. ICRU Report 49, *Stopping Powers and Ranges for Protons and Alpha
   Particles* (1993).
4. ICRU Report 73, *Stopping of Ions Heavier than Helium* (2005).
5. J. F. Ziegler, M. D. Ziegler, J. P. Biersack, Nucl. Instrum. Methods B 268
   (2010) 1818, https://doi.org/10.1016/j.nimb.2010.02.091
6. V. N. Ivanchenko, O. Kadri, M. Maire, L. Urban, J. Phys. Conf. Ser. 219
   (2010) 032045, https://doi.org/10.1088/1742-6596/219/3/032045
7. ATIMA, GSI, https://web-docs.gsi.de/~weick/atima/ ; J. Lindhard,
   A. H. Sørensen, Phys. Rev. A 53 (1996) 2443,
   https://doi.org/10.1103/PhysRevA.53.2443
8. D. Bernard, Nucl. Instrum. Methods A 899 (2018) 85; I. Semeniouk,
   D. Bernard, Nucl. Instrum. Methods A 936 (2019) 290.
9. J. Lindhard, V. Nielsen, M. Scharff, P. V. Thomsen, Mat. Fys. Medd. Dan.
   Vid. Selsk. 33 (10) (1963); M. T. Robinson, in *Radiation-Induced Voids
   in Metals*, Albany (1972) 397.
10. S. Incerti et al., Med. Phys. 45 (2018) e722,
    https://doi.org/10.1002/mp.13048
11. L. Thulliez, C. Jouanne, E. Dumonteil, Nucl. Instrum. Methods A 1027
    (2022) 166187, https://doi.org/10.1016/j.nima.2021.166187
12. M. J. Norgett, M. T. Robinson, I. M. Torrens, Nucl. Eng. Des. 33 (1975)
    50, https://doi.org/10.1016/0029-5493(75)90035-7
13. R. E. Stoller et al., Nucl. Instrum. Methods B 310 (2013) 75,
    https://doi.org/10.1016/j.nimb.2013.05.008
14. K. Nordlund et al., Nat. Commun. 9 (2018) 1084,
    https://doi.org/10.1038/s41467-018-03415-5
