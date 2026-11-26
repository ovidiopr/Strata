//==============================================================================
//
//  RandomMessenger.hh: the /strata/random/ commands.
//
//==============================================================================

#ifndef RandomMessenger_h
#define RandomMessenger_h 1

#include "G4UImessenger.hh"
#include "globals.hh"

class RandomSetup;
class G4UIdirectory;
class G4UIcmdWithAString;
class G4UIcmdWithABool;
class G4UIcommand;

class RandomMessenger : public G4UImessenger {
public:
    explicit RandomMessenger(RandomSetup*);
    ~RandomMessenger() override;

    void SetNewValue(G4UIcommand*, G4String) override;

private:
    RandomSetup* fSetup;

    G4UIdirectory*      fDirectory;
    G4UIcmdWithAString* fEngineCmd;
    G4UIcommand*        fSeedsCmd;
    G4UIcmdWithABool*   fRandomizeCmd;
    G4UIcommand*        fPrintCmd;
};

#endif
