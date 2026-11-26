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
/// \file Strata/src/DetectorConstruction.cc
/// \brief Implementation of the DetectorConstruction class
//
//
//==============================================================================
//==============================================================================

#include "DetectorConstruction.hh"
#include "DetectorMessenger.hh"
#include "MaterialMessenger.hh"
#include "RBSDetector.hh"
#include "DamageCalculator.hh"

#include "BFieldSetup.hh"
#include "EFieldSetup.hh"
#include "G4AutoDelete.hh"

#include "G4Material.hh"
#include "G4Box.hh"
#include "G4LogicalVolume.hh"
#include "G4PVPlacement.hh"
#include "G4UniformMagField.hh"

#include "G4GeometryManager.hh"
#include "G4VisAttributes.hh"

#include "G4NistManager.hh"

#include <cmath>
#include <sstream>
#include "G4UnitsTable.hh"

#include "G4FieldManager.hh"
#include "G4TransportationManager.hh"
#include "G4RunManager.hh"

#include "G4PhysicalConstants.hh"
#include "G4SystemOfUnits.hh"

//==============================================================================

DetectorConstruction::DetectorConstruction()
        : G4VUserDetectorConstruction(),
          // NTP, which is what every material Geant4 builds carries.  A
          // different default would make ResolveMaterial build a variant of
          // every layer material for no reason the user asked for
          fTemperature(NTP_Temperature),
          fMagField(nullptr),
          fLWorld(nullptr),
          fLayerNumber(1),
          fLayerThickness(),
          fLayerDensity(),
          fLayerMaterial(),
          fLLayers() {

    // default parameter values
    for (G4int i = 0; i < nMaxLayer; i++) {
        fLLayers[i] = nullptr;

        fLayerThickness[i] = 0.0;
        fLayerDensity[i] = 0.0;
        fLayerMaterial[i] = nullptr;
    }
    fLayerNumber = 1;
    fLayerThickness[0] = 20.0*um;
    fLayerDensity[0] = 0.0;

    fMultiLayerSizeYZ = 20*um;
    fWorldSizeX = 1.2*GetMultiLayerSizeX();
    fWorldSizeYZ = 1.2*fMultiLayerSizeYZ;

    fVoxelNumber = 0;
    for (G4int j = 0; j < nMaxVoxel; j++) {
        fVoxelSize[j] = fVoxelPosition[j] = G4ThreeVector(0., 0., 0.);
        fVoxelMass[j] = 0.;
        fLVoxel[j] = nullptr;
    }

    DefineMaterials();

    // create commands for interactive definition of the detector
    fDetectorMessenger = new DetectorMessenger(this);
    fMaterialMessenger = new MaterialMessenger();
    fRBS = new RBSDetector(this);
    fDamage = new DamageCalculator(this);
}

//==============================================================================

DetectorConstruction::~DetectorConstruction() {
    delete fRBS;
    delete fMaterialMessenger;
    delete fDetectorMessenger;
}

//==============================================================================

void DetectorConstruction::DefineMaterials() {
    G4String symbol;    //a=mass of a mole;
    G4double a, z;      //z=mean number of protons;


    // Define Elements

    auto* H = new G4Element("Hydrogen", symbol = "H", z = 1, a = 1.008*g/mole);
    auto* C = new G4Element("Carbon", symbol = "C", z = 6, a = 12.01*g/mole);
    auto* N = new G4Element("Nitrogen", symbol = "N", z = 7, a = 14.01*g/mole);
    auto* O = new G4Element("Oxygen", symbol = "O", z = 8, a = 16.00*g/mole);
    auto* Si = new G4Element("Silicon", symbol = "Si", z = 14, a = 28.0855*g/mole);
    auto* Na = new G4Element("Sodium", symbol = "Na", z = 11, a = 22.99*g/mole);
    auto* Ar = new G4Element("Argon", symbol = "Ar", z = 18, a = 39.95*g/mole);
    auto* I = new G4Element("Iodine", symbol = "I", z = 53, a = 126.90*g/mole);
    auto* Xe = new G4Element("Xenon", symbol = "Xe", z = 54, a = 131.29*g/mole);

    // Define Materials

    G4double density, temperature, pressure;
    G4int ncomponents, natoms;
    G4double fractionmass;

    // Define simple materials

    new G4Material("H2Liq", z = 1, a = 1.01*g/mole, density = 70.8*mg/cm3);
    new G4Material("Beryllium", z = 4, a = 9.01*g/mole, density = 1.848*g/cm3);
    new G4Material("Aluminium", z = 13, a = 26.98*g/mole, density = 2.700*g/cm3);
    new G4Material("Silicon", z = 14, a = 28.09*g/mole, density = 2.330*g/cm3);

    auto* lAr = new G4Material("liquidArgon", density = 1.390*g/cm3, ncomponents = 1);
    lAr->AddElement(Ar, natoms = 1);

    new G4Material("Iron", z = 26, a = 55.85*g/mole, density = 7.870*g/cm3);
    new G4Material("Copper", z = 29, a = 63.55*g/mole, density = 8.960*g/cm3);
    new G4Material("Germanium", z = 32, a = 72.61*g/mole, density = 5.323*g/cm3);
    new G4Material("Silver", z = 47, a = 107.87*g/mole, density = 10.50*g/cm3);
    new G4Material("Tungsten", z = 74, a = 183.85*g/mole, density = 19.30*g/cm3);
    new G4Material("Gold", z = 79, a = 196.97*g/mole, density = 19.32*g/cm3);
    new G4Material("Lead", z = 82, a = 207.19*g/mole, density = 11.35*g/cm3);

    // Define a material from elements. case 1: chemical molecule

    // Amorphous silica
    auto* SiO2 = new G4Material("Silica", density = 2.32*g/cm3, ncomponents = 2,
                                kStateSolid, fTemperature);
    SiO2->AddElement(Si, natoms = 1);
    SiO2->AddElement(O, natoms = 2);
    SiO2->GetIonisation()->SetMeanExcitationEnergy(139.2*eV);

    // Crystalline alpha quartz
    auto* Qrtz = new G4Material("Quartz", density = 2.65*g/cm3, ncomponents = 2,
                                kStateSolid, fTemperature);
    Qrtz->AddElement(Si, natoms = 1);
    Qrtz->AddElement(O, natoms = 2);
    Qrtz->GetIonisation()->SetMeanExcitationEnergy(139.2*eV);

    // Water
    auto* H2O = new G4Material("Water", density = 1.0*g/cm3, ncomponents = 2);
    H2O->AddElement(H, natoms = 2);
    H2O->AddElement(O, natoms = 1);
    H2O->GetIonisation()->SetMeanExcitationEnergy(78.0*eV);

    // In this line both G4_WATER and Water_1.05 will be constructed
    G4NistManager::Instance()->
            BuildMaterialWithNewDensity("Water_1.05", "G4_WATER", 1.05*g/cm3);

    auto* CH = new G4Material("Plastic", density = 1.04*g/cm3, ncomponents = 2);
    CH->AddElement(C, natoms = 1);
    CH->AddElement(H, natoms = 1);

    auto* NaI = new G4Material("NaI", density = 3.67*g/cm3, ncomponents = 2);
    NaI->AddElement(Na, natoms = 1);
    NaI->AddElement(I, natoms = 1);
    NaI->GetIonisation()->SetMeanExcitationEnergy(452*eV);

    // Define a material from elements. case 2: mixture by fractional mass

    auto* Air = new G4Material("Air", density = 1.290*mg/cm3, ncomponents = 2);
    Air->AddElement(N, fractionmass = 0.7);
    Air->AddElement(O, fractionmass = 0.3);

    auto* Air20 = new G4Material("Air20", density = 1.205*mg/cm3, ncomponents = 2,
                                 kStateGas, 293.*kelvin, 1.*atmosphere);
    Air20->AddElement(N, fractionmass = 0.7);
    Air20->AddElement(O, fractionmass = 0.3);

    //Graphite
    auto* Graphite = new G4Material("Graphite", density = 1.7*g/cm3, ncomponents = 1);
    Graphite->AddElement(C, fractionmass = 1.);

    // Havar
    auto* Cr = new G4Element("Chrome", "Cr", z = 24, a = 51.996*g/mole);
    auto* Fe = new G4Element("Iron", "Fe", z = 26, a = 55.845*g/mole);
    auto* Co = new G4Element("Cobalt", "Co", z = 27, a = 58.933*g/mole);
    auto* Ni = new G4Element("Nickel", "Ni", z = 28, a = 58.693*g/mole);
    auto* W = new G4Element("Tungsten", "W", z = 74, a = 183.850*g/mole);

    auto* Havar = new G4Material("Havar", density = 8.3*g/cm3, ncomponents = 5);
    Havar->AddElement(Cr, fractionmass = 0.1785);
    Havar->AddElement(Fe, fractionmass = 0.1822);
    Havar->AddElement(Co, fractionmass = 0.4452);
    Havar->AddElement(Ni, fractionmass = 0.1310);
    Havar->AddElement(W, fractionmass = 0.0631);

    // Examples of gas
    new G4Material("ArgonGas", z = 18, a = 39.948*g/mole, density = 1.782*mg/cm3,
                   kStateGas, 273.15*kelvin, 1*atmosphere);

    new G4Material("XenonGas", z = 54, a = 131.29*g/mole, density = 5.458*mg/cm3,
                   kStateGas, 293.15*kelvin, 1*atmosphere);

    auto* CO2 = new G4Material("CarbonicGas", density = 1.977*mg/cm3, ncomponents = 2);
    CO2->AddElement(C, natoms = 1);
    CO2->AddElement(O, natoms = 2);

    auto* ArCO2 = new G4Material("ArgonCO2", density = 1.8223*mg/cm3, ncomponents = 2);
    ArCO2->AddElement(Ar, fractionmass = 0.7844);
    ArCO2->AddMaterial(CO2, fractionmass = 0.2156);

    // Another way to define mixture of gas per volume
    auto* NewArCO2 = new G4Material("NewArgonCO2", density = 1.8223*mg/cm3, ncomponents = 3);
    NewArCO2->AddElement(Ar, natoms = 8);
    NewArCO2->AddElement(C, natoms = 2);
    NewArCO2->AddElement(O, natoms = 4);

    auto* ArCH4 = new G4Material("ArgonCH4", density = 1.709*mg/cm3, ncomponents = 3);
    ArCH4->AddElement(Ar, natoms = 93);
    ArCH4->AddElement(C, natoms = 7);
    ArCH4->AddElement(H, natoms = 28);

    auto* XeCH = new G4Material("XenonMethanePropane", density = 4.9196*mg/cm3, ncomponents = 3,
                           kStateGas, 293.15*kelvin, 1*atmosphere);
    XeCH->AddElement(Xe, natoms = 875);
    XeCH->AddElement(C, natoms = 225);
    XeCH->AddElement(H, natoms = 700);

    auto* steam = new G4Material("WaterSteam", density = 1.0*mg/cm3, ncomponents = 1);
    steam->AddMaterial(H2O, fractionmass = 1.);
    steam->GetIonisation()->SetMeanExcitationEnergy(71.6*eV);

    auto* rock1 = new G4Material("StandardRock", 2.65*CLHEP::g/CLHEP::cm3, 1, kStateSolid);
    rock1->AddElement(Na, 1);

    // Example of vacuum
    //density = 1.e-5*g/cm3;
    density = 1.e-11*g/cm3;
    //pressure = 2.e-2*bar;
    pressure = 2.e-8*bar;
    temperature = STP_Temperature;  // From PhysicalConstants.h .
    auto* vacuum = new G4Material("Vacuum", density, 1, kStateGas, temperature, pressure);
    vacuum->AddMaterial(Air, 1.);

    // Stripper gas
    pressure = 1.e-3*bar;
    temperature = STP_Temperature;  // From PhysicalConstants.h .
    density = pressure/(296.8*joule/kilogram/kelvin)/temperature;
    G4cout << "Density: " << density << G4endl;
    auto* stripperGas = new G4Material("StripperGas", density, 1, kStateGas, temperature, pressure);
    stripperGas->AddElement(N, fractionmass = 1.);

    // Default materials
    fWorldMaterial = vacuum;
    for (auto& mat: fLayerMaterial) {
        mat = SiO2;
    }
}

//==============================================================================

G4VPhysicalVolume* DetectorConstruction::Construct() {

    G4Colour color_white(1.0, 1.0, 1.0);
    G4Colour color_gray(0.5, 0.5, 0.5);
    G4Colour color_black(0.0, 0.0, 0.0);
    G4Colour color_red(1.0, 0.0, 0.0);
    G4Colour color_green(0.0, 0.1, 0.0);
    G4Colour color_blue(0.0, 0.0, 1.0);
    G4Colour color_cyan(0.0, 0.1, 1.0);
    G4Colour color_magenta(1.0, 0.0, 1.0);
    G4Colour color_yellow(1.0, 1.0, 0.0);
    G4Colour color_orange(1.0, 0.5, 0.0);

    G4Colour layer_colors[7] = {color_yellow,
                                color_orange,
                                color_red,
                                color_blue,
                                color_magenta,
                                color_cyan,
                                color_gray};

    // Option to switch on/off checking of volumes overlaps
    G4bool checkOverlaps = true;

    // World
    auto* sWorld = new G4Box("World", fWorldSizeX/2, fWorldSizeYZ/2, fWorldSizeYZ/2);

    fLWorld = new G4LogicalVolume(sWorld, fWorldMaterial, "World");

    G4VPhysicalVolume* pWorld = new G4PVPlacement(nullptr, G4ThreeVector(0., 0., 0.),
                                                  fLWorld, "World", nullptr,
                                                  false, 0, checkOverlaps);

    // Target Layers
    G4double PositionX = -GetMultiLayerSizeX()/2;
    G4cout << "Multilayer size: " << GetMultiLayerSizeX() << G4endl;
    G4Box* solid;

    G4int idx = 0;
    G4Colour layer_color;
    G4bool color_found;

    for (G4int i = 0; i < fLayerNumber; i++) {
        G4String layerName = "Layer" + std::to_string(i);

        PositionX += fLayerThickness[i]/2;

        // Create layer

        solid = new G4Box(layerName + ".Solid",
                          fLayerThickness[i]/2, fMultiLayerSizeYZ/2, fMultiLayerSizeYZ/2);

        fLLayers[i] = new G4LogicalVolume(solid, GetLayerMaterial(i), layerName + ".Logic");

        new G4PVPlacement(nullptr, G4ThreeVector(PositionX, 0., 0.),
                          fLLayers[i], layerName + ".Physical", fLWorld,
                          false, 0, checkOverlaps);

        // Select color for the layer
        color_found = false;
        for (G4int j = 0; j < i; j++) {
            if (fLLayers[j]->GetMaterial() == GetLayerMaterial(i)) {
                layer_color = fLLayers[j]->GetVisAttributes()->GetColor();
                color_found = true;
                break;
            }
        }

        // If no other layer had the material, assign a new color
        if (!color_found) {
            layer_color = layer_colors[idx%7];
            idx++;
        }

        auto* visAtt = new G4VisAttributes(layer_color);
        visAtt->SetVisibility(true);
        fLLayers[i]->SetVisAttributes(visAtt);


        PositionX += fLayerThickness[i]/2;
    }

    // Voxels (optional)
    if (fVoxelNumber > 0) {
        for (G4int j = 0; j < fVoxelNumber; j++) {
            // Index of layer containing the voxel
            G4int layNum = GetMotherIndex(j);
            G4cout << "Voxel number: " << j << ", mother layer: " << layNum << G4endl;

            // Make the voxel position relative to its mother layer
            G4ThreeVector voxelLocation = G4ThreeVector(fVoxelPosition[j].x() - GetLayerXpos(layNum),
                                                        fVoxelPosition[j].y(),
                                                        fVoxelPosition[j].z());

            auto* sVoxel = new G4Box("Voxel",
                                     fVoxelSize[j].x()/2, fVoxelSize[j].y()/2, fVoxelSize[j].z()/2);

            fLVoxel[j] = new G4LogicalVolume(sVoxel, fLayerMaterial[layNum], "Voxel");

            new G4PVPlacement(nullptr, voxelLocation, fLVoxel[j],
                              "Voxel", fLLayers[layNum], false,
                              j + 1, checkOverlaps);

            fVoxelMass[j] = fVoxelSize[j].x()*fVoxelSize[j].y()*fVoxelSize[j].z()
                            *(fLayerMaterial[layNum]->GetDensity());
        }
    }

    PrintParameters();

    // Always return the World volume
    return pWorld;
}

//==============================================================================

void DetectorConstruction::PrintParameters() const {
    G4cout << *(G4Material::GetMaterialTable()) << G4endl;
    G4cout << "\n---------------------------------------------------------\n";
    G4cout << "---> There are " << fLayerNumber << " layer(s) : " << G4endl;
    for (G4int i = 0; i < fLayerNumber; i++) {
        G4cout << "---> Layer " << i + 1 << " is " << G4BestUnit(fLayerThickness[i], "Length")
               << " of " << fLayerMaterial[i]->GetName() << G4endl;
    }
    G4cout << "\n---------------------------------------------------------\n";

    if (fVoxelNumber > 0) {
        G4cout << "---> There are " << fVoxelNumber << " tallie(s) : " << G4endl;
        for (G4int j = 0; j < fVoxelNumber; j++) {
            // Index of layer containing the voxel
            G4int layNum = GetMotherIndex(j);
            G4cout << "fVoxel " << j + 1 << ": "
                   << fLayerMaterial[layNum]->GetName()
                   << ",  mass = " << G4BestUnit(fVoxelMass[j], "Mass")
                   << " size = " << G4BestUnit(fVoxelSize[j], "Length")
                   << " position = " << G4BestUnit(fVoxelPosition[j], "Length")
                   << G4endl;
        }
        G4cout << "\n---------------------------------------------------------\n";
    }
}

//==============================================================================

G4double DetectorConstruction::GetMultiLayerSizeX() const {
    G4double sum = 0.0;
    for (G4int i = 0; i < fLayerNumber; i++) {
        sum += fLayerThickness[i];
    }

    return sum;
}

//==============================================================================

G4bool DetectorConstruction::LayerContainsVoxel(G4int layerIdx, G4int voxelIdx) const {
    return (G4bool) ((GetVoxelXmin(voxelIdx) >= GetLayerXmin(layerIdx))
                  && (GetVoxelXmax(voxelIdx) <= GetLayerXmax(layerIdx))
                  && (GetVoxelYmin(voxelIdx) >= GetLayersYZmin())
                  && (GetVoxelYmax(voxelIdx) <= GetLayersYZmax())
                  && (GetVoxelZmin(voxelIdx) >= GetLayersYZmin())
                  && (GetVoxelZmax(voxelIdx) <= GetLayersYZmax()));
}

//==============================================================================

G4int DetectorConstruction::GetMotherIndex(G4int voxelIdx) const {
    // Check if some layer fully contains it
    for (G4int i = 0; i < fLayerNumber; i++) {
        if (LayerContainsVoxel(i, voxelIdx))
            return i;
    }
    // If no layer fully contains it, just assign it to the first layer
    return 0;
}

//==============================================================================

G4LogicalVolume* DetectorConstruction::GetMotherLayer(G4int voxelIdx) {
    G4int layerIdx = GetMotherIndex(voxelIdx);
    if ((layerIdx >= 0) && (layerIdx < fLayerNumber))
        return fLLayers[layerIdx];
    else
        return nullptr;
}

//==============================================================================

void DetectorConstruction::SetSizeYZ(G4double value) {
    fMultiLayerSizeYZ = value;
    fWorldSizeYZ = 1.2*fMultiLayerSizeYZ;
}

//==============================================================================

void DetectorConstruction::SetWorldMaterial(const G4String& materialChoice) {
    // search the material by its name
    G4Material* ptrtoMaterial =
            G4NistManager::Instance()->FindOrBuildMaterial(materialChoice);
    if (ptrtoMaterial && ptrtoMaterial != fWorldMaterial) {
        fWorldMaterial = ptrtoMaterial;
        if (fLWorld) {
            fLWorld->SetMaterial(fWorldMaterial);
            G4RunManager::GetRunManager()->PhysicsHasBeenModified();
        }
    }
}

//==============================================================================

void DetectorConstruction::SetMagField(G4double fieldValue) {
    //apply a global uniform magnetic field along Z axis
    G4FieldManager* fieldMgr
            = G4TransportationManager::GetTransportationManager()->GetFieldManager();

    delete fMagField;        //delete the existing magn field

    if (fieldValue != 0.)                        // create a new one if non nul
    {
        fMagField = new G4UniformMagField(G4ThreeVector(0., 0., fieldValue));
        fieldMgr->SetDetectorField(fMagField);
        fieldMgr->CreateChordFinder(fMagField);
    } else {
        fMagField = nullptr;
        fieldMgr->SetDetectorField(fMagField);
    }
}

//==============================================================================

void DetectorConstruction::ConstructSDandField() {
    // Construct the field creator - this will register the field it creates

    if (!fBFieldSetup.Get()) {
        BFieldSetup* BFSetup = new BFieldSetup();
        G4AutoDelete::Register(BFSetup); //Kernel will delete the messenger
        fBFieldSetup.Put(BFSetup);
    }

    if (!fEFieldSetup.Get()) {
        EFieldSetup* EFSetup = new EFieldSetup();
        G4AutoDelete::Register(EFSetup); //Kernel will delete the messenger
        fEFieldSetup.Put(EFSetup);
    }
}

//==============================================================================

void DetectorConstruction::SetLayerNumber(G4int value) {
    if (value >= 1 && value <= nMaxLayer) {
        fLayerNumber = value;
    } else {
        G4cout << "### DetectorConstruction::SetLayerNumber WARNING: wrong layer "
               << "number " << value << " is ignored" << G4endl;
    }
}

//==============================================================================

void DetectorConstruction::SetLayerThickness(G4int j, const G4double value) {
    if (j >= 0 && j < nMaxLayer) {
        fLayerThickness[j] = value;
        fWorldSizeX = 1.2*GetMultiLayerSizeX();
    } else {
        G4cout << "### DetectorConstruction::SetLayerThickness WARNING: wrong layer "
               << "number " << j << " is ignored" << G4endl;
    }
}

//==============================================================================

// A material is immutable once Geant4 has it, so a layer wanted at a
// density or a temperature other than the catalogue's is a new material
// built on the catalogue one.  The variant is named for what makes it
// different: Geant4 keeps one material per name, so a second request at a
// different temperature would otherwise come back with the first.
G4Material* DetectorConstruction::ResolveMaterial(const G4String& name,
                                                  G4double density) {
    G4Material* base = G4NistManager::Instance()->FindOrBuildMaterial(name);
    if (base == nullptr) base = G4Material::GetMaterial(name, false);
    if (base == nullptr) return nullptr;

    const G4bool newDensity = (density > 0.) && (density != base->GetDensity());
    const G4bool newTemperature =
            std::abs(fTemperature - base->GetTemperature()) > 1e-6*kelvin;
    if (!newDensity && !newTemperature) return base;

    std::ostringstream id;
    id << name << "_strata";
    if (newDensity) id << '_' << density/(g/cm3) << "gcm3";
    if (newTemperature) id << '_' << fTemperature/kelvin << 'K';

    G4Material* made = G4Material::GetMaterial(id.str(), false);
    if (made != nullptr) return made;

    return new G4Material(id.str(), newDensity ? density : base->GetDensity(),
                          base, base->GetState(), fTemperature,
                          base->GetPressure());
}

//==============================================================================

// Every layer has to be rebuilt: a material's temperature is fixed when it
// is made, and the thermal neutron kernel reads it off the material
void DetectorConstruction::SetTemperature(G4double aDouble) {
    if (aDouble == fTemperature) return;
    fTemperature = aDouble;

    for (G4int j = 0; j < fLayerNumber; j++)
        if (!fLayerMaterialName[j].empty())
            SetLayerMaterial(j, fLayerMaterialName[j], fLayerDensity[j]);
}

//==============================================================================

void DetectorConstruction::SetLayerMaterial(G4int j, const G4String value, const G4double density) {
    if (j >= 0 && j < nMaxLayer) {
        fLayerDensity[j] = density;
        if (!value.empty()) {
            fLayerMaterialName[j] = value;
            G4Material* ptrtoMaterial = ResolveMaterial(value, fLayerDensity[j]);

            if (!ptrtoMaterial) {
                G4ExceptionDescription description;
                description << "      Layer material (" << value << ") not found." << G4endl
                            << "      Check that the name is spelled correctly.";
                G4Exception("DetectorConstruction::SetLayerMaterial()",
                            "Material_not_found", FatalException, description);
            } else if (ptrtoMaterial != fLayerMaterial[j]) {
                fLayerMaterial[j] = ptrtoMaterial;

                for (G4int t = 0; t < fVoxelNumber; t++) {
                    if ((fLVoxel[t]) && (j == GetMotherIndex(t))) {
                        fLVoxel[t]->SetMaterial(ptrtoMaterial);
                        fVoxelMass[t] = fVoxelSize[t].x()*fVoxelSize[t].y()*fVoxelSize[t].z()
                                        *ptrtoMaterial->GetDensity();
                    }
                }

                if (fLLayers[j]) {
                    fLLayers[j]->SetMaterial(fLayerMaterial[j]);
                    G4RunManager::GetRunManager()->PhysicsHasBeenModified();
                }

            }
        } else {
            fLayerMaterial[j] = nullptr;
        }
    } else {
        G4cout << "### DetectorConstruction::SetLayerMaterial WARNING: wrong layer "
               << "number " << j << " is ignored" << G4endl;
    }
}

//==============================================================================

G4double DetectorConstruction::GetLayerThickness(G4int j) const {
    if (j >= 0 && j < nMaxLayer) {
        return fLayerThickness[j];
    } else {
        G4cout << "### DetectorConstruction::GetLayerThickness WARNING: wrong layer "
               << "number " << j << " is ignored" << G4endl;
        return 0.0;
    }
}

//==============================================================================

G4double DetectorConstruction::GetLayerXpos(G4int j) const {
    G4double PositionX = (fLayerThickness[j] - GetMultiLayerSizeX())/2;

    for (G4int i = 0; i < j; i++)
        PositionX += fLayerThickness[i];

    return PositionX;
}

//==============================================================================

G4double DetectorConstruction::GetLayerDensity(G4int j) const {
    if (j >= 0 && j < nMaxLayer) {
        return fLayerDensity[j];
    } else {
        G4cout << "### DetectorConstruction::GetLayerDensity WARNING: wrong layer "
               << "number " << j << " is ignored" << G4endl;
        return 0.0;
    }
}

//==============================================================================

G4Material* DetectorConstruction::GetLayerMaterial(G4int j) {
    if (j >= 0 && j < nMaxLayer) {
        return fLayerMaterial[j];
    } else {
        G4cout << "### DetectorConstruction::GetLayerMaterial WARNING: wrong voxel "
               << "number " << j << " is ignored" << G4endl;
        return nullptr;
    }
}

//==============================================================================

void DetectorConstruction::SetVoxelNumber(G4int value) {
    if (value >= 0 && value <= nMaxVoxel) {
        fVoxelNumber = value;
    } else {
        G4cout << "### DetectorConstruction::SetVoxelNumber WARNING: wrong voxel "
               << "number " << value << " is ignored" << G4endl;
    }
}

//==============================================================================

void DetectorConstruction::SetVoxelSize(G4int j, const G4ThreeVector& value) {
    if (j >= 0 && j < nMaxVoxel) {
        fVoxelSize[j] = value;
    } else {
        G4cout << "### DetectorConstruction::SetVoxelSize WARNING: wrong voxel "
               << "number " << j << " is ignored" << G4endl;
    }
}

//==============================================================================

void DetectorConstruction::SetVoxelPosition(G4int j, const G4ThreeVector& value) {
    if (j >= 0 && j < nMaxVoxel) {
        fVoxelPosition[j] = value;
    } else {
        G4cout << "### DetectorConstruction::SetVoxelPosition WARNING: wrong voxel "
               << "number " << j << " is ignored" << G4endl;
    }
}

//==============================================================================

G4double DetectorConstruction::GetVoxelMass(G4int j) const {
    if (j >= 0 && j < nMaxVoxel) {
        return fVoxelMass[j];
    } else {
        G4cout << "### DetectorConstruction::GetVoxelMass WARNING: wrong voxel "
               << "number " << j << " is ignored" << G4endl;
        return 0.0;
    }
}

//==============================================================================

const G4LogicalVolume* DetectorConstruction::GetLogicalVoxel(G4int j) const {
    if (j >= 0 && j < nMaxVoxel) {
        return fLVoxel[j];
    } else {
        G4cout << "### DetectorConstruction::GetLogicalVoxel WARNING: wrong voxel "
               << "number " << j << " is ignored" << G4endl;
        return nullptr;
    }
}

//==============================================================================
