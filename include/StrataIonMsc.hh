//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
/// \file StrataIonMsc.hh
/// \brief Multiple scattering for hadrons and ions in the nuclear-recoil lists

#ifndef StrataIonMsc_h
#define StrataIonMsc_h 1

#include "globals.hh"
#include "G4SystemOfUnits.hh"

class G4ParticleDefinition;
class G4hMultipleScattering;

namespace StrataIonMsc {

// FactorForAngleLimit: the momentum transfer that separates msc from G4ScreenedNuclearRecoil
constexpr G4double kFactorForAngleLimit = 0.01;

// Energy per nucleon above which p, d, t, He3 and alpha use WentzelVI with the recoil process
constexpr G4double kMinEnergyPerNucleon = 1.*MeV;

// Sets the shared EM parameters; call after G4EmParameters::SetDefaults()
void Configure();

// p, d, t, He3, alpha: WentzelVI from kMinEnergyPerNucleon to limitPerNucleon, Urban above;
// other ions: Urban above limitPerNucleon only
G4hMultipleScattering* Make(const G4ParticleDefinition* particle, G4double limitPerNucleon);

}

#endif
