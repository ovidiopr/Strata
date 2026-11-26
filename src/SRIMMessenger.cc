//==============================================================================
/// \file Strata/src/SRIMMessenger.cc
/// \brief Implementation of the SRIMMessenger class
//==============================================================================

#include "SRIMMessenger.hh"

#include "SRIMStoppingData.hh"

#include "G4UIcmdWithoutParameter.hh"
#include "G4UIcommand.hh"
#include "G4UIdirectory.hh"
#include "G4UIparameter.hh"

#include <sstream>

//==============================================================================

SRIMMessenger::SRIMMessenger()
        : G4UImessenger(),
          fDir(nullptr), fLoadCmd(nullptr),
          fListCmd(nullptr), fClearCmd(nullptr) {

    fDir = new G4UIdirectory("/strata/physics/srim/");
    fDir->SetGuidance("External electronic stopping powers for the 'srim' "
                      "physics list.");

    fLoadCmd = new G4UIcommand("/strata/physics/srim/loadTable", this);
    fLoadCmd->SetGuidance("Load an electronic stopping-power table.");
    fLoadCmd->SetGuidance("  particle: Geant4 particle name, e.g. proton, "
                          "alpha, or GenericIon to cover every ion");
    fLoadCmd->SetGuidance("  material: Geant4 material name, e.g. "
                          "G4_SILICON_DIOXIDE");
    fLoadCmd->SetGuidance("  file: SRIM 'Stopping and Range Tables' output, "
                          "or a columnar file with a '# energy_unit' and "
                          "'# dedx_unit' header");
    fLoadCmd->SetGuidance("Must be issued before /run/initialize.");

    auto* particlePrm = new G4UIparameter("particle", 's', false);
    particlePrm->SetGuidance("projectile name");
    fLoadCmd->SetParameter(particlePrm);

    auto* materialPrm = new G4UIparameter("material", 's', false);
    materialPrm->SetGuidance("target material name");
    fLoadCmd->SetParameter(materialPrm);

    auto* filePrm = new G4UIparameter("file", 's', false);
    filePrm->SetGuidance("path to the table");
    fLoadCmd->SetParameter(filePrm);

    fLoadCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fListCmd = new G4UIcmdWithoutParameter("/strata/physics/srim/list", this);
    fListCmd->SetGuidance("Report the loaded tables, and which "
                          "particle/material pairs have been served from a "
                          "table rather than from Geant4.");
    fListCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fClearCmd = new G4UIcmdWithoutParameter("/strata/physics/srim/clear", this);
    fClearCmd->SetGuidance("Discard every loaded table.");
    fClearCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
}

//==============================================================================

SRIMMessenger::~SRIMMessenger() {
    delete fLoadCmd;
    delete fListCmd;
    delete fClearCmd;
    delete fDir;
}

//==============================================================================

void SRIMMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fLoadCmd) {
        std::istringstream is(newValue);
        G4String particle, material, file;
        is >> particle >> material >> file;

        G4String error;
        if (!SRIMStoppingData::Instance().LoadFile(particle, material, file,
                                                   error)) {
            G4ExceptionDescription ed;
            ed << "could not load the stopping table: " << error;
            G4Exception("SRIMMessenger::SetNewValue", "strata_srim01",
                        JustWarning, ed);
            // Make the command fail so that a front end or a macro notices.
            command->CommandFailed(ed);
        }

    } else if (command == fListCmd) {
        SRIMStoppingData::Instance().Print();

    } else if (command == fClearCmd) {
        SRIMStoppingData::Instance().Clear();
        G4cout << "Strata: external stopping tables cleared." << G4endl;
    }
}

//==============================================================================
