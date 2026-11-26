//
// ********************************************************************
// * License and Disclaimer                                           *
// *                                                                  *
// * The  Geant4 software  is  copyright of the Copyright Holders  of *
// * the Geant4 Collaboration.  It is provided  under  the terms  and *
// * conditions of the Geant4 Software License,  included in the file *
// * LICENSE and available at  http://cern.ch/geant4/license .  These *
// * include a list of copyright holders.                             *
// *                                                                  *
// * Neither the authors of this software system, nor their employing *
// * institutes,nor the agencies providing financial support for this *
// * work  make  any representation or  warranty, express or implied, *
// * regarding  this  software system or assume any liability for its *
// * use.  Please see the license in the file  LICENSE  and URL above *
// * for the full disclaimer and the limitation of liability.         *
// *                                                                  *
// * This  code  implementation is the result of  the  scientific and *
// * technical work of the GEANT4 collaboration.                      *
// * By using,  copying,  modifying or  distributing the software (or *
// * any work based  on the software)  you  agree  to acknowledge its *
// * use  in  resulting  scientific  publications,  and indicate your *
// * acceptance of all terms of the Geant4 Software license.          *
// ********************************************************************
//
/// \file Strata/src/StackingAction.cc
/// \brief Implementation of the StackingAction class
//
//
//==============================================================================
//==============================================================================

#include "StackingAction.hh"

#include "Run.hh"
#include "EventAction.hh"
#include "HistoManager.hh"
#include "DetectorConstruction.hh"
#include "DamageCalculator.hh"
#include "StackingMessenger.hh"

#include "G4RunManager.hh"
#include "G4Track.hh"
#include "G4Neutron.hh"
#include "G4EmSecondaryParticleType.hh"

//==============================================================================

StackingAction::StackingAction(EventAction* EA)
        : G4UserStackingAction(), fEventAction(EA) {
    fStackMessenger = new StackingMessenger(this);
}

//==============================================================================

StackingAction::~StackingAction() {
    delete fStackMessenger;
}

//==============================================================================

G4ClassificationOfNewTrack
StackingAction::ClassifyNewTrack(const G4Track* aTrack) {
    G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();

    //keep primary particle
    if (aTrack->GetParentID() == 0) { return fUrgent; }

    G4int procID = aTrack->GetCreatorProcess()->GetProcessSubType();
    G4int modelID = aTrack->GetCreatorModelID();

    //count secondary particles
    Run* run = static_cast<Run*>(
            G4RunManager::GetRunManager()->GetNonConstCurrentRun());
    run->CountParticles(aTrack->GetDefinition());

    // A recoil nucleus starts a cascade
    const auto* detector = static_cast<const DetectorConstruction*>(
            G4RunManager::GetRunManager()->GetUserDetectorConstruction());
    if (detector != nullptr) detector->GetDamage()->AccumulateRecoil(aTrack);

    //
    //energy spectrum of secondaries
    //
    G4double energy = aTrack->GetKineticEnergy();
    G4double charge = aTrack->GetDefinition()->GetPDGCharge();

    if (charge != 0.) {
        analysisManager->FillH1(11, energy);
        analysisManager->FillH1(13, energy);
        if (procID >= 51 && procID <= 65) {
            analysisManager->FillH1(68, energy);
            analysisManager->FillH1(70, energy);
        } else if (_AugerElectron == modelID) {
            analysisManager->FillH1(60, energy);
            analysisManager->FillH1(62, energy);
        } else if (_ePIXE == modelID) {
            analysisManager->FillH1(64, energy);
            analysisManager->FillH1(66, energy);
        }
    }

    // Neutrons have their own pair.  12 and 14 were always gammas only,
    // whatever their titles used to say
    if (aTrack->GetDefinition() == G4Neutron::Neutron()) {
        analysisManager->FillH1(kStrataH1NeutronBorn, energy);
        analysisManager->FillH1(kStrataH1NeutronBornLog, energy);
    }

    if (aTrack->GetDefinition() == G4Gamma::Gamma()) {
        analysisManager->FillH1(12, energy);
        analysisManager->FillH1(14, energy);
        if (procID >= 51 && procID <= 65) {
            analysisManager->FillH1(69, energy);
            analysisManager->FillH1(71, energy);
        } else if (_Fluorescence == modelID) {
            analysisManager->FillH1(61, energy);
            analysisManager->FillH1(63, energy);
        } else if (_GammaPIXE == modelID) {
            analysisManager->FillH1(65, energy);
            analysisManager->FillH1(67, energy);
        }
    }

    //stack or delete secondaries
    G4ClassificationOfNewTrack status = fUrgent;
    if (0 < fKillSecondary) {
        if (fKillSecondary == 1) {
            fEventAction->AddEnergy(energy);
        }
        status = fKill;
    }

    return status;
}

//==============================================================================
