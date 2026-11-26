//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/src/DamageMessenger.cc
// \brief Implementation of the DamageMessenger class

#include "DamageMessenger.hh"
#include "DamageCalculator.hh"

#include "G4UIdirectory.hh"
#include "G4UIcmdWithABool.hh"
#include "G4UIcmdWithoutParameter.hh"
#include "G4UIcommand.hh"
#include "G4UIparameter.hh"
#include "G4SystemOfUnits.hh"

#include <sstream>

//==============================================================================

DamageMessenger::DamageMessenger(DamageCalculator* damage)
        : G4UImessenger(), fDamage(damage),
          fDir(nullptr),
          fEnableCmd(nullptr),
          fEdCmd(nullptr),
          fArcCmd(nullptr),
          fPrintCmd(nullptr) {
    fDir = new G4UIdirectory("/strata/damage/");
    fDir->SetGuidance("Displacement damage.");

    // The object is shared by every thread, so only the master sets it

    fEnableCmd = new G4UIcmdWithABool("/strata/damage/enable", this);
    fEnableCmd->SetGuidance("Count displacements into h1[4], h1[5] and h1[6].");
    fEnableCmd->SetParameterName("enable", true);
    fEnableCmd->SetDefaultValue(true);
    fEnableCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fEnableCmd->SetToBeBroadcasted(false);

    fEdCmd = new G4UIcommand("/strata/damage/setEd", this);
    fEdCmd->SetGuidance("Threshold displacement energy of a material.");
    fEdCmd->SetGuidance("  material name, value, unit");
    auto* edMat = new G4UIparameter("material", 's', false);
    fEdCmd->SetParameter(edMat);
    auto* edVal = new G4UIparameter("Ed", 'd', false);
    edVal->SetParameterRange("Ed>0.");
    fEdCmd->SetParameter(edVal);
    auto* edUnit = new G4UIparameter("unit", 's', true);
    edUnit->SetParameterCandidates(G4UIcommand::UnitsList(G4UIcommand::CategoryOf("eV")));
    edUnit->SetDefaultValue("eV");
    fEdCmd->SetParameter(edUnit);
    fEdCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fEdCmd->SetToBeBroadcasted(false);

    fArcCmd = new G4UIcommand("/strata/damage/setArc", this);
    fArcCmd->SetGuidance("Arc-dpa constants of a material.");
    fArcCmd->SetGuidance("  material name, b, c");
    auto* arcMat = new G4UIparameter("material", 's', false);
    fArcCmd->SetParameter(arcMat);
    auto* arcB = new G4UIparameter("b", 'd', false);
    arcB->SetParameterRange("b<=0.");
    fArcCmd->SetParameter(arcB);
    auto* arcC = new G4UIparameter("c", 'd', false);
    arcC->SetParameterRange("c>=0. && c<=1.");
    fArcCmd->SetParameter(arcC);
    fArcCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fArcCmd->SetToBeBroadcasted(false);

    fPrintCmd = new G4UIcmdWithoutParameter("/strata/damage/print", this);
    fPrintCmd->SetGuidance("List the constants in use.");
    fPrintCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fPrintCmd->SetToBeBroadcasted(false);
}

//==============================================================================

DamageMessenger::~DamageMessenger() {
    delete fEnableCmd;
    delete fEdCmd;
    delete fArcCmd;
    delete fPrintCmd;
    delete fDir;
}

//==============================================================================

void DamageMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fEnableCmd)
        fDamage->SetEnabled(G4UIcmdWithABool::GetNewBoolValue(newValue));

    if (command == fEdCmd) {
        G4String material, unit;
        G4double value = 0.;
        std::istringstream is(newValue);
        is >> material >> value >> unit;
        fDamage->SetDisplacementEnergy(material,
                                       value*G4UIcommand::ValueOf(unit));
    }

    if (command == fArcCmd) {
        G4String material;
        G4double b = 0., c = 0.;
        std::istringstream is(newValue);
        is >> material >> b >> c;
        fDamage->SetArcConstants(material, b, c);
    }

    if (command == fPrintCmd) fDamage->Print();
}
