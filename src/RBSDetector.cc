//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
/// \file Strata/src/RBSDetector.cc
/// \brief Rutherford backscattering spectrometry by forced detection.

#include "RBSDetector.hh"

#include "DetectorConstruction.hh"
#include "HistoManager.hh"
#include "RBSMessenger.hh"

#include "G4AnalysisManager.hh"
#include "G4EmCalculator.hh"
#include "G4Material.hh"
#include "G4ParticleDefinition.hh"
#include "G4PhysicalConstants.hh"
#include "G4Step.hh"
#include "G4SystemOfUnits.hh"
#include "G4Track.hh"
#include "Randomize.hh"

#include <cmath>

//==============================================================================
namespace {

/// e^2/(4 pi eps0) in Geant4 units
const G4double kCoulomb = classic_electr_radius*electron_mass_c2;

/// How finely the exit path is integrated
constexpr G4int kExitSteps = 10;

}  // namespace

//==============================================================================

RBSDetector::RBSDetector(DetectorConstruction* detector)
        : fDetector(detector),
          fAngle(165.*deg),
          fSolidAngle(1e-3*steradian),   // 1 msr, a common detector
          fResolution(15.*keV),
          fTilt(0.) {
    fMessenger = new RBSMessenger(this);
    UpdateGeometry();
}

//==============================================================================

RBSDetector::~RBSDetector() {
    delete fMessenger;
}

//==============================================================================

void RBSDetector::BeginOfRun() {
    UpdateGeometry();
}

//==============================================================================

G4double RBSDetector::KinematicFactor(G4double aM1, G4double aM2,
                                      G4double aTheta) {
    // K = [ (sqrt(M2^2 - M1^2 sin^2 t) + M1 cos t) / (M1 + M2) ]^2
    const G4double s = aM1*std::sin(aTheta);
    const G4double under = aM2*aM2 - s*s;
    // A projectile heavier than the target cannot come back: beyond
    // asin(M2/M1) there is no solution at all
    if (under < 0.) return 0.;
    const G4double k = (std::sqrt(under) + aM1*std::cos(aTheta))/(aM1 + aM2);
    return (k > 0.) ? k*k : 0.;
}

//==============================================================================

G4double RBSDetector::CmAngle(G4double aM1, G4double aM2, G4double aTheta) {
    const G4double r = aM1/aM2;
    const G4double s = r*std::sin(aTheta);
    if (s > 1. || s < -1.) return -1.;
    // A projectile heavier than the target scatters only into a forward
    // cone, so there is no solution behind 90 degrees
    if (std::cos(aTheta) < 0. && r >= 1.) return -1.;
    return aTheta + std::asin(s);
}

G4double RBSDetector::RutherfordCrossSection(G4double aZ1, G4double aM1,
                                             G4double aZ2, G4double aM2,
                                             G4double aE, G4double aTheta) {
    if (aE <= 0.) return 0.;

    // Through the centre of mass rather than through the closed laboratory form
    const G4double thetaCm = CmAngle(aM1, aM2, aTheta);
    if (thetaCm < 0.) return 0.;

    const G4double half = std::sin(0.5*thetaCm);
    if (half <= 0.) return 0.;

    const G4double eCm = aE*aM2/(aM1 + aM2);
    const G4double a = aZ1*aZ2*kCoulomb/(4.*eCm);
    const G4double sigmaCm = a*a/(half*half*half*half);

    // dOmega_cm / dOmega_lab
    const G4double r = aM1/aM2;
    const G4double c = std::cos(thetaCm);
    const G4double den = std::abs(1. + r*c);
    if (den < 1e-12) return 0.;
    const G4double jacobian = std::pow(1. + r*r + 2.*r*c, 1.5)/den;

    return sigmaCm*jacobian;
}

//==============================================================================

G4double RBSDetector::AndersenScreening(G4double aZ1, G4double aM1,
                                        G4double aZ2, G4double aM2,
                                        G4double aE, G4double aTheta) {
    if (aE <= 0.) return 1.;

    // Andersen et al., Phys. Rev. A 21 (1980) 1891.  V1 is an increment to
    // the centre-of-mass energy standing for the screened potential.
    const G4double V1 = 0.04873*keV*aZ1*aZ2
                        *std::sqrt(std::pow(aZ1, 2./3.) + std::pow(aZ2, 2./3.));
    const G4double eCm = aE*aM2/(aM1 + aM2);
    if (eCm <= 0.) return 1.;

    const G4double thetaCm = CmAngle(aM1, aM2, aTheta);
    if (thetaCm < 0.) return 1.;

    const G4double half = std::sin(thetaCm/2.);
    if (std::abs(half) < 1e-12) return 1.;

    const G4double num = 1. + 0.5*V1/eCm;
    const G4double d   = V1/(2.*eCm*half);
    const G4double den = 1. + V1/eCm + d*d;
    return num*num/(den*den);
}

//==============================================================================

void RBSDetector::UpdateGeometry() {
    // A detector at a scattering angle beyond 90 degrees sees particles
    // leaving through the face the beam came in by
    const G4double cosT = std::cos(fAngle);
    fBackscatter = (cosT < 0.);

    // Without tilt the exit path from depth x is x/|cos(theta)|
    const G4double tilt = EffectiveTilt();
    G4double cosExit = std::abs(cosT);
    if (tilt != 0.) {
        const G4double exitAngle = pi - fAngle - tilt;
        cosExit = std::abs(std::cos(exitAngle));
    }
    fPathFactor = (cosExit > 1e-6) ? 1./cosExit : 0.;
    fGeometryStale = false;
}

//==============================================================================

G4Material* RBSDetector::MaterialAtDepth(G4double aDepth) const {
    const G4double x = fDetector->GetLayerXmin(0) + aDepth;
    for (G4int n = 0; n < fDetector->GetLayerNumber(); ++n)
        if (x >= fDetector->GetLayerXmin(n) && x <= fDetector->GetLayerXmax(n))
            return fDetector->GetLayerMaterial(n);
    return nullptr;
}

G4double RBSDetector::ExitLoss(G4double aDepth, G4double aEnergy,
                               const G4ParticleDefinition* aProjectile) const {
    if (fPathFactor <= 0. || aDepth <= 0. || aProjectile == nullptr) return 0.;

    const G4double ds = aDepth*fPathFactor/kExitSteps;
    const G4double dDepth = aDepth/kExitSteps;

    // One calculator per worker thread
    static G4ThreadLocal G4EmCalculator* calc = nullptr;
    if (calc == nullptr) calc = new G4EmCalculator();

    // The particle leaves the way it came, so it crosses the same layers in reverse
    G4double e = aEnergy;
    for (G4int i = 0; i < kExitSteps && e > 0.; ++i) {
        G4Material* mat = MaterialAtDepth(aDepth - (i + 0.5)*dDepth);
        if (mat == nullptr) break;
        e -= calc->ComputeTotalDEDX(e, aProjectile, mat)*ds;
    }
    return (e < aEnergy) ? aEnergy - e : 0.;
}

//==============================================================================

void RBSDetector::AccumulateStep(const G4Step* step) {
    if (!fEnabled) return;
    if (fGeometryStale) UpdateGeometry();
    if (fPathFactor <= 0.) return;

    const G4Track* track = step->GetTrack();
    // Only the projectile: a recoil or a secondary is not what an RBS
    // detector is counting
    if (track->GetTrackID() != 1) return;

    const G4Material* mat = step->GetPreStepPoint()->GetMaterial();
    if (mat == nullptr) return;
    const G4double dx = step->GetStepLength();
    if (dx <= 0.) return;

    // Mid-step energy and position: the step is short enough that the
    // average is a better estimate than either end
    const G4double e = 0.5*(step->GetPreStepPoint()->GetKineticEnergy()
                            + step->GetPostStepPoint()->GetKineticEnergy());
    if (e <= 0.) return;

    const G4ParticleDefinition* proj = track->GetDefinition();
    const G4double z1 = proj->GetPDGCharge()/eplus;
    const G4double m1 = proj->GetPDGMass()/amu_c2;
    if (z1 <= 0.) return;

    const G4double xFront = fDetector->GetLayerXmin(0);
    const G4double depth = 0.5*(step->GetPreStepPoint()->GetPosition().x()
                                + step->GetPostStepPoint()->GetPosition().x())
                           - xFront;
    if (depth < 0.) return;

    auto* analysisManager = G4AnalysisManager::Instance();
    const G4ElementVector* elements = mat->GetElementVector();
    const G4double* nAtoms = mat->GetVecNbOfAtomsPerVolume();

    for (std::size_t j = 0; j < mat->GetNumberOfElements(); ++j) {
        const G4Element* el = (*elements)[j];
        const G4double z2 = el->GetZ();
        const G4double m2 = el->GetA()/(g/mole);

        const G4double k = KinematicFactor(m1, m2, fAngle);
        if (k <= 0.) continue;          // too light to send it back

        G4double sigma = RutherfordCrossSection(z1, m1, z2, m2, e, fAngle);
        if (fScreening) sigma *= AndersenScreening(z1, m1, z2, m2, e, fAngle);
        if (sigma <= 0.) continue;

        // What reaches the detector, per incident ion
        const G4double yield = nAtoms[j]*dx*sigma*fSolidAngle;
        if (yield <= 0.) continue;

        // And at what energy: the kinematic factor at the depth it
        // scattered from, less what it loses getting back out
        const G4double eScattered = k*e;
        G4double eDetected = eScattered - ExitLoss(depth, eScattered, proj);
        if (eDetected <= 0.) continue;

        // The detector does not resolve an energy exactly
        if (fResolution > 0.)
            eDetected += G4RandGauss::shoot(0., fResolution/2.35482);
        if (eDetected <= 0.) continue;

        analysisManager->FillH1(kStrataH1RBS, eDetected, yield);
    }
}
