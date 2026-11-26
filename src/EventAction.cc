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
/// \file Strata/src/EventAction.cc
/// \brief Implementation of the EventAction class
//
//
//==============================================================================
//==============================================================================

#include "EventAction.hh"

#include "Run.hh"
#include "HistoManager.hh"
#include "StrataResults.hh"

#include "G4RunManager.hh"
#include "G4Event.hh"

//==============================================================================

EventAction::EventAction()
        : G4UserEventAction(),
          fEnergyDeposit(0.), fNIELEnergy(0.),
          fProjRange(0.),
          fTrakLenCharged(0.), fTrakLenNeutral(0.),
          fNbStepsCharged(0), fNbStepsNeutral(0),
          fTransmitFlag(0), fReflectFlag(0) {}

//==============================================================================

EventAction::~EventAction() = default;

//==============================================================================

void EventAction::BeginOfEventAction(const G4Event*) {
    // Initialisation per event
    fEnergyDeposit = 0.; fNIELEnergy = 0.;
    fProjRange = 0.;
    fTrakLenCharged = fTrakLenNeutral = 0.;
    fNbStepsCharged = fNbStepsNeutral = 0;
    fTransmitFlag = fReflectFlag = 0;
}

//==============================================================================

void EventAction::EndOfEventAction(const G4Event*) {
    Run* run = static_cast<Run*>(
            G4RunManager::GetRunManager()->GetNonConstCurrentRun());

    run->AddEnergy(fEnergyDeposit);
    run->AddNIELEnergy(fNIELEnergy);

    run->AddTrakLenCharg(fTrakLenCharged);
    run->AddTrakLenNeutr(fTrakLenNeutral);

    run->CountStepsCharg(fNbStepsCharged);
    run->CountStepsNeutr(fNbStepsNeutral);

    run->CountTransmit(fTransmitFlag);
    run->CountReflect(fReflectFlag);

    if (fEnergyDeposit > 0.)
        G4AnalysisManager::Instance()->FillH1(10, fEnergyDeposit);
    if (fProjRange > 0.)
        G4AnalysisManager::Instance()->FillH1(3, fProjRange);

    // Live progress for the front end
    StrataResultStore::Instance().CountEvent();

    // Send the spectra as it is, so one can be watched while the run goes on
    StrataPublishLiveH1(false);

    // The front end have asked for the run to stop
    if (StrataResultStore::Instance().AbortRequested())
        G4RunManager::GetRunManager()->AbortRun(true);
}

//==============================================================================

