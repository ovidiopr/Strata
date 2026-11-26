//==============================================================================
// \file Strata/src/MaterialMessenger.cc
// \brief Implementation of MaterialMessenger
//==============================================================================

#include "MaterialMessenger.hh"

#include <sstream>

#include "MaterialBuilder.hh"

#include "G4UIcmdWithAString.hh"
#include "G4UIcmdWithoutParameter.hh"
#include "G4UIcommand.hh"
#include "G4UIdirectory.hh"
#include "G4UIparameter.hh"
#include "G4UnitsTable.hh"

//==============================================================================

namespace {

// Every command here is master-only and legal both before and between runs
void Configure(G4UIcommand* cmd) {
    cmd->SetToBeBroadcasted(false);
    cmd->AvailableForStates(G4State_PreInit, G4State_Idle);
}

}  // namespace

//==============================================================================

MaterialMessenger::MaterialMessenger() {
    fMatDir = new G4UIdirectory("/strata/material/");
    fMatDir->SetGuidance("Definition of materials.");

    //--------------------------------------------------------------------
    fCreateCmd = new G4UIcommand("/strata/material/create", this);
    fCreateCmd->SetGuidance("Open the definition of a new material.");
    fCreateCmd->SetGuidance("  create <name> <density> <unit>");
    fCreateCmd->SetGuidance("Add its constituents with addMaterial, "
                            "addElement or addElementByAtoms, then close "
                            "the definition with build.");
    {
        auto* name = new G4UIparameter("name", 's', false);
        name->SetGuidance("Name of the new material; must not be taken.");
        fCreateCmd->SetParameter(name);

        auto* density = new G4UIparameter("density", 'd', false);
        density->SetGuidance("Density, greater than zero.");
        fCreateCmd->SetParameter(density);

        auto* unit = new G4UIparameter("unit", 's', true);
        unit->SetGuidance("Unit of the density.");
        unit->SetParameterCandidates(G4UIcommand::UnitsList(G4UIcommand::CategoryOf("g/cm3")));
        unit->SetDefaultValue("g/cm3");
        fCreateCmd->SetParameter(unit);
    }
    Configure(fCreateCmd);

    //--------------------------------------------------------------------
    fAddMaterialCmd = new G4UIcommand("/strata/material/addMaterial", this);
    fAddMaterialCmd->SetGuidance("Add an existing material as a constituent, "
                                 "by mass fraction.");
    fAddMaterialCmd->SetGuidance("  addMaterial <name> <massFraction>");
    fAddMaterialCmd->SetGuidance("The name may be a NIST material, one of "
                                 "Strata's own, or one defined earlier here.");
    {
        auto* name = new G4UIparameter("material", 's', false);
        fAddMaterialCmd->SetParameter(name);

        auto* fraction = new G4UIparameter("massFraction", 'd', false);
        fraction->SetGuidance("Mass fraction in (0, 1]; the fractions of a "
                              "material have to add up to 1.");
        fAddMaterialCmd->SetParameter(fraction);
    }
    Configure(fAddMaterialCmd);

    //--------------------------------------------------------------------
    fAddElementCmd = new G4UIcommand("/strata/material/addElement", this);
    fAddElementCmd->SetGuidance("Add a chemical element as a constituent, "
                                "by mass fraction.");
    fAddElementCmd->SetGuidance("  addElement <symbol> <massFraction>");
    {
        auto* symbol = new G4UIparameter("symbol", 's', false);
        symbol->SetGuidance("Element symbol, for instance Si or Fe.");
        fAddElementCmd->SetParameter(symbol);

        auto* fraction = new G4UIparameter("massFraction", 'd', false);
        fAddElementCmd->SetParameter(fraction);
    }
    Configure(fAddElementCmd);

    //--------------------------------------------------------------------
    fAddAtomsCmd = new G4UIcommand("/strata/material/addElementByAtoms", this);
    fAddAtomsCmd->SetGuidance("Add a chemical element as a constituent, by number "
                              "of atoms, the way a chemical formula is written.");
    fAddAtomsCmd->SetGuidance("  addElementByAtoms <symbol> <atoms>");
    fAddAtomsCmd->SetGuidance("Si 3 and N 4 give Si3N4.  A material is "
                              "defined either by atoms or by mass fractions; "
                              "the two cannot be combined.");
    {
        auto* symbol = new G4UIparameter("symbol", 's', false);
        fAddAtomsCmd->SetParameter(symbol);

        auto* atoms = new G4UIparameter("atoms", 'i', false);
        atoms->SetGuidance("Number of atoms, at least one.");
        fAddAtomsCmd->SetParameter(atoms);
    }
    Configure(fAddAtomsCmd);

    //--------------------------------------------------------------------
    fBuildCmd = new G4UIcmdWithoutParameter("/strata/material/build", this);
    fBuildCmd->SetGuidance("Check the open definition and create the "
                           "material.");
    fBuildCmd->SetGuidance("Nothing is created if it does not add up; the "
                           "definition stays open so it can be corrected.");
    Configure(fBuildCmd);

    fCancelCmd = new G4UIcmdWithoutParameter("/strata/material/cancel", this);
    fCancelCmd->SetGuidance("Throw away the definition in progress.");
    Configure(fCancelCmd);

    fListCmd = new G4UIcmdWithoutParameter("/strata/material/list", this);
    fListCmd->SetGuidance("List every material currently defined.");
    Configure(fListCmd);

    fPrintCmd = new G4UIcmdWithAString("/strata/material/print", this);
    fPrintCmd->SetGuidance("Print one material in full.");
    fPrintCmd->SetParameterName("name", false);
    Configure(fPrintCmd);
}

//==============================================================================

MaterialMessenger::~MaterialMessenger() {
    delete fPrintCmd;
    delete fListCmd;
    delete fCancelCmd;
    delete fBuildCmd;
    delete fAddAtomsCmd;
    delete fAddElementCmd;
    delete fAddMaterialCmd;
    delete fCreateCmd;
    delete fMatDir;
}

//==============================================================================

void MaterialMessenger::SetNewValue(G4UIcommand* command, G4String value) {
    MaterialBuilder* builder = MaterialBuilder::Instance();

    if (command == fCreateCmd) {
        G4String name;
        G4String unit;
        G4double density = 0.;
        std::istringstream is(value);
        is >> name >> density >> unit;
        builder->Begin(name, density*G4UIcommand::ValueOf(unit));

    } else if (command == fAddMaterialCmd) {
        G4String name;
        G4double fraction = 0.;
        std::istringstream is(value);
        is >> name >> fraction;
        builder->AddMaterial(name, fraction);

    } else if (command == fAddElementCmd) {
        G4String symbol;
        G4double fraction = 0.;
        std::istringstream is(value);
        is >> symbol >> fraction;
        builder->AddElement(symbol, fraction);

    } else if (command == fAddAtomsCmd) {
        G4String symbol;
        G4int atoms = 0;
        std::istringstream is(value);
        is >> symbol >> atoms;
        builder->AddElementByAtoms(symbol, atoms);

    } else if (command == fBuildCmd) {
        builder->Build();

    } else if (command == fCancelCmd) {
        builder->Cancel();

    } else if (command == fListCmd) {
        builder->List();

    } else if (command == fPrintCmd) {
        builder->Print(value);
    }
}
