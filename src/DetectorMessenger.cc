//
// ********************************************************************
// * License and Disclaimer                                           *
// *                                                                  *
// * The  Geant4 software  is  copyright of the Copyright Holders  of *
// * the Geant4 Collaboration.  It is provided  under  the terms  and *
// * conditions of the Geant4 Software License,  included in the file *
// * LICENSE and available at  http://cern.ch/geant4/license .  These *
// * include a list of copyright holders.                             *
// *                                                                  *
// * Neither the authors of this software system, nor their employing *
// * institutes,nor the agencies providing financial support for this *
// * work  make  any representation or  warranty, express or implied, *
// * regarding  this  software system or assume any liability for its *
// * use.  Please see the license in the file  LICENSE  and URL above *
// * for the full disclaimer and the limitation of liability.         *
// *                                                                  *
// * This  code  implementation is the result of  the  scientific and *
// * technical work of the GEANT4 collaboration.                      *
// * By using,  copying,  modifying or  distributing the software (or *
// * any work based  on the software)  you  agree  to acknowledge its *
// * use  in  resulting  scientific  publications,  and indicate your *
// * acceptance of all terms of the Geant4 Software license.          *
// ********************************************************************
//
/// \file Strata/src/DetectorMessenger.cc
/// \brief Implementation of the DetectorMessenger class
//
//
//==============================================================================
//==============================================================================

#include "DetectorMessenger.hh"
#include "DetectorConstruction.hh"

#include "G4UIdirectory.hh"
#include "G4UIcommand.hh"
#include "G4UIparameter.hh"
#include "G4UIcmdWithAString.hh"
#include "G4UIcmdWithAnInteger.hh"
#include "G4UIcmdWithADoubleAndUnit.hh"

#include <string>

//==============================================================================

DetectorMessenger::DetectorMessenger(DetectorConstruction* Det)
        : G4UImessenger(), fDetector(Det),
          fTestemDir(nullptr),
          fDetDir(nullptr),
          fMaterCmd(nullptr),
          fWMaterCmd(nullptr),
          fTargetTempCmd(nullptr),
          fSizeXCmd(nullptr),
          fSizeYZCmd(nullptr),
          fMagFieldCmd(nullptr),
          fLayNbCmd(nullptr),
          fLayThickCmd(nullptr),
          fLayMatCmd(nullptr),
          fVoxNbCmd(nullptr),
          fVoxDefCmd(nullptr),
          fVoxPosiCmd(nullptr) {
    fTestemDir = new G4UIdirectory("/strata/");
    fTestemDir->SetGuidance("Strata configuration options.");

    fDetDir = new G4UIdirectory("/strata/geometry/");
    fDetDir->SetGuidance("Geometry construction commands");

    fWMaterCmd = new G4UIcmdWithAString("/strata/geometry/setWorldMat", this);
    fWMaterCmd->SetGuidance("Select material of the world.");
    fWMaterCmd->SetParameterName("material", false);
    fWMaterCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fTargetTempCmd = new G4UIcmdWithADoubleAndUnit("/strata/geometry/setTemperature",this);
    fTargetTempCmd->SetGuidance("Set target temperature.");
    fTargetTempCmd->SetParameterName("targettemp", true);
    fTargetTempCmd->SetDefaultValue(273.);
    fTargetTempCmd->SetDefaultUnit("kelvin");
    fTargetTempCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fSizeYZCmd = new G4UIcmdWithADoubleAndUnit("/strata/geometry/setSizeYZ", this);
    fSizeYZCmd->SetGuidance("Set transversal size (YZ) of the target.");
    fSizeYZCmd->SetParameterName("SizeYZ", false);
    fSizeYZCmd->SetRange("SizeYZ>0.");
    fSizeYZCmd->SetUnitCategory("Length");
    fSizeYZCmd->AvailableForStates(G4State_PreInit);

    fMagFieldCmd = new G4UIcmdWithADoubleAndUnit("/strata/geometry/setField", this);
    fMagFieldCmd->SetGuidance("Define magnetic field.");
    fMagFieldCmd->SetGuidance("Magnetic field will be in Z direction.");
    fMagFieldCmd->SetParameterName("Bz", false);
    fMagFieldCmd->SetUnitCategory("Magnetic flux density");
    fMagFieldCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fLayNbCmd = new G4UIcmdWithAnInteger("/strata/geometry/layerNumber", this);
    fLayNbCmd->SetGuidance("Set number of layers.");
    fLayNbCmd->SetParameterName("layerNb", false);
    std::string layer_range = "(layerNb>=1)&&(layerNb<=" + std::to_string(nMaxLayer) + ")";
    fLayNbCmd->SetRange(layer_range.c_str());
    fLayNbCmd->AvailableForStates(G4State_PreInit);

    fLayThickCmd = new G4UIcommand("/strata/geometry/layerThickness", this);
    fLayThickCmd->SetGuidance("Set layer thickness.");
    fLayThickCmd->SetGuidance("  layer number: from 0 to layerNumber");
    fLayThickCmd->SetGuidance("  thickness (double with unit)");
    //
    auto* fLayNbPrm = new G4UIparameter("layerNb", 'i', false);
    fLayNbPrm->SetGuidance("layer number: from 0 to layerNumber");
    fLayNbPrm->SetParameterRange("layerNb>=0");
    fLayThickCmd->SetParameter(fLayNbPrm);
    //
    auto* ThickPrm = new G4UIparameter("Thickness", 'd', false);
    ThickPrm->SetGuidance("layer thickness");
    ThickPrm->SetParameterRange("Thickness>0.");
    fLayThickCmd->SetParameter(ThickPrm);
    //
    auto* unitThickPrm = new G4UIparameter("unit", 's', false);
    unitThickPrm->SetGuidance("unit of length");
    G4String unitThickList = G4UIcommand::UnitsList(G4UIcommand::CategoryOf("um"));
    unitThickPrm->SetParameterCandidates(unitThickList);
    fLayThickCmd->SetParameter(unitThickPrm);
    //
    fLayThickCmd->AvailableForStates(G4State_PreInit);

    fLayMatCmd = new G4UIcommand("/strata/geometry/layerMaterial", this);
    fLayMatCmd->SetGuidance("Set layer material.");
    fLayMatCmd->SetGuidance("  layer number : from 0 to layerNumber");
    fLayMatCmd->SetGuidance("  material name");
    //
    auto* fLayNmPrm = new G4UIparameter("layerNm", 'i', false);
    fLayNmPrm->SetGuidance("layer number: from 0 to layerNumber");
    fLayNmPrm->SetParameterRange("layerNm>=0");
    fLayMatCmd->SetParameter(fLayNmPrm);
    //
    auto* matNamePrm = new G4UIparameter("material", 's', false);
    matNamePrm->SetGuidance("material name");
    fLayMatCmd->SetParameter(matNamePrm);
    //
    auto* DensPrm = new G4UIparameter("Density", 'd', true);
    DensPrm->SetGuidance("layer density");
    DensPrm->SetParameterRange("Density>=0.");
    DensPrm->SetDefaultValue(0.0);
    fLayMatCmd->SetParameter(DensPrm);
    //
    auto* unitDensPrm = new G4UIparameter("unit", 's', true);
    unitDensPrm->SetGuidance("unit of density");
    G4String unitDensList = G4UIcommand::UnitsList(G4UIcommand::CategoryOf("g/cm3"));
    unitDensPrm->SetParameterCandidates(unitDensList);
    unitDensPrm->SetDefaultValue("g/cm3");
    fLayMatCmd->SetParameter(unitDensPrm);
    //
    fLayMatCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fVoxNbCmd = new G4UIcmdWithAnInteger("/strata/geometry/voxelNumber", this);
    fVoxNbCmd->SetGuidance("Set number of voxels.");
    fVoxNbCmd->SetParameterName("voxelNb", false);
    std::string voxel_range = "(voxelNb>=0)&&(voxelNb<=" + std::to_string(nMaxVoxel) + ")";
    fVoxNbCmd->SetRange(voxel_range.c_str());
    fVoxNbCmd->AvailableForStates(G4State_PreInit, G4State_Idle);

    fVoxDefCmd = new G4UIcommand("/strata/geometry/voxelDefinition", this);
    fVoxDefCmd->SetGuidance("Set voxel dimensions.");
    fVoxDefCmd->SetGuidance("  voxel number: from 0 to voxelNumber");
    fVoxDefCmd->SetGuidance("  material name");
    fVoxDefCmd->SetGuidance("  dimensions (3-vector with unit)");
    //
    auto* fVoxNbPrm = new G4UIparameter("voxelNb", 'i', false);
    fVoxNbPrm->SetGuidance("voxel number: from 0 to voxelNumber");
    fVoxNbPrm->SetParameterRange("voxelNb>=0");
    fVoxDefCmd->SetParameter(fVoxNbPrm);
    //
    auto* SizeXPrm = new G4UIparameter("sizeX", 'd', false);
    SizeXPrm->SetGuidance("sizeX");
    SizeXPrm->SetParameterRange("sizeX>0.");
    fVoxDefCmd->SetParameter(SizeXPrm);
    //
    auto* SizeYPrm = new G4UIparameter("sizeY", 'd', false);
    SizeYPrm->SetGuidance("sizeY");
    SizeYPrm->SetParameterRange("sizeY>0.");
    fVoxDefCmd->SetParameter(SizeYPrm);
    //
    auto* SizeZPrm = new G4UIparameter("sizeZ", 'd', false);
    SizeZPrm->SetGuidance("sizeZ");
    SizeZPrm->SetParameterRange("sizeZ>0.");
    fVoxDefCmd->SetParameter(SizeZPrm);
    //
    auto* unitPrm = new G4UIparameter("unit", 's', false);
    unitPrm->SetGuidance("unit of dimensions");
    G4String unitList = G4UIcommand::UnitsList(G4UIcommand::CategoryOf("um"));
    unitPrm->SetParameterCandidates(unitList);
    fVoxDefCmd->SetParameter(unitPrm);
    //
    fVoxDefCmd->AvailableForStates(G4State_PreInit);

    fVoxPosiCmd = new G4UIcommand("/strata/geometry/voxelPosition", this);
    fVoxPosiCmd->SetGuidance("Set voxel position");
    fVoxPosiCmd->SetGuidance("  voxel number: from 0 to voxelNumber");
    fVoxPosiCmd->SetGuidance("  position (3-vector with unit)");
    //
    auto* fVoxNumPrm = new G4UIparameter("voxelNum", 'i', false);
    fVoxNumPrm->SetGuidance("voxel number: from 0 to voxelNumber");
    fVoxNumPrm->SetParameterRange("voxelNum>=0");
    fVoxPosiCmd->SetParameter(fVoxNumPrm);
    //
    auto* PosiXPrm = new G4UIparameter("posiX", 'd', false);
    PosiXPrm->SetGuidance("position X");
    fVoxPosiCmd->SetParameter(PosiXPrm);
    //
    auto* PosiYPrm = new G4UIparameter("posiY", 'd', false);
    PosiYPrm->SetGuidance("position Y");
    fVoxPosiCmd->SetParameter(PosiYPrm);
    //
    auto* PosiZPrm = new G4UIparameter("posiZ", 'd', false);
    PosiZPrm->SetGuidance("position Z");
    fVoxPosiCmd->SetParameter(PosiZPrm);
    //
    auto* unitPr = new G4UIparameter("unit", 's', false);
    unitPr->SetGuidance("unit of position");
    unitPr->SetParameterCandidates(unitList);
    fVoxPosiCmd->SetParameter(unitPr);
    //
    fVoxPosiCmd->AvailableForStates(G4State_PreInit);

}

//==============================================================================

DetectorMessenger::~DetectorMessenger() {
    delete fMaterCmd;
    delete fWMaterCmd;
    delete fTargetTempCmd;
    delete fSizeXCmd;
    delete fSizeYZCmd;
    delete fMagFieldCmd;
    delete fLayNbCmd;
    delete fLayThickCmd;
    delete fLayMatCmd;
    delete fVoxNbCmd;
    delete fVoxDefCmd;
    delete fVoxPosiCmd;
    delete fDetDir;
    delete fTestemDir;
}

//==============================================================================

G4bool DetectorMessenger::LayerInStack(G4UIcommand* command, G4int index) {
    const G4int n = fDetector->GetLayerNumber();
    if (index >= 0 && index < n) return true;
    G4ExceptionDescription ed;
    ed << "layer " << index << " does not exist: the stack has " << n
       << " layer(s), numbered 0 to " << n - 1
       << "; set /strata/geometry/layerNumber first";
    command->CommandFailed(ed);
    return false;
}

//==============================================================================

void DetectorMessenger::SetNewValue(G4UIcommand* command, G4String newValue) {
    if (command == fWMaterCmd) {
        fDetector->SetWorldMaterial(newValue);
    }

    if (command == fTargetTempCmd) {
        fDetector->SetTemperature(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue));
    }

    if (command == fSizeYZCmd) {
        fDetector->SetSizeYZ(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue));
    }

    if (command == fMagFieldCmd) {
        fDetector->SetMagField(G4UIcmdWithADoubleAndUnit::GetNewDoubleValue(newValue));
    }

    if (command == fLayNbCmd) {
        const G4int n = G4UIcmdWithAnInteger::GetNewIntValue(newValue);
        fDetector->SetLayerNumber(n);
        if (fDetector->GetLayerNumber() != n) {
            G4ExceptionDescription ed;
            ed << "layer number " << n << " is out of range";
            command->CommandFailed(ed);
        }
    }

    if (command == fLayThickCmd) {
        G4int num;
        G4double val;
        G4String unt;
        std::istringstream is(newValue);
        is >> num >> val >> unt;
        val *= G4UIcommand::ValueOf(unt);
        // A layer past the stack would be set and never used
        if (!LayerInStack(command, num)) return;
        fDetector->SetLayerThickness(num, val);
    }

    if (command == fLayMatCmd) {
        G4int num;
        G4String val, unt;
        G4double dens;
        std::istringstream is(newValue);
        is >> num >> val >> dens >> unt;
        dens *= G4UIcommand::ValueOf(unt);
        if (!LayerInStack(command, num)) return;
        fDetector->SetLayerMaterial(num, val, dens);
    }

    if (command == fVoxNbCmd) {
        fDetector->SetVoxelNumber(G4UIcmdWithAnInteger::GetNewIntValue(newValue));
    }

    if (command == fVoxDefCmd) {
        G4int num;
        G4double v1, v2, v3;
        G4String unt;
        std::istringstream is(newValue);
        is >> num >> v1 >> v2 >> v3 >> unt;
        G4ThreeVector vec(v1, v2, v3);
        vec *= G4UIcommand::ValueOf(unt);
        fDetector->SetVoxelSize(num, vec);
    }

    if (command == fVoxPosiCmd) {
        G4int num;
        G4double v1, v2, v3;
        G4String unt;
        std::istringstream is(newValue);
        is >> num >> v1 >> v2 >> v3 >> unt;
        G4ThreeVector vec(v1, v2, v3);
        vec *= G4UIcommand::ValueOf(unt);
        fDetector->SetVoxelPosition(num, vec);
    }
}

//==============================================================================
