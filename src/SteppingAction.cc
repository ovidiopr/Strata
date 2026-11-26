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
/// \file Strata/src/SteppingAction.cc
/// \brief Implementation of the SteppingAction class
//
//
//==============================================================================
//==============================================================================

#include "SteppingAction.hh"

#include "DetectorConstruction.hh"
#include "RBSDetector.hh"
#include "RunAction.hh"
#include "EventAction.hh"
#include "HistoManager.hh"
#include "Run.hh"

#include "G4Step.hh"
#include "G4RunManager.hh"
#include "G4DynamicParticle.hh"
#include "G4PrimaryParticle.hh"
#include "G4Material.hh"
#include "G4SystemOfUnits.hh"

//==============================================================================

namespace {
/// Below this density a material is vacuum: an ion keeps its charge state
/// there.  The front end's Vacuum is 1e-11 g/cm3; StripperGas is about 1e-6
constexpr G4double kVacuumDensity = 1.e-9*g/cm3;
}

//==============================================================================

SteppingAction::SteppingAction(DetectorConstruction* det, EventAction* EvAct, RunAction* RunAct) :
        G4UserSteppingAction(),
        fDetector(det),
        fEventAction(EvAct),
        fRunAction(RunAct) { }

//==============================================================================

SteppingAction::~SteppingAction() = default;

//==============================================================================

// Geant4 replaces an ion's charge with the equilibrium effective charge on
// every step, in vacuum too, so the charge given to /gun/ion never reached
// the field.  The primary keeps a charge state in vacuum and takes the
// effective one in matter; particles Geant4 does not re-charge in matter
// (protons, deuterons, ...) are stripped there to their nominal charge.
void SteppingAction::HoldChargeState(const G4Step* aStep) {
    G4Track* track = aStep->GetTrack();
    if (track->GetTrackID() != 1) return;
    auto* dp = const_cast<G4DynamicParticle*>(track->GetDynamicParticle());

    if (track->GetCurrentStepNumber() == 1) {
        const G4PrimaryParticle* primary = dp->GetPrimaryParticle();
        fHeldCharge = (primary != nullptr) ? primary->GetCharge() : dp->GetCharge();
    }

    const G4Material* mat = aStep->GetPostStepPoint()->GetMaterial();
    if (mat == nullptr) return;          // it has left the world

    if (mat->GetDensity() < kVacuumDensity) {
        dp->SetCharge(fHeldCharge);
    } else {
        const G4ParticleDefinition* def = dp->GetDefinition();
        const G4bool effectiveCharge = (def->GetParticleType() == "nucleus")
                                       && (def->GetPDGCharge() > 1.5*eplus);
        if (!effectiveCharge) dp->SetCharge(def->GetPDGCharge());
        fHeldCharge = dp->GetCharge();
    }
}

//==============================================================================

void SteppingAction::UserSteppingAction(const G4Step* aStep) {
    HoldChargeState(aStep);

//    if (aStep->GetPreStepPoint()->GetTouchableHandle()->GetVolume()
//        != fDetector->GetAbsorber())
//        return;

    // Save tracks to files
    if (fRunAction->GetSavePrimaries() || fRunAction->GetSaveCascades()) {
        fRunAction->WriteToFiles(aStep);
    }

    // Before the test below: a step that deposits nothing still carries the
    // projectile through matter it can backscatter from
    fDetector->GetRBS()->AccumulateStep(aStep);

    G4double Edep = aStep->GetTotalEnergyDeposit();
    if (Edep <= 0.) return;

    G4double Eniel = aStep->GetNonIonizingEnergyDeposit();

    Run* run = static_cast<Run*>(
            G4RunManager::GetRunManager()->GetNonConstCurrentRun());

    fEventAction->AddEnergy(Edep);
    fEventAction->AddNIELEnergy(Eniel);

    G4double charge = aStep->GetTrack()->GetDefinition()->GetPDGCharge();
    if (charge != 0.) {
        fEventAction->AddTrakLenCharg(aStep->GetStepLength());
        fEventAction->CountStepsCharg();
    } else {
        fEventAction->AddTrakLenNeutr(aStep->GetStepLength());
        fEventAction->CountStepsNeutr();
    }

    G4StepPoint* prePoint = aStep->GetPreStepPoint();
    G4StepPoint* postPoint = aStep->GetPostStepPoint();

    G4int copyNb = prePoint->GetTouchableHandle()->GetCopyNumber();
    if (copyNb > 0) { run->FillVoxelEdep(copyNb - 1, Edep); }

    if (aStep->GetTrack()->GetTrackID() == 1) {
        run->AddPrimaryStep();
    }

    //Bragg curve (separated in ionizing and non-ionizing fractions)
    G4double xmax = fDetector->GetMultiLayerSizeX();

    G4double x1 = prePoint->GetPosition().x() + xmax*0.5;
    G4double x2 = postPoint->GetPosition().x() + xmax*0.5;
    if (x1 >= 0.0 && x2 <= xmax) {
        G4double x = x1 + G4UniformRand()*(x2 - x1);
        if (aStep->GetTrack()->GetDefinition()->GetPDGCharge() == 0.) x = x2;
        G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();
        // The ionizing fraction of the energy deposited
        analysisManager->FillH1(1, x, Edep - Eniel);
        // The non-ionizing fraction of the energy deposited
        analysisManager->FillH1(2, x, Eniel);
    }
}

//==============================================================================
