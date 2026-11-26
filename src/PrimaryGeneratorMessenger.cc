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
/// \file Strata/src/PrimaryGeneratorMessenger.cc
/// \brief Implementation of the PrimaryGeneratorMessenger class
//
//
//==============================================================================
//==============================================================================

#include "PrimaryGeneratorMessenger.hh"
#include "PrimaryGeneratorAction.hh"

#include "G4UIdirectory.hh"
#include "G4UIcmdWithoutParameter.hh"
#include "G4UIcmdWithADoubleAndUnit.hh"
#include "G4UIcmdWithAString.hh"
#include "G4SystemOfUnits.hh"

#include <cstdlib>

//==============================================================================

PrimaryGeneratorMessenger::PrimaryGeneratorMessenger(PrimaryGeneratorAction* Gun)
        : G4UImessenger(), fAction(Gun),
          fGunDir(nullptr),
          fRndmCmd(nullptr),
          fAngleCmd(nullptr) {
    fGunDir = new G4UIdirectory("/strata/gun/");
    fGunDir->SetGuidance("Gun control.");

    fDefaultCmd = new G4UIcmdWithoutParameter("/strata/gun/setDefault", this);
    fDefaultCmd->SetGuidance("Set/reset the kinematic defined in PrimaryGenerator.");
    fDefaultCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fRndmCmd = new G4UIcmdWithADoubleAndUnit("/strata/gun/rndBeam", this);
    fRndmCmd->SetGuidance("Random lateral extension on the beam.");
    fRndmCmd->SetParameterName("rBeam", false);
    fRndmCmd->SetRange("rBeam>=0.");
    fRndmCmd->SetUnitCategory("Length");
    fRndmCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    // One angle, not three components.  The geometry is a stack of slabs
    // normal to x and symmetric about it, so the only thing a direction can
    // say that matters is how far it leans away from the normal; the plane
    // it leans in is a free choice, and x-y is as good as any.  The sign is
    // kept so that a tilt one way can be told from the other, which the RBS
    // exit path cares about
    fAngleCmd = new G4UIcmdWithADoubleAndUnit("/strata/gun/angle", this);
    fAngleCmd->SetGuidance("Angle of the beam to the x axis, in the x-y plane.");
    fAngleCmd->SetGuidance("  The gun moves with it, so the beam still arrives");
    fAngleCmd->SetGuidance("  at the centre of the entrance face.");
    fAngleCmd->SetParameterName("angle", false);
    fAngleCmd->SetRange("angle>-90. && angle<90.");
    fAngleCmd->SetDefaultUnit("deg");
    fAngleCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fChargeCmd = new G4UIcmdWithAString("/strata/gun/charge", this);
    fChargeCmd->SetGuidance("Charge state of the beam, in units of e, or auto.");
    fChargeCmd->SetGuidance("  Overrides the one /gun/ion sets, which cannot be negative.");
    fChargeCmd->SetGuidance("  In vacuum the beam keeps it; in matter it takes the");
    fChargeCmd->SetGuidance("  effective charge, and keeps that in vacuum afterwards.");
    fChargeCmd->SetGuidance("  auto: the charge the gun has (Z for /gun/ion without one).");
    fChargeCmd->SetParameterName("q", false);
    fChargeCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
}

//==============================================================================

PrimaryGeneratorMessenger::~PrimaryGeneratorMessenger() {
    delete fDefaultCmd;
    delete fRndmCmd;
    delete fAngleCmd;
    delete fChargeCmd;
    delete fGunDir;
}

//==============================================================================

void PrimaryGeneratorMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fDefaultCmd)
    {fAction->SetDefaultKinematic();}
    if (command == fRndmCmd) { fAction->SetRndmBeam(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue)); }
    if (command == fAngleCmd) { fAction->SetBeamAngle(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue)); }
    if (command == fChargeCmd) {
        G4String v = newValue;
        G4StrUtil::strip(v);
        if (v == "auto") {
            fAction->ClearChargeState();
        } else {
            char* end = nullptr;
            const G4double q = std::strtod(v.c_str(), &end);
            if (end == v.c_str() || *end != '\0') {
                G4ExceptionDescription ed;
                ed << "charge state '" << v << "' is neither a number nor auto";
                command->CommandFailed(ed);
            } else {
                fAction->SetChargeState(q);
            }
        }
    }
}

//==============================================================================

