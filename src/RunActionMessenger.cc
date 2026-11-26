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
/// \file Strata/src/RunActionMessenger.cc
/// \brief Implementation of the RunActionMessenger class
//
//
//==============================================================================
//==============================================================================

#include "RunActionMessenger.hh"
#include "RunAction.hh"

#include "G4UIdirectory.hh"
#include "G4UIcmdWithAString.hh"
#include "G4UIcmdWithABool.hh"

//==============================================================================

RunActionMessenger::RunActionMessenger(RunAction* RunAct) :
        G4UImessenger(),
        fRunAction(RunAct),
        fWriteHistCmd(nullptr),
        fSavePrimCmd(nullptr),
        fSaveCascCmd(nullptr),
        fPrimNameCmd(nullptr),
        fCascNameCmd(nullptr) {
    fOutFilesDir = new G4UIdirectory("/strata/files/");
    fOutFilesDir->SetGuidance("File output commands.");

    fWriteHistCmd = new G4UIcmdWithABool("/strata/files/writeHistograms", this);
    fWriteHistCmd->SetGuidance("Write the histograms to the analysis file at");
    fWriteHistCmd->SetGuidance("the end of a run.  On for the batch program,");
    fWriteHistCmd->SetGuidance("off when a front end drives the library, which");
    fWriteHistCmd->SetGuidance("reads them out of memory instead.");
    fWriteHistCmd->SetParameterName("writeHist", true);
    fWriteHistCmd->SetDefaultValue(true);
    fWriteHistCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fSavePrimCmd = new G4UIcmdWithABool("/strata/files/savePrimaries",this);
    fSavePrimCmd->SetGuidance("Save primaries file.");
    fSavePrimCmd->SetParameterName("savePrim",false);
    fSavePrimCmd->SetDefaultValue(true);
    fSavePrimCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fSaveCascCmd = new G4UIcmdWithABool("/strata/files/saveCascades",this);
    fSaveCascCmd->SetGuidance("Save cascades file.");
    fSaveCascCmd->SetParameterName("saveCasc",false);
    fSaveCascCmd->SetDefaultValue(true);
    fSaveCascCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fPrimNameCmd = new G4UIcmdWithAString("/strata/files/setPrimariesName", this);
    fPrimNameCmd->SetGuidance("Set name of primaries file.");
    fPrimNameCmd->SetParameterName("PName", false);
    fPrimNameCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fCascNameCmd = new G4UIcmdWithAString("/strata/files/setCascadesName", this);
    fCascNameCmd->SetGuidance("Set name of cascades file.");
    fCascNameCmd->SetParameterName("CName", false);
    fCascNameCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
}

//==============================================================================

RunActionMessenger::~RunActionMessenger() {
    delete fWriteHistCmd;
    delete fSavePrimCmd;
    delete fSaveCascCmd;
    delete fPrimNameCmd;
    delete fCascNameCmd;
    delete fOutFilesDir;
}

//==============================================================================

void RunActionMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fWriteHistCmd) {
        // Process-wide, so one command covers master and workers alike
        RunAction::SetWriteHistograms(
            G4UIcmdWithABool::GetNewBoolValue(newValue));
    }

    if (command == fSavePrimCmd) {
        fRunAction->SetSavePrimaries(G4UIcmdWithABool::GetNewBoolValue(newValue));
    }

    if (command == fSaveCascCmd) {
        fRunAction->SetSaveCascades(G4UIcmdWithABool::GetNewBoolValue(newValue));
    }

    if (command == fPrimNameCmd) {
        fRunAction->SetPrimariesName(newValue);
    }

    if (command == fCascNameCmd) {
        fRunAction->SetCascadesName(newValue);
    }
}

//==============================================================================
