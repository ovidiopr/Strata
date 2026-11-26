//==============================================================================
// \file Strata/include/PhysListEmStandardSRIM.hh
// \brief Definition of the PhysListEmStandardSRIM class
//
// A SRIM/TRIM-like configuration of Geant4, reached with
//
//     /strata/physics/addPhysics srim
//
// It is standardNR with two deliberate changes:
//
//   * the screened-nuclear-recoil process is built with the ZBL universal
//     screening function named explicitly, so the choice is visible in the
//     source rather than inherited as a default;
//   * ionisation for protons, light ions and generic ions goes through the
//     SRIMDEDXModel wrappers, which use an externally supplied stopping
//     table where one has been loaded and Geant4's own parameterisation
//     everywhere else.
//
// Loading a table is a separate, explicit act:
//
//     /strata/physics/srim/loadTable proton G4_SILICON_DIOXIDE H-in-SiO2.txt
//
// With no table loaded this list is a well-defined Geant4 configuration in
// its own right (it is standardNR with explicit ZBL screening) and not
// a broken one.  doc/srim-comparison.md sets out what it does and does not
// share with TRIM.
//==============================================================================

#ifndef PhysListEmStandardSRIM_h
#define PhysListEmStandardSRIM_h 1

#include "G4VPhysicsConstructor.hh"
#include "globals.hh"

//==============================================================================

class PhysListEmStandardSRIM : public G4VPhysicsConstructor {
public:
    explicit PhysListEmStandardSRIM(const G4String& name = "emstandard_SRIM");
    ~PhysListEmStandardSRIM() override;

    void ConstructParticle() override;
    void ConstructProcess() override;

    // Energy above which the screened-recoil process hands over to
    // multiple scattering, as in standardNR.
    static G4double ScatteringEnergyLimit() { return fScatteringLimit; }

private:
    static G4double fScatteringLimit;
};

//==============================================================================
#endif
