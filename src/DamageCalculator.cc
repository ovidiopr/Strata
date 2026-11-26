//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/src/DamageCalculator.cc
// \brief Implementation of the DamageCalculator class

#include "DamageCalculator.hh"
#include "G4ScreenedNuclearRecoil.hh"
#include "DamageMessenger.hh"
#include "DetectorConstruction.hh"
#include "HistoManager.hh"

#include "G4AnalysisManager.hh"
#include "G4Material.hh"
#include "G4Track.hh"
#include "G4ParticleDefinition.hh"
#include "G4SystemOfUnits.hh"
#include "G4UnitsTable.hh"

#include <cmath>
#include <iomanip>

//==============================================================================

namespace {

// Table 1 of Nordlund et al., Nature Communications 9 (2018) 1084.  Only
// the materials that paper fits are here; anything else needs
// /strata/damage/setEd and /strata/damage/setArc
struct BuiltIn { const char* name; G4double ed; G4double b; G4double c; };

const BuiltIn kBuiltIn[] = {
    {"G4_Fe", 40.*CLHEP::eV, -0.568, 0.286},
    {"G4_Cu", 33.*CLHEP::eV, -0.68,  0.16 },
    {"G4_Ni", 39.*CLHEP::eV, -1.01,  0.23 },
    {"G4_Pd", 41.*CLHEP::eV, -0.88,  0.15 },
    {"G4_Pt", 42.*CLHEP::eV, -1.12,  0.11 },
    {"G4_W",  70.*CLHEP::eV, -0.56,  0.12 }
};

}  // namespace

//==============================================================================

DamageCalculator::DamageCalculator(DetectorConstruction* det)
        : fDetector(det),
          fMessenger(nullptr),
          fEnabled(false) {
    for (const BuiltIn& b : kBuiltIn)
        fConstants[b.name] = DamageConstants{b.ed, b.b, b.c};

    fMessenger = new DamageMessenger(this);

    // Recoils too slow to be tracked are reported where they are deposited
    G4ScreenedNuclearRecoil::SetRecoilObserver(
        [this](const G4Track& projectile, G4int z, G4double a, G4double energy) {
            if (projectile.GetTrackID() == 1) Count(z, a, projectile.GetPosition(), energy);
        });
}

//==============================================================================

DamageCalculator::~DamageCalculator() {
    G4ScreenedNuclearRecoil::SetRecoilObserver(nullptr);
    delete fMessenger;
}

//==============================================================================

void DamageCalculator::SetDisplacementEnergy(const G4String& material, G4double value) {
    auto it = fConstants.find(material);
    if (it == fConstants.end())
        fConstants[material] = DamageConstants{value, 0., 1.};
    else
        it->second.ed = value;
}

//==============================================================================

void DamageCalculator::SetArcConstants(const G4String& material, G4double b, G4double c) {
    auto it = fConstants.find(material);
    if (it == fConstants.end())
        fConstants[material] = DamageConstants{0., b, c};
    else {
        it->second.bArc = b;
        it->second.cArc = c;
    }
}

//==============================================================================

//==============================================================================

G4bool DamageCalculator::BuiltInFor(const G4String& material, DamageConstants& out) {
    for (const BuiltIn& b : kBuiltIn) {
        if (material != b.name) continue;
        out = DamageConstants{b.ed, b.b, b.c};
        return true;
    }
    return false;
}

//==============================================================================

G4bool DamageCalculator::ConstantsFor(const G4String& material,
                                      DamageConstants& out) const {
    auto it = fConstants.find(material);
    if (it == fConstants.end() || it->second.ed <= 0.) return false;
    out = it->second;
    return true;
}

//==============================================================================

void DamageCalculator::Print() const {
    G4cout << "\n Displacement damage: " << (fEnabled ? "on" : "off") << G4endl;
    G4cout << " material            Ed       b_arc    c_arc" << G4endl;
    for (const auto& entry : fConstants)
        G4cout << " " << std::setw(18) << std::left << entry.first
               << std::setw(9) << G4BestUnit(entry.second.ed, "Energy")
               << std::setw(9) << entry.second.bArc
               << entry.second.cArc << G4endl;
}

//==============================================================================

// NRT, as Norgett, Robinson and Torrens defined it
G4double DamageCalculator::NrtDisplacements(G4double aTdam, G4double aEd) {
    if (aEd <= 0. || aTdam < aEd) return 0.;
    if (aTdam < 2.*aEd/0.8) return 1.;
    return 0.8*aTdam/(2.*aEd);
}

//==============================================================================

// NRT with the athermal recombination correction of Nordlund et al., which
// is unity at the NRT threshold and falls with the damage energy
G4double DamageCalculator::ArcDisplacements(G4double aTdam, const DamageConstants& aC) {
    if (aC.ed <= 0. || aTdam < aC.ed) return 0.;
    if (aTdam < 2.*aC.ed/0.8) return 1.;

    const G4double threshold = 2.*aC.ed/0.8;
    const G4double xi = (1. - aC.cArc)*std::pow(aTdam/threshold, aC.bArc) + aC.cArc;
    return 0.8*aTdam/(2.*aC.ed)*xi;
}

//==============================================================================

G4Material* DamageCalculator::MaterialAtDepth(G4double aDepth) const {
    const G4double x = fDetector->GetLayerXmin(0) + aDepth;
    for (G4int n = 0; n < fDetector->GetLayerNumber(); ++n)
        if (x >= fDetector->GetLayerXmin(n) && x <= fDetector->GetLayerXmax(n))
            return fDetector->GetLayerMaterial(n);
    return nullptr;
}

//==============================================================================

void DamageCalculator::AccumulateRecoil(const G4Track* aTrack) {
    if (!fEnabled || aTrack == nullptr) return;

    // Only the recoils the projectile makes itself.  NRT counts the whole
    // cascade a primary knock-on atom produces, so adding the recoils
    // inside that cascade as well counts the same displacements twice
    if (aTrack->GetParentID() != 1) return;

    const G4ParticleDefinition* def = aTrack->GetDefinition();
    G4int z = def->GetAtomicNumber();
    G4double a = def->GetAtomicMass();
    // A recoil proton is a nucleus too, whatever the particle table calls it
    if (z == 0 && def->GetPDGCharge() == eplus && def->GetBaryonNumber() == 1) {
        z = 1;
        a = 1.;
    }
    Count(z, a, aTrack->GetPosition(), aTrack->GetKineticEnergy());
}

//==============================================================================

void DamageCalculator::Count(G4int aZ, G4double aA, const G4ThreeVector& aWhere, G4double aEnergy) {
    if (!fEnabled || aZ <= 0 || aA <= 0.) return;

    const G4double xmax = fDetector->GetMultiLayerSizeX();
    const G4double depth = aWhere.x() + 0.5*xmax;
    if (depth < 0. || depth > xmax) return;

    G4Material* material = MaterialAtDepth(depth);
    if (material == nullptr) return;

    DamageConstants c;
    if (!ConstantsFor(material->GetName(), c)) return;

    const G4double tdam = aEnergy*fPartition.PartitionNIEL(aZ, aA, material, aEnergy);

    auto* analysisManager = G4AnalysisManager::Instance();
    // A knock-on atom is one that is displaced
    if (aEnergy >= c.ed) analysisManager->FillH1(kStrataH1Pka, aEnergy);

    // Per unit fluence, so the bin has to become a number of atoms per unit
    // area: the width is reported in the unit of the axis, and the unit is
    // how large that is internally
    const G4double width = analysisManager->GetH1Width(kStrataH1DpaNrt)
                           *analysisManager->GetH1Unit(kStrataH1DpaNrt);
    if (width <= 0.) return;
    const G4double perArea = material->GetTotNbOfAtomsPerVolume()*width;
    if (perArea <= 0.) return;

    analysisManager->FillH1(kStrataH1DpaNrt, depth,
                            NrtDisplacements(tdam, c.ed)/perArea/cm2);
    analysisManager->FillH1(kStrataH1DpaArc, depth,
                            ArcDisplacements(tdam, c)/perArea/cm2);
}
