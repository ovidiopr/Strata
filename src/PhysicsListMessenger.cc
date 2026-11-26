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
/// \file Strata/src/PhysicsListMessenger.cc
/// \brief Implementation of the PhysicsListMessenger class
//
//
//==============================================================================
//==============================================================================

#include "PhysicsListMessenger.hh"

#include "G4ScreenedNuclearRecoil.hh"

#include "PhysicsList.hh"
#include "G4UIdirectory.hh"
#include "G4UIcmdWithAString.hh"
#include "G4UIcmdWithADoubleAndUnit.hh"

//==============================================================================

PhysicsListMessenger::PhysicsListMessenger(PhysicsList* phys)
        : G4UImessenger(), fPhysicsList(phys) {
    fPhysDir = new G4UIdirectory("/strata/physics/");
    fPhysDir->SetGuidance("Configuration of physics list");

    fListCmd = new G4UIcmdWithAString("/strata/physics/addPhysics", this);
    fListCmd->SetGuidance("Add modula physics list.");
    fListCmd->SetParameterName("PList", false);
    fListCmd->AvailableForStates(G4State_PreInit);

    fRecoilCmd = new G4UIcmdWithADoubleAndUnit("/strata/physics/recoilCutoff", this);
    fRecoilCmd->SetGuidance("Recoils above this energy always become moving atoms.");
    fRecoilCmd->SetGuidance("  0 leaves it to Geant4's cutoff of 100 eV per nucleon.");
    fRecoilCmd->SetParameterName("cutoff", false);
    fRecoilCmd->SetRange("cutoff >= 0.");
    fRecoilCmd->SetUnitCategory("Energy");
    fRecoilCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    // A static the workers only read
    fRecoilCmd->SetToBeBroadcasted(false);
}

//==============================================================================

PhysicsListMessenger::~PhysicsListMessenger() {
    delete fListCmd;
    delete fRecoilCmd;
    delete fPhysDir;
}

//==============================================================================

void PhysicsListMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fListCmd) { fPhysicsList->AddPhysicsList(newValue); }
    if (command == fRecoilCmd)
        G4ScreenedNuclearRecoil::SetRecoilThreshold(fRecoilCmd->GetNewDoubleValue(newValue));
}

//==============================================================================
