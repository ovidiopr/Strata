//==============================================================================
/// \file Strata/include/SRIMIonisationModel.hh
/// \brief Geant4 energy-loss models backed by an external stopping table.
///
/// Rather than write an energy-loss model from scratch, each of these
/// derives from the standard Geant4 model it replaces and overrides exactly
/// one method: the stopping power.  Delta-ray production, energy-loss
/// fluctuations, the step limitation and everything else stay as Geant4
/// built them, which is what keeps the "srim" list a physics-list variant
/// rather than a parallel transport code.
///
/// Restricted versus unrestricted stopping power
/// ---------------------------------------------
/// A tabulated stopping power (SRIM's included) is the *total* electronic
/// stopping: all the energy the projectile loses to electrons, whatever
/// becomes of it afterwards.  Geant4 wants the *restricted* loss, with the
/// part carried away by explicitly produced delta rays removed, because it
/// transports those deltas separately.  Handing it the unrestricted number
/// double-counts them.
///
/// The models therefore scale the tabulated value by the ratio the
/// underlying Geant4 model gives between its restricted and unrestricted
/// stopping power at the same point.  Where the production cut is above the
/// maximum delta-ray energy no deltas are made, the ratio is one, and the
/// table is used unchanged, which is the TRIM-like configuration, and the
/// one to choose when comparing against SRIM.
//==============================================================================

#ifndef SRIMIonisationModel_h
#define SRIMIonisationModel_h 1

#include "SRIMStoppingData.hh"

#include "G4BetheBlochModel.hh"
#include "G4BraggIonModel.hh"
#include "G4BraggModel.hh"
#include "G4Material.hh"
#include "G4ParticleDefinition.hh"

#include <cfloat>

//==============================================================================
/// Mixin: \a BaseModel with its stopping power replaced where a table says so.
//==============================================================================
template <class BaseModel>
class SRIMDEDXModel : public BaseModel {
public:
    using BaseModel::BaseModel;      // same constructors as the model replaced

    G4double ComputeDEDXPerVolume(const G4Material* material,
                                  const G4ParticleDefinition* particle,
                                  G4double kinEnergy,
                                  G4double cutEnergy) override {
        G4double tabulated = 0.;
        if (!SRIMStoppingData::Instance().GetElectronicDEDX(
                particle, material, kinEnergy, tabulated))
            return BaseModel::ComputeDEDXPerVolume(material, particle,
                                                   kinEnergy, cutEnergy);

        // Passing an effectively infinite cut makes the base model return its
        // unrestricted stopping power: it clamps the cut to the kinematic
        // maximum internally.
        const G4double baseRestricted =
            BaseModel::ComputeDEDXPerVolume(material, particle, kinEnergy,
                                            cutEnergy);
        const G4double baseTotal =
            BaseModel::ComputeDEDXPerVolume(material, particle, kinEnergy,
                                            DBL_MAX);

        if (baseTotal <= 0. || baseRestricted <= 0. || baseRestricted > baseTotal)
            return tabulated;        // no sensible ratio; use the table as is

        return tabulated*(baseRestricted/baseTotal);
    }
};

//==============================================================================

using SRIMBraggModel      = SRIMDEDXModel<G4BraggModel>;
using SRIMBraggIonModel   = SRIMDEDXModel<G4BraggIonModel>;
using SRIMBetheBlochModel = SRIMDEDXModel<G4BetheBlochModel>;

//==============================================================================
#endif
