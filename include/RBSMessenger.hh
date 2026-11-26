//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
/// \file Strata/include/RBSMessenger.hh
/// \brief The /strata/rbs/ commands.

#ifndef RBSMessenger_h
#define RBSMessenger_h 1

#include "G4UImessenger.hh"
#include "globals.hh"

class RBSDetector;
class G4UIdirectory;
class G4UIcmdWithABool;
class G4UIcmdWithADoubleAndUnit;

//==============================================================================

class RBSMessenger : public G4UImessenger {
public:
    explicit RBSMessenger(RBSDetector*);
    ~RBSMessenger() override;

    void SetNewValue(G4UIcommand*, G4String) override;

private:
    RBSDetector* fRBS;

    G4UIdirectory*             fRBSDir;
    G4UIcmdWithABool*          fEnableCmd;
    G4UIcmdWithADoubleAndUnit* fAngleCmd;
    G4UIcmdWithADoubleAndUnit* fSolidAngleCmd;
    G4UIcmdWithADoubleAndUnit* fResolutionCmd;
    G4UIcmdWithADoubleAndUnit* fTiltCmd;
    G4UIcmdWithABool*          fScreeningCmd;
};

//==============================================================================

#endif
