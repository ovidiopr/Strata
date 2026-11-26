//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/include/DamageMessenger.hh
// \brief Commands of the /strata/damage/ directory

#ifndef DamageMessenger_h
#define DamageMessenger_h 1

#include "globals.hh"
#include "G4UImessenger.hh"

class DamageCalculator;
class G4UIdirectory;
class G4UIcmdWithABool;
class G4UIcmdWithoutParameter;
class G4UIcommand;

//==============================================================================

class DamageMessenger : public G4UImessenger {
public:
    explicit DamageMessenger(DamageCalculator*);
    ~DamageMessenger() override;

    void SetNewValue(G4UIcommand*, G4String) override;

private:
    DamageCalculator* fDamage;

    G4UIdirectory* fDir;
    G4UIcmdWithABool* fEnableCmd;
    G4UIcommand* fEdCmd;
    G4UIcommand* fArcCmd;
    G4UIcmdWithoutParameter* fPrintCmd;
};

//==============================================================================

#endif
