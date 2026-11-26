//==============================================================================
/// \file Strata/include/MaterialMessenger.hh
/// \brief UI commands for defining materials
///
///   /strata/material/create            <name> <density> <unit>
///   /strata/material/addMaterial       <name> <massFraction>
///   /strata/material/addElement        <symbol> <massFraction>
///   /strata/material/addElementByAtoms <symbol> <atoms>
///   /strata/material/build
///   /strata/material/cancel
///   /strata/material/list
///   /strata/material/print             <name>
///
/// A definition is opened by create, filled by the add commands and closed
/// by build, so a macro reads as
///
///   /strata/material/create Borosilicate 2.23 g/cm3
///   /strata/material/addMaterial G4_SILICON_DIOXIDE 0.81
///   /strata/material/addMaterial G4_BORON_OXIDE     0.13
///   /strata/material/addMaterial G4_SODIUM_MONOXIDE 0.04
///   /strata/material/addMaterial G4_ALUMINUM_OXIDE  0.02
///   /strata/material/build
///
/// The commands are not broadcast to worker threads: the material table is
/// shared, so the master defines a material once for all of them.
//==============================================================================

#ifndef MaterialMessenger_h
#define MaterialMessenger_h 1

#include "G4UImessenger.hh"
#include "globals.hh"

class G4UIdirectory;
class G4UIcommand;
class G4UIcmdWithAString;
class G4UIcmdWithoutParameter;

//==============================================================================

class MaterialMessenger : public G4UImessenger {
public:
    MaterialMessenger();
    ~MaterialMessenger() override;

    void SetNewValue(G4UIcommand*, G4String) override;

private:
    G4UIdirectory*           fMatDir;
    G4UIcommand*             fCreateCmd;
    G4UIcommand*             fAddMaterialCmd;
    G4UIcommand*             fAddElementCmd;
    G4UIcommand*             fAddAtomsCmd;
    G4UIcmdWithoutParameter* fBuildCmd;
    G4UIcmdWithoutParameter* fCancelCmd;
    G4UIcmdWithoutParameter* fListCmd;
    G4UIcmdWithAString*      fPrintCmd;
};

#endif
