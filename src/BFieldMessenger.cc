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
/// \file Strata/src/BFieldMessenger.cc
/// \brief Implementation of the BFieldMessenger class
//
//
//
//
//==============================================================================
//==============================================================================

#include "BFieldMessenger.hh"

#include "BFieldSetup.hh"
#include "G4UIcmdWithAnInteger.hh"
#include "G4UIcmdWithADoubleAndUnit.hh"
#include "G4UIcmdWith3VectorAndUnit.hh"
#include "G4UIcmdWithoutParameter.hh"

#include "G4SystemOfUnits.hh"

//==============================================================================

BFieldMessenger::BFieldMessenger(BFieldSetup* fieldSetup)
        : G4UImessenger(),
          fBFieldSetup(fieldSetup),
          fBFieldDir(nullptr),
          fBFieldStepperCmd(nullptr),
          fBFieldCmd(nullptr),
          fBFieldMinStepCmd(nullptr),
          fBFieldUpdateCmd(nullptr) {
    fBFieldDir = new G4UIdirectory("/strata/BField/");
    fBFieldDir->SetGuidance("Strata's magnetic field tracking control.");

    fBFieldStepperCmd = new G4UIcmdWithAnInteger("/strata/BField/setStepperType", this);
    fBFieldStepperCmd->SetGuidance("Select stepper type for magnetic field");
    fBFieldStepperCmd->SetParameterName("choice", true);
    fBFieldStepperCmd->SetDefaultValue(4);
    fBFieldStepperCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fBFieldUpdateCmd = new G4UIcmdWithoutParameter("/strata/BField/update", this);
    fBFieldUpdateCmd->SetGuidance("Update calorimeter geometry.");
    fBFieldUpdateCmd->SetGuidance("This command MUST be applied before \"beamOn\" ");
    fBFieldUpdateCmd->SetGuidance("if you changed geometrical value(s).");
    fBFieldUpdateCmd->AvailableForStates(G4State_Idle);

    fBFieldCmd = new G4UIcmdWith3VectorAndUnit("/strata/BField/setValue", this);
    fBFieldCmd->SetGuidance("Define magnetic field.");
    fBFieldCmd->SetParameterName("Bx", "By", "Bz", false, false);
    fBFieldCmd->SetDefaultUnit("tesla");
    fBFieldCmd->AvailableForStates(G4State_Idle);

    fBFieldMinStepCmd = new G4UIcmdWithADoubleAndUnit("/strata/BField/setMinStep", this);
    fBFieldMinStepCmd->SetGuidance("Define minimal step");
    fBFieldMinStepCmd->SetParameterName("min step", false, false);
    fBFieldMinStepCmd->SetDefaultUnit("mm");
    fBFieldMinStepCmd->AvailableForStates(G4State_Idle);
}

//==============================================================================

BFieldMessenger::~BFieldMessenger() {
    delete fBFieldStepperCmd;
    delete fBFieldCmd;
    delete fBFieldMinStepCmd;
    delete fBFieldDir;
    delete fBFieldUpdateCmd;
}

//==============================================================================

void BFieldMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fBFieldStepperCmd)
        fBFieldSetup->SetStepperType(G4UIcmdWithAnInteger::GetNewIntValue(newValue));
    if (command == fBFieldUpdateCmd)
        fBFieldSetup->CreateStepperAndChordFinder();
    if (command == fBFieldCmd)
        fBFieldSetup->SetFieldValue(G4UIcmdWith3VectorAndUnit::GetNew3VectorValue(newValue));
    if (command == fBFieldMinStepCmd)
        fBFieldSetup->SetMinStep(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue));
}

//==============================================================================
