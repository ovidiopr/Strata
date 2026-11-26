//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
/// \file Strata/src/RBSMessenger.cc
/// \brief The /strata/rbs/ commands.

#include "RBSMessenger.hh"

#include "RBSDetector.hh"

#include "G4UIcmdWithABool.hh"
#include "G4UIcmdWithADoubleAndUnit.hh"
#include "G4UIdirectory.hh"

//==============================================================================

RBSMessenger::RBSMessenger(RBSDetector* rbs)
        : G4UImessenger(), fRBS(rbs) {
    fRBSDir = new G4UIdirectory("/strata/rbs/");
    fRBSDir->SetGuidance("Rutherford backscattering spectrometry.");

    // The object is shared by every thread, so only the master sets it

    fEnableCmd = new G4UIcmdWithABool("/strata/rbs/enable", this);
    fEnableCmd->SetGuidance("Collect an RBS spectrum into h1[80].");
    fEnableCmd->SetGuidance("The yield is computed at every step of the");
    fEnableCmd->SetGuidance("projectile rather than waited for, so a useful");
    fEnableCmd->SetGuidance("spectrum needs thousands of ions, not 1e12.");
    fEnableCmd->SetParameterName("enable", true);
    fEnableCmd->SetDefaultValue(true);
    fEnableCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fEnableCmd->SetToBeBroadcasted(false);

    fAngleCmd = new G4UIcmdWithADoubleAndUnit("/strata/rbs/angle", this);
    fAngleCmd->SetGuidance("Scattering angle of the detector.");
    fAngleCmd->SetParameterName("angle", false);
    fAngleCmd->SetRange("angle>0.");
    fAngleCmd->SetDefaultUnit("deg");
    fAngleCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fAngleCmd->SetToBeBroadcasted(false);

    fSolidAngleCmd = new G4UIcmdWithADoubleAndUnit("/strata/rbs/solidAngle", this);
    fSolidAngleCmd->SetGuidance("Solid angle the detector subtends.");
    fSolidAngleCmd->SetParameterName("solidAngle", false);
    fSolidAngleCmd->SetRange("solidAngle>0.");
    fSolidAngleCmd->SetDefaultUnit("msr");
    fSolidAngleCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fSolidAngleCmd->SetToBeBroadcasted(false);

    fResolutionCmd = new G4UIcmdWithADoubleAndUnit("/strata/rbs/resolution", this);
    fResolutionCmd->SetGuidance("Energy resolution of the detector, FWHM.");
    fResolutionCmd->SetGuidance("Zero records the energy with no broadening.");
    fResolutionCmd->SetParameterName("resolution", false);
    fResolutionCmd->SetRange("resolution>=0.");
    fResolutionCmd->SetDefaultUnit("keV");
    fResolutionCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fResolutionCmd->SetToBeBroadcasted(false);

    fTiltCmd = new G4UIcmdWithADoubleAndUnit("/strata/rbs/tilt", this);
    fTiltCmd->SetGuidance("Tilt of the sample, beam to surface normal.");
    fTiltCmd->SetParameterName("tilt", true);
    fTiltCmd->SetDefaultValue(0.);
    fTiltCmd->SetDefaultUnit("deg");
    fTiltCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fTiltCmd->SetToBeBroadcasted(false);

    fScreeningCmd = new G4UIcmdWithABool("/strata/rbs/screening", this);
    fScreeningCmd->SetGuidance("Apply Andersen's screening correction.");
    fScreeningCmd->SetGuidance("It matters below about 1 MeV and for heavy targets.");
    fScreeningCmd->SetParameterName("screening", true);
    fScreeningCmd->SetDefaultValue(true);
    fScreeningCmd->AvailableForStates(G4State_PreInit, G4State_Idle);
    fScreeningCmd->SetToBeBroadcasted(false);
}

//==============================================================================

RBSMessenger::~RBSMessenger() {
    delete fEnableCmd;
    delete fAngleCmd;
    delete fSolidAngleCmd;
    delete fResolutionCmd;
    delete fTiltCmd;
    delete fScreeningCmd;
    delete fRBSDir;
}

//==============================================================================

void RBSMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fEnableCmd)
        fRBS->SetEnabled(fEnableCmd->GetNewBoolValue(newValue));
    else if (command == fAngleCmd)
        fRBS->SetAngle(fAngleCmd->GetNewDoubleValue(newValue));
    else if (command == fSolidAngleCmd)
        fRBS->SetSolidAngle(fSolidAngleCmd->GetNewDoubleValue(newValue));
    else if (command == fResolutionCmd)
        fRBS->SetResolution(fResolutionCmd->GetNewDoubleValue(newValue));
    else if (command == fTiltCmd)
        fRBS->SetTilt(fTiltCmd->GetNewDoubleValue(newValue));
    else if (command == fScreeningCmd)
        fRBS->SetScreening(fScreeningCmd->GetNewBoolValue(newValue));
}

//==============================================================================
