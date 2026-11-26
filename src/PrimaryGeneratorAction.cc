//
// ********************************************************************
//*License and Disclaimer                                           *
//*                                                                 *
//*The  Geant4 software  is  copyright of the Copyright Holders  of *
//*the Geant4 Collaboration.  It is provided  under  the terms  and *
//*conditions of the Geant4 Software License,  included in the file *
//*LICENSE and available at  http://cern.ch/geant4/license .  These *
//*include a list of copyright holders.                             *
//*                                                                 *
//*Neither the authors of this software system, nor their employing *
//*institutes,nor the agencies providing financial support for this *
//*work  make  any representation or  warranty, express or implied, *
//*regarding  this  software system or assume any liability for its *
//*use.  Please see the license in the file  LICENSE  and URL above *
//*for the full disclaimer and the limitation of liability.         *
//*                                                                 *
//*This  code  implementation is the result of  the  scientific and *
//*technical work of the GEANT4 collaboration.                      *
//*By using,  copying,  modifying or  distributing the software (or *
//*any work based  on the software)  you  agree  to acknowledge its *
//*use  in  resulting  scientific  publications,  and indicate your *
//*acceptance of all terms of the Geant4 Software license.          *
// ********************************************************************
//
/// \file Strata/src/PrimaryGeneratorAction.cc
/// \brief Implementation of the PrimaryGeneratorAction class
//
//
//==============================================================================
//==============================================================================

#include "PrimaryGeneratorAction.hh"
#include "DetectorConstruction.hh"
#include "PrimaryGeneratorMessenger.hh"

#include "G4Event.hh"
#include "G4ParticleGun.hh"
#include "G4ParticleTable.hh"
#include "G4ParticleDefinition.hh"
#include "G4SystemOfUnits.hh"
#include "Randomize.hh"
#include "RBSDetector.hh"

#include <cmath>

//==============================================================================

PrimaryGeneratorAction::PrimaryGeneratorAction(DetectorConstruction* det)
        : G4VUserPrimaryGeneratorAction(),
          fParticleGun(nullptr),
          fDetector(det),
          fRndmBeam(0),
          fEbeamCumul(0),
          fGunMessenger(nullptr) {
    fParticleGun = new G4ParticleGun(1);
    SetDefaultKinematic();

    // Create a messenger for this class
    fGunMessenger = new PrimaryGeneratorMessenger(this);
}

//==============================================================================

PrimaryGeneratorAction::~PrimaryGeneratorAction() {
    delete fParticleGun;
    delete fGunMessenger;
}

//==============================================================================

void PrimaryGeneratorAction::SetDefaultKinematic() {
    // Default particle kinematic
    G4ParticleDefinition* particle
            = G4ParticleTable::GetParticleTable()->FindParticle("proton");
    fParticleGun->SetParticleDefinition(particle);
    fParticleGun->SetParticleEnergy(1.*MeV);
    fBeamAngle = 0.;
    fChargeStateSet = false;
    fParticleGun->SetParticleMomentumDirection(G4ThreeVector(1., 0., 0.));
}

//==============================================================================

// The RBS exit path is corrected for the angle between the beam and the
// surface normal, which is this one unless /strata/rbs/tilt overrode it
void PrimaryGeneratorAction::SetBeamAngle(G4double val) {
    fBeamAngle = val;
    if (fDetector != nullptr && fDetector->GetRBS() != nullptr)
        fDetector->GetRBS()->SetBeamAngle(val);
}

//==============================================================================

void PrimaryGeneratorAction::GeneratePrimaries(G4Event* anEvent) {
    // This function is called at the beginning of event
    const G4double cosA = std::cos(fBeamAngle);
    const G4double sinA = std::sin(fBeamAngle);
    const G4ThreeVector along(cosA, sinA, 0.);

    // Where the beam has to arrive: the centre of the entrance face.  Aiming
    // the gun from the same place as before and simply turning it would walk
    // the spot off the face, by the drift over the gap between the world
    // edge and the target -- several millimetres on a short stack, and the
    // whole face on a long one.  So the gun is moved instead, back along the
    // beam from the point it has to hit
    const G4double xFace = fDetector->GetLayerXmin(0);

    // Back off until the world ends, in x or in y, whichever comes first.
    // Taking only the x face would put the gun outside the world at a
    // grazing angle, where the y drift is the larger of the two
    G4double back = (xFace + 0.5*fDetector->GetWorldSizeX())/std::max(cosA, 1e-9);
    if (std::abs(sinA) > 1e-9)
        back = std::min(back, 0.5*fDetector->GetWorldSizeYZ()/std::abs(sinA));

    G4double x0 = xFace - back*cosA;
    G4double y0 = -back*sinA;
    G4double z0 = 0.*um;

    // Randomize the beam, if requested.
    if (fRndmBeam > 0.) {
        if (fRndmBeam > fDetector->GetMultiLayerSizeYZ())
            fRndmBeam = fDetector->GetMultiLayerSizeYZ();
        G4double rbeam = 0.5*fRndmBeam;
        // Across the beam, not across x, so that a tilted beam keeps its
        // own cross-section and the footprint on the target stretches, as
        // a real one does
        const G4double across = (2*G4UniformRand() - 1.)*rbeam;
        x0 += -across*sinA;
        y0 += across*cosA;
        z0 = (2*G4UniformRand() - 1.)*rbeam;
    }
    fParticleGun->SetParticleMomentumDirection(along);
    fParticleGun->SetParticlePosition(G4ThreeVector(x0, y0, z0));
    if (fChargeStateSet) fParticleGun->SetParticleCharge(fChargeState*eplus);
    fParticleGun->GeneratePrimaryVertex(anEvent);

    fEbeamCumul += fParticleGun->GetParticleEnergy();
}

//==============================================================================

