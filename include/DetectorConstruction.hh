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
/// \file Strata/include/DetectorConstruction.hh
/// \brief Definition of the DetectorConstruction class
//
//
//==============================================================================
//==============================================================================

#ifndef DetectorConstruction_h
#define DetectorConstruction_h 1

#include "G4VUserDetectorConstruction.hh"
#include "globals.hh"
#include "G4Cache.hh"
#include "G4ThreeVector.hh"
#include "G4Colour.hh"

class G4LogicalVolume;
class G4Material;
class G4UniformMagField;
class DetectorMessenger;
class RBSDetector;
class DamageCalculator;
class BFieldSetup;
class EFieldSetup;

const G4int nMaxLayer = 100;
const G4int nMaxVoxel = 20;

//==============================================================================

class DetectorConstruction : public G4VUserDetectorConstruction
{
public:

    DetectorConstruction();
    virtual ~DetectorConstruction();

    G4bool LayerContainsVoxel(G4int, G4int) const;
    G4int GetMotherIndex(G4int) const;
    G4LogicalVolume* GetMotherLayer(G4int);

    // Materials carry their temperature, so this rebuilds the layers
    void SetTemperature(G4double aDouble);
    void SetSizeYZ(G4double);
    void SetWorldMaterial(const G4String&);
    void SetMagField(G4double);

    void SetLayerNumber(G4int);
    void SetLayerThickness(G4int, G4double);
    void SetLayerMaterial(G4int, G4String, G4double);

    void SetVoxelNumber(G4int);
    void SetVoxelSize(G4int, const G4ThreeVector&);
    void SetVoxelPosition(G4int, const G4ThreeVector&);

    virtual G4VPhysicalVolume* Construct();
    virtual void ConstructSDandField();

    G4double GetTemperature() { return fTemperature; }
    inline G4double GetWorldSizeX() const { return fWorldSizeX; };
    inline G4double GetWorldSizeYZ() const { return fWorldSizeYZ; };
    G4double GetMultiLayerSizeX() const;
    inline G4double GetMultiLayerSizeYZ() const { return fMultiLayerSizeYZ; };

    inline G4int GetLayerNumber() const {return fLayerNumber;}

    inline G4int GetVoxelNumber() const {return fVoxelNumber;};

    inline const G4Material* GetWorldMaterial() const { return fWorldMaterial; };

    G4double GetLayerThickness(G4int n) const;
    G4double GetLayerXpos(G4int n) const;
    G4double GetLayerDensity(G4int n) const;
    G4Material* GetLayerMaterial(G4int n);
    // The name the layer was given, not that of a density or temperature variant
    const G4String& GetLayerMaterialName(G4int n) const { return fLayerMaterialName[n]; }

    /// The backscattering detector, which is one object for the whole
    /// application: it carries the /strata/rbs/ settings, and the worker
    /// threads only read them
    inline RBSDetector* GetRBS() const { return fRBS; };
    inline DamageCalculator* GetDamage() const { return fDamage; };

    G4double GetVoxelMass(G4int n) const;
    const G4LogicalVolume* GetLogicalVoxel(G4int n) const;

    inline G4double GetLayerXmin(G4int n) const;
    inline G4double GetLayerXmax(G4int n) const { return GetLayerXmin(n) + fLayerThickness[n]; };
    inline G4double GetLayersYZmin() const { return -fMultiLayerSizeYZ/2; };
    inline G4double GetLayersYZmax() const { return fMultiLayerSizeYZ/2; };

    inline G4double GetVoxelXmin(G4int n) const { return fVoxelPosition[n].x() - fVoxelSize[n].x()/2; };
    inline G4double GetVoxelXmax(G4int n) const { return fVoxelPosition[n].x() + fVoxelSize[n].x()/2; };
    inline G4double GetVoxelYmin(G4int n) const { return fVoxelPosition[n].y() - fVoxelSize[n].y()/2; };
    inline G4double GetVoxelYmax(G4int n) const { return fVoxelPosition[n].y() + fVoxelSize[n].y()/2; };
    inline G4double GetVoxelZmin(G4int n) const { return fVoxelPosition[n].z() - fVoxelSize[n].z()/2; };
    inline G4double GetVoxelZmax(G4int n) const { return fVoxelPosition[n].z() + fVoxelSize[n].z()/2; };

    void PrintParameters() const;

private:

    void DefineMaterials();

    G4double fTemperature;
    G4double fWorldSizeX;
    G4double fWorldSizeYZ;
    G4double fMultiLayerSizeYZ;

    G4Material* fWorldMaterial{};

    G4UniformMagField* fMagField;
    G4LogicalVolume* fLWorld;

    G4int fLayerNumber{};
    G4double fLayerThickness[nMaxLayer]{};
    G4double fLayerDensity[nMaxLayer]{};
    G4Material* fLayerMaterial[nMaxLayer]{};
    // Kept so that a change of temperature can rebuild them
    G4String fLayerMaterialName[nMaxLayer];

    // A material at this density and temperature, built from the named one
    // if either differs from what the named one already has
    G4Material* ResolveMaterial(const G4String& name, G4double density);
    RBSDetector* fRBS = nullptr;
    DamageCalculator* fDamage = nullptr;
    G4LogicalVolume* fLLayers[nMaxLayer]{};

    G4int fVoxelNumber;
    G4ThreeVector fVoxelSize[nMaxVoxel];
    G4double fVoxelMass[nMaxVoxel]{};
    G4ThreeVector fVoxelPosition[nMaxVoxel];
    G4LogicalVolume* fLVoxel[nMaxVoxel]{};

    DetectorMessenger* fDetectorMessenger;
    class MaterialMessenger* fMaterialMessenger;

    G4Cache<BFieldSetup*> fBFieldSetup;
    G4Cache<EFieldSetup*> fEFieldSetup;
};

//==============================================================================

inline G4double DetectorConstruction::GetLayerXmin(G4int n) const {
    G4double lXmin = -GetMultiLayerSizeX()/2;
    for (G4int i = 0; i < n; i++)
        lXmin += fLayerThickness[i];
    return lXmin;
}

//==============================================================================

#endif

