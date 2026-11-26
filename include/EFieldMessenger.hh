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
/// \file Strata/include/EFieldMessenger.hh
/// \brief Definition of the EFieldMessenger class
//
//
//
//
//==============================================================================
//==============================================================================

#ifndef EFieldMessenger_h
#define EFieldMessenger_h 1

#include "G4UImessenger.hh"

class EFieldSetup;
class G4UIdirectory;
class G4UIcmdWithAnInteger;
class G4UIcmdWithADoubleAndUnit;
class G4UIcmdWith3VectorAndUnit;
class G4UIcmdWithoutParameter;

//==============================================================================

class EFieldMessenger: public G4UImessenger {
public:
    EFieldMessenger(EFieldSetup*);
    virtual ~EFieldMessenger();

    virtual void SetNewValue(G4UIcommand*, G4String);

private:

    EFieldSetup* fEFieldSetup;

    G4UIdirectory* fEFieldDir;
    G4UIcmdWithAnInteger* fEFieldStepperCmd;
    G4UIcmdWith3VectorAndUnit* fEFieldCmd;
    G4UIcmdWithADoubleAndUnit* fEFieldMinStepCmd;
    G4UIcmdWithoutParameter* fEFieldUpdateCmd;
};

#endif
