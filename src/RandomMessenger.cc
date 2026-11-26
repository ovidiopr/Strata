//==============================================================================
//
//  RandomMessenger.cc: see RandomMessenger.hh.
//
//==============================================================================

#include "RandomMessenger.hh"
#include "RandomSetup.hh"

#include "G4UIdirectory.hh"
#include "G4UIcmdWithAString.hh"
#include "G4UIcmdWithABool.hh"
#include "G4UIcommand.hh"
#include "G4UIparameter.hh"

#include <sstream>

//==============================================================================

RandomMessenger::RandomMessenger(RandomSetup* setup)
        : G4UImessenger(), fSetup(setup) {
    fDirectory = new G4UIdirectory("/strata/random/");
    fDirectory->SetGuidance("Pseudo-random generator and seeds.");

    G4String candidates;
    for (const G4String& name : RandomSetup::EngineNames()) {
        if (!candidates.empty()) candidates += " ";
        candidates += name;
    }

    fEngineCmd = new G4UIcmdWithAString("/strata/random/engine", this);
    fEngineCmd->SetGuidance("Select the pseudo-random generator.");
    fEngineCmd->SetGuidance("  ranecu   : two-stream combined generator (default)");
    fEngineCmd->SetGuidance("  mixmax   : matrix generator, long period");
    fEngineCmd->SetGuidance("  mtwist   : Mersenne twister");
    fEngineCmd->SetGuidance("  ranlux64 : RANLUX, 64 bit");
    fEngineCmd->SetGuidance("  ranluxpp : RANLUX++");
    fEngineCmd->SetGuidance("  james    : the generator Geant4 starts with");
    fEngineCmd->SetParameterName("engine", false);
    fEngineCmd->SetCandidates(candidates);
    fEngineCmd->AvailableForStates(G4State_PreInit);

    fSeedsCmd = new G4UIcommand("/strata/random/seeds", this);
    fSeedsCmd->SetGuidance("Fix the stream, making the next run reproducible.");
    fSeedsCmd->SetGuidance("Switches off the fresh seeds drawn for each run.");
    auto* seed1 = new G4UIparameter("seed1", 'l', false);
    seed1->SetGuidance("first seed, 1 .. 2147483562");
    fSeedsCmd->SetParameter(seed1);
    auto* seed2 = new G4UIparameter("seed2", 'l', false);
    seed2->SetGuidance("second seed, 1 .. 2147483562");
    fSeedsCmd->SetParameter(seed2);
    fSeedsCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fRandomizeCmd = new G4UIcmdWithABool("/strata/random/randomize", this);
    fRandomizeCmd->SetGuidance("Draw new seeds before every run (the default).");
    fRandomizeCmd->SetGuidance("The seeds in use are printed as the command "
                               "that repeats the run.");
    fRandomizeCmd->SetParameterName("randomize", true);
    fRandomizeCmd->SetDefaultValue(true);
    fRandomizeCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fPrintCmd = new G4UIcommand("/strata/random/print", this);
    fPrintCmd->SetGuidance("Print the generator and the seeds in use.");
    fPrintCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
}

//==============================================================================

RandomMessenger::~RandomMessenger() {
    delete fEngineCmd;
    delete fSeedsCmd;
    delete fRandomizeCmd;
    delete fPrintCmd;
    delete fDirectory;
}

//==============================================================================

void RandomMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fEngineCmd) fSetup->SetEngine(newValue);

    if (command == fSeedsCmd) {
        long s1 = 0, s2 = 0;
        std::istringstream is(newValue);
        is >> s1 >> s2;
        fSetup->SetSeeds(s1, s2);
        fSetup->Print();
    }

    if (command == fRandomizeCmd)
        fSetup->SetRandomize(fRandomizeCmd->GetNewBoolValue(newValue));

    if (command == fPrintCmd) fSetup->Print();
}
