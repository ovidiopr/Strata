//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/include/RBSDetector.hh
// \brief Rutherford backscattering spectrometry by forced detection.
//
// Backscattering into a real detector is far too rare to simulate by
// waiting for it.  The Rutherford cross-section into a solid angle of a
// few millisteradian is of order 1e-3 barn/sr, which is about 1e-6 of an
// incident ion per detector, so a spectrum worth looking at would need
// 1e12 histories.  Every RBS code therefore uses forced detection: at
// each step of the projectile the yield that *would* reach the detector
// is added analytically,
//
//     dY = N  dx  (dsigma/dOmega)(E, theta)  dOmega
//
// and recorded at the energy that yield would arrive with.  The
// statistics then come from sampling the depth, which the ordinary
// transport already does well, and 1e5 histories give a clean spectrum.
//
// What the projectile does between steps (straggling, multiple
// scattering, the slowing down that shapes the spectrum) is Geant4's,
// not ours.  Only the rare large-angle scatter is replaced by its
// expectation value.

#ifndef RBSDetector_h
#define RBSDetector_h 1

#include "globals.hh"
#include "G4ThreeVector.hh"

#include <vector>

class DetectorConstruction;
class G4Material;
class G4ParticleDefinition;
class G4Step;
class RBSMessenger;

//==============================================================================

class RBSDetector {
public:
    explicit RBSDetector(DetectorConstruction* detector);
    ~RBSDetector();

    // Adds what this step contributes to the spectrum
    void AccumulateStep(const G4Step* step);

    // Clears the per-run cache
    void BeginOfRun();

    // The detector, as /strata/rbs/ sets it
    void SetEnabled(G4bool v)        { fEnabled = v; }
    void SetAngle(G4double v)        { fAngle = v; fGeometryStale = true; }
    void SetSolidAngle(G4double v)   { fSolidAngle = v; }
    void SetResolution(G4double v)   { fResolution = v; }
    void SetTilt(G4double v)         { fTilt = v; fTiltSet = true; fGeometryStale = true; }

    // The beam angle, pushed here by the gun.  Tilting the beam and tilting
    // the sample are the same geometry seen from the two ends, and the exit
    // path has to be corrected for it either way -- the inbound path does
    // not, because forced detection measures it along the track Geant4
    // really followed.  So an untouched detector follows the beam, and
    // /strata/rbs/tilt stays as an override for anyone who wants the two
    // set apart.  Whichever is used, the correction is applied once
    void SetBeamAngle(G4double v)    { fBeamAngle = v; fGeometryStale = true; }
    G4double EffectiveTilt() const   { return fTiltSet ? fTilt : fBeamAngle; }
    void SetScreening(G4bool v)      { fScreening = v; }

    G4bool    IsEnabled() const    { return fEnabled; }
    G4double  GetAngle() const     { return fAngle; }
    G4double  GetSolidAngle() const{ return fSolidAngle; }
    G4double  GetResolution() const{ return fResolution; }
    G4double  GetTilt() const      { return fTilt; }
    G4bool    GetScreening() const { return fScreening; }

    // The physics, exposed so it can be tested on its own

    // The kinematic factor
    static G4double KinematicFactor(G4double aM1, G4double aM2, G4double aTheta);

    // The Rutherford differential cross-section in the laboratory frame
    static G4double RutherfordCrossSection(G4double aZ1, G4double aM1,
                                           G4double aZ2, G4double aM2,
                                           G4double aE, G4double aTheta);

    // The centre-of-mass scattering angle for a laboratory angle
    static G4double CmAngle(G4double aM1, G4double aM2, G4double aTheta);

    // Andersen's correction for the screening of the nuclear charge by
    // the electrons, as a factor on the Rutherford cross-section
    static G4double AndersenScreening(G4double aZ1, G4double aM1,
                                      G4double aZ2, G4double aM2,
                                      G4double aE, G4double aTheta);

private:
    // Energy lost by a projectile of energy aEnergy leaving from aDepth
    // along the exit direction, down to the surface
    G4double ExitLoss(G4double aDepth, G4double aEnergy,
                      const G4ParticleDefinition* aProjectile) const;

    // The layer material at a depth below the entrance face
    G4Material* MaterialAtDepth(G4double aDepth) const;

    // Works out the exit direction and path-length factor from the
    // scattering angle and the sample tilt
    void UpdateGeometry();

    DetectorConstruction* fDetector;
    RBSMessenger*         fMessenger;

    G4bool    fEnabled    = false;
    G4double  fAngle;              // scattering angle, 0 to 180 degrees
    G4double  fSolidAngle;         // of the detector
    G4double  fResolution;         // FWHM of the detector, in energy
    G4double  fTilt;               // of the sample, beam to surface normal
    G4bool    fTiltSet = false;    // whether /strata/rbs/tilt was used
    G4double  fBeamAngle = 0.;     // what the gun is set to
    G4bool    fScreening  = true;  // apply Andersen's correction

    // Set by UpdateGeometry: the exit path from depth x is x*fPathFactor
    G4bool    fGeometryStale = true;
    G4double  fPathFactor;
    G4bool    fBackscatter;        // the detector is on the entrance side
};

#endif
