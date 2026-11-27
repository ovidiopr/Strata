//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
/// \file StrataIonMsc.cc
/// \brief Multiple scattering for hadrons and ions in the nuclear-recoil lists

#include "StrataIonMsc.hh"

#include "G4EmParameters.hh"
#include "G4hMultipleScattering.hh"
#include "G4ParticleDefinition.hh"
#include "G4PhysicalConstants.hh"
#include "G4UrbanMscModel.hh"
#include "G4WentzelVIModel.hh"

//==============================================================================

void StrataIonMsc::Configure() {
    G4EmParameters::Instance()->SetFactorForAngleLimit(kFactorForAngleLimit);
}

//==============================================================================

G4hMultipleScattering* StrataIonMsc::Make(const G4ParticleDefinition* particle,
                                          G4double limitPerNucleon) {
    G4hMultipleScattering* msc = new G4hMultipleScattering();
    const G4String& name = particle->GetParticleName();
    const G4bool light = name == "proton" || name == "deuteron" || name == "triton"
                         || name == "He3" || name == "alpha";

    if (!light) {
        G4UrbanMscModel* model = new G4UrbanMscModel();
        model->SetActivationLowEnergyLimit(limitPerNucleon);
        msc->SetEmModel(model);
        return msc;
    }

    const G4double massRatio = particle->GetPDGMass()/amu_c2;
    const G4double split = limitPerNucleon*massRatio;

    G4WentzelVIModel* low = new G4WentzelVIModel();
    low->SetHighEnergyLimit(split);
    low->SetActivationLowEnergyLimit(kMinEnergyPerNucleon*massRatio);
    G4UrbanMscModel* high = new G4UrbanMscModel();
    high->SetLowEnergyLimit(split);

    // G4hMultipleScattering registers only the first SetEmModel model itself
    msc->SetEmModel(low);
    msc->AddEmModel(1, high);
    return msc;
}
