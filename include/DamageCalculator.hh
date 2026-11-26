//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/include/DamageCalculator.hh
// \brief Displacements per atom from the recoils of a cascade.

#ifndef DamageCalculator_h
#define DamageCalculator_h 1

#include "globals.hh"
#include "G4ThreeVector.hh"
#include "G4LindhardPartition.hh"

#include <map>

class DetectorConstruction;
class DamageMessenger;
class G4Material;
class G4Track;

//==============================================================================

// The constants a material needs, as Nordlund et al. fit them
struct DamageConstants {
    G4double ed;        // threshold displacement energy
    G4double bArc;      // arc-dpa exponent
    G4double cArc;      // arc-dpa offset
};

//==============================================================================

class DamageCalculator {
public:
    explicit DamageCalculator(DetectorConstruction*);
    ~DamageCalculator();

    // Counts the displacements a new recoil will produce
    void AccumulateRecoil(const G4Track* aTrack);

    void SetEnabled(G4bool v)        { fEnabled = v; }
    G4bool GetEnabled() const        { return fEnabled; }

    void SetDisplacementEnergy(const G4String& material, G4double value);
    void SetArcConstants(const G4String& material, G4double b, G4double c);
    void Print() const;

    // What is in use for a material, built in or set by command
    G4bool ConstantsFor(const G4String& material, DamageConstants& out) const;

    // What is built in for a material, whatever has been set since
    static G4bool BuiltInFor(const G4String& material, DamageConstants& out);

    // Displacements from a recoil of damage energy aTdam, as NRT counts them
    static G4double NrtDisplacements(G4double aTdam, G4double aEd);
    // The same, with the athermal recombination of Nordlund et al.
    static G4double ArcDisplacements(G4double aTdam, const DamageConstants& aC);

private:
    DetectorConstruction* fDetector;
    DamageMessenger* fMessenger;
    G4LindhardRobinsonPartition fPartition;

    G4bool fEnabled;
    std::map<G4String, DamageConstants> fConstants;

    G4Material* MaterialAtDepth(G4double aDepth) const;

    // One knock-on atom, tracked or not
    void Count(G4int aZ, G4double aA, const G4ThreeVector& aWhere, G4double aEnergy);
};

//==============================================================================

#endif
