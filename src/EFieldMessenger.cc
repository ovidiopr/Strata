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
/// \file Strata/src/EFieldMessenger.cc
/// \brief Implementation of the EFieldMessenger class
//
//
//
//
//==============================================================================
//==============================================================================

#include "EFieldMessenger.hh"

#include "EFieldSetup.hh"
#include "G4UIcmdWithAnInteger.hh"
#include "G4UIcmdWithADoubleAndUnit.hh"
#include "G4UIcmdWith3VectorAndUnit.hh"
#include "G4UIcmdWithoutParameter.hh"

#include "G4SystemOfUnits.hh"

//==============================================================================

EFieldMessenger::EFieldMessenger(EFieldSetup* fieldSetup)
        : G4UImessenger(),
          fEFieldSetup(fieldSetup),
          fEFieldDir(nullptr),
          fEFieldStepperCmd(nullptr),
          fEFieldCmd(nullptr),
          fEFieldMinStepCmd(nullptr),
          fEFieldUpdateCmd(nullptr) {
    fEFieldDir = new G4UIdirectory("/strata/EField/");
    fEFieldDir->SetGuidance("Strata's electric field tracking control.");

    fEFieldStepperCmd = new G4UIcmdWithAnInteger("/strata/EField/setStepperType", this);
    fEFieldStepperCmd->SetGuidance("Select stepper type for electric field");
    fEFieldStepperCmd->SetParameterName("choice", true);
    fEFieldStepperCmd->SetDefaultValue(4);
    fEFieldStepperCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fEFieldUpdateCmd = new G4UIcmdWithoutParameter("/strata/EField/update", this);
    fEFieldUpdateCmd->SetGuidance("Update calorimeter geometry.");
    fEFieldUpdateCmd->SetGuidance("This command MUST be applied before \"beamOn\" ");
    fEFieldUpdateCmd->SetGuidance("if you changed geometrical value(s).");
    fEFieldUpdateCmd->AvailableForStates(G4State_Idle);

    fEFieldCmd = new G4UIcmdWith3VectorAndUnit("/strata/EField/setValue", this);
    fEFieldCmd->SetGuidance("Define uniform Electric field.");
    fEFieldCmd->SetGuidance("Value of Electric field has to be given in volt/m");
    fEFieldCmd->SetParameterName("Ex", "Ey", "Ez", false, false);
    fEFieldCmd->SetDefaultUnit("volt/m");
    fEFieldCmd->AvailableForStates(G4State_Idle);

    fEFieldMinStepCmd = new G4UIcmdWithADoubleAndUnit("/strata/EField/setMinStep", this);
    fEFieldMinStepCmd->SetGuidance("Define minimal step");
    fEFieldMinStepCmd->SetParameterName("min step", false, false);
    fEFieldMinStepCmd->SetDefaultUnit("mm");
    fEFieldMinStepCmd->AvailableForStates(G4State_Idle);
}

//==============================================================================

EFieldMessenger::~EFieldMessenger() {
    delete fEFieldStepperCmd;
    delete fEFieldCmd;
    delete fEFieldMinStepCmd;
    delete fEFieldDir;
}

//==============================================================================

void EFieldMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fEFieldStepperCmd)
        fEFieldSetup->SetStepperType(G4UIcmdWithAnInteger::GetNewIntValue(newValue));
    if (command == fEFieldUpdateCmd)
        fEFieldSetup->UpdateIntegrator();
    if (command == fEFieldCmd)
        fEFieldSetup->SetFieldValue(G4UIcmdWith3VectorAndUnit::GetNew3VectorValue(newValue));
    if (command == fEFieldMinStepCmd)
        fEFieldSetup->SetMinStep(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue));
}

//==============================================================================
