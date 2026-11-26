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
/// \file Strata/src/TrackingAction.cc
/// \brief Implementation of the TrackingAction class
//
//
//==============================================================================
//==============================================================================

#include "TrackingAction.hh"

#include "DetectorConstruction.hh"
#include "Run.hh"
#include "EventAction.hh"
#include "RunAction.hh"
#include "HistoManager.hh"

#include "G4RunManager.hh"
#include "G4Track.hh"
#include "G4DynamicParticle.hh"
#include "G4PrimaryParticle.hh"
#include "G4Neutron.hh"
#include "G4PhysicalConstants.hh"
#include "G4SystemOfUnits.hh"

//==============================================================================


// The run action is still taken so that ActionInitialization can hand the
// same three objects to every user action, but nothing here needs it.
TrackingAction::TrackingAction(DetectorConstruction* det, EventAction* EvAct,
                               RunAction*)
        : G4UserTrackingAction(),
          fDetector(det),
          fEventAction(EvAct) {
    fXstartAbs = fXendAbs = fPrimaryCharge = fDirX = 0.0;
}

//==============================================================================

TrackingAction::~TrackingAction() = default;

//==============================================================================

void TrackingAction::PreUserTrackingAction(const G4Track* aTrack) {
    // Some initialisations
    if (aTrack->GetTrackID() == 1) {
        fXstartAbs = -fDetector->GetMultiLayerSizeX()/2.;
        fXendAbs = fDetector->GetMultiLayerSizeX()/2.;
        fPrimaryCharge = aTrack->GetDefinition()->GetPDGCharge();
        fDirX = aTrack->GetMomentumDirection().x();
        // The charge state given to the gun, for the first step too: the
        // first step through vacuum can cross the whole field region
        auto* dp = const_cast<G4DynamicParticle*>(aTrack->GetDynamicParticle());
        const G4PrimaryParticle* primary = dp->GetPrimaryParticle();
        if (primary != nullptr) dp->SetCharge(primary->GetCharge());
    }
}

//==============================================================================

void TrackingAction::PostUserTrackingAction(const G4Track* aTrack) {
    G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();

    Run* run = static_cast<Run*>(
            G4RunManager::GetRunManager()->GetNonConstCurrentRun());

    const G4ThreeVector& position = aTrack->GetPosition();
    G4double charge = aTrack->GetDefinition()->GetPDGCharge();
    G4double energy = aTrack->GetKineticEnergy();

    // Extract Projected Range of primary particle
    if (aTrack->GetTrackID() == 1) {
        G4double x = position.x() + 0.5*fDetector->GetMultiLayerSizeX();
        if (x > 0.0) run->AddProjRange(x);
        fEventAction->SetProjRange(x);
    }

    G4bool transmit = (((fDirX >= 0.0 && position.x() >= fXendAbs) ||
                        (fDirX < 0.0 && position.x() <= fXstartAbs))
                       && energy > 0.0);
    G4bool reflect = (((fDirX >= 0.0 && position.x() <= fXstartAbs) ||
                       (fDirX < 0.0 && position.x() <= fXendAbs))
                      && energy > 0.0);
    G4bool notabsor = (transmit || reflect);

    // transmitted + reflected particles counter
    G4int flag = 0;
    if (charge == fPrimaryCharge) flag = 1;
    if (aTrack->GetTrackID() == 1) flag = 2;
    if (transmit) fEventAction->SetTransmitFlag(flag);
    if (reflect) fEventAction->SetReflectFlag(flag);

    // Histograms

    G4bool charged = (charge != 0.);
    // Neutrons are counted on their own, not among the neutrals.  One set
    // of spectra for both put the capture gammas of a hydrogenous target
    // in with the neutrons that made them, a third of the entries
    G4bool neutron = (aTrack->GetDefinition() == G4Neutron::Neutron());
    G4bool neutral = !charged && !neutron;

    // Energy spectrum at exit
    // zero energy charged particle are not taken into account
    G4int id = 0;
    if (transmit && charged) id = 20;
    else if (transmit && neutral) id = 30;
    else if (transmit && neutron) id = kStrataH1NeutronTransmitted + 0;
    else if (reflect && charged) id = 40;
    else if (reflect && neutral) id = 50;
    else if (reflect && neutron) id = kStrataH1NeutronReflected + 0;

    if (id > 0) { analysisManager->FillH1(id, energy); }

    // Energy leakage
    if (notabsor) {
        G4int trackID = aTrack->GetTrackID();
        G4int index = 0;
        if (trackID > 1) index = 1;    //primary=0, secondaries=1
        G4double eleak = aTrack->GetKineticEnergy();
        if ((aTrack->GetDefinition() == G4Positron::Positron()) && (trackID > 1))
            eleak += 2*electron_mass_c2;
        run->AddEnergyLeak(eleak, index);
    }

    // Space angle distribution at exit : dN/dOmega
    const G4ThreeVector& direction = aTrack->GetMomentumDirection();
    id = 0;
    if (transmit && charged) id = 22;
    else if (transmit && neutral) id = 32;
    else if (transmit && neutron) id = kStrataH1NeutronTransmitted + 2;
    else if (reflect && charged) id = 42;
    else if (reflect && neutral) id = 52;
    else if (reflect && neutron) id = kStrataH1NeutronReflected + 2;

    if (id > 0) {
        G4double theta = std::acos(direction.x());
        if (theta > 0.0) {
            // The width comes in the axis unit; in radians it is width*unit,
            // so the spectrum is per steradian whatever the axis is in
            G4double dteta = analysisManager->GetH1Width(id)*analysisManager->GetH1Unit(id);
            G4double weight = 1./(twopi*std::sin(theta)*dteta);

            analysisManager->FillH1(id, theta, weight);
        }
    }

    // Energy fluence at exit : dE(MeV)/dOmega
    id = 0;
    if (transmit && charged) id = 21;
    else if (transmit && neutral) id = 31;
    else if (transmit && neutron) id = kStrataH1NeutronTransmitted + 1;
    else if (reflect && charged) id = 41;
    else if (reflect && neutral) id = 51;
    else if (reflect && neutron) id = kStrataH1NeutronReflected + 1;

    if (id > 0) {
        G4double theta = std::acos(direction.x());
        if (theta > 0.0) {
            // The width comes in the axis unit; in radians it is width*unit,
            // so the spectrum is per steradian whatever the axis is in
            G4double dteta = analysisManager->GetH1Width(id)*analysisManager->GetH1Unit(id);
            G4double weight = 1./(twopi*std::sin(theta)*dteta);
            weight *= (aTrack->GetKineticEnergy()/MeV);
            analysisManager->FillH1(id, theta, weight);
        }
    }

    // Projected angles distribution at exit
    id = 0;
    if (transmit && charged) id = 23;
    else if (transmit && neutral) id = 33;
    else if (transmit && neutron) id = kStrataH1NeutronTransmitted + 3;
    else if (reflect && charged) id = 43;
    else if (reflect && neutral) id = 53;
    else if (reflect && neutron) id = kStrataH1NeutronReflected + 3;

    if (id > 0) {
        if (direction.x() != 0.0) {
            G4double tet = std::atan(direction.y()/std::fabs(direction.x()));
            analysisManager->FillH1(id, tet);
            if (transmit && (flag == 2)) run->AddMscProjTheta(tet);

            tet = std::atan(direction.z()/std::fabs(direction.x()));
            analysisManager->FillH1(id, tet);
            if (transmit && (flag == 2)) run->AddMscProjTheta(tet);
        }
    }

    // Projected position and radius at exit
    if (transmit && energy > 0.0) {
        G4double y = position.y(), z = position.z();
        G4double r = std::sqrt(y*y + z*z);
        analysisManager->FillH1(24, y);
        analysisManager->FillH1(24, z);
        analysisManager->FillH1(25, r);
    }

    // X-vertex of charged secondaries
    if ((aTrack->GetParentID() == 1) && charged && energy > 0.0) {
        G4double xVertex = (aTrack->GetVertexPosition()).x();
        analysisManager->FillH1(15, xVertex);
        if (notabsor) analysisManager->FillH1(16, xVertex);
    }
}

//==============================================================================
