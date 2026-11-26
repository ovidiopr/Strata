//==============================================================================
/// \file Strata/include/SRIMMessenger.hh
/// \brief UI commands for the external stopping-power tables
///
///   /strata/physics/srim/loadTable <particle> <material> <file>
///   /strata/physics/srim/list
///   /strata/physics/srim/clear
///
/// The commands exist whatever physics list is selected, so a table can be
/// loaded before /strata/physics/addPhysics srim; only the srim list
/// consults them.
//==============================================================================

#ifndef SRIMMessenger_h
#define SRIMMessenger_h 1

#include "G4UImessenger.hh"
#include "globals.hh"

class G4UIdirectory;
class G4UIcommand;
class G4UIcmdWithoutParameter;

//==============================================================================

class SRIMMessenger : public G4UImessenger {
public:
    SRIMMessenger();
    ~SRIMMessenger() override;

    void SetNewValue(G4UIcommand*, G4String) override;

private:
    G4UIdirectory* fDir;
    G4UIcommand* fLoadCmd;
    G4UIcmdWithoutParameter* fListCmd;
    G4UIcmdWithoutParameter* fClearCmd;
};

//==============================================================================
#endif
