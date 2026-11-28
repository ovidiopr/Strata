//==============================================================================
/// \file Strata/include/MaterialBuilder.hh
/// \brief Builds G4Materials from a density and a list of constituents
///
/// A material is assembled in steps (open it, add constituents, close it)
/// because a Geant4 UI command carries only one line.  The constituents may
/// be other materials (anything already defined, including the NIST
/// catalogue and materials built here earlier) or chemical elements, mixed
/// freely, and are given either as mass fractions or as numbers of atoms.
/// An element may also be a single isotope, by mass fraction.
/// The two forms cannot be combined in one material: that is a Geant4
/// restriction, not one added here.
///
/// Nothing is created until Build() succeeds, so a definition that does not
/// add up leaves the material table untouched.
//==============================================================================

#ifndef MaterialBuilder_h
#define MaterialBuilder_h 1

#include <vector>

#include "globals.hh"

class G4Material;

//==============================================================================

class MaterialBuilder {
public:
    /// One instance per process; materials are global to Geant4.
    static MaterialBuilder* Instance();

    MaterialBuilder(const MaterialBuilder&) = delete;
    MaterialBuilder& operator=(const MaterialBuilder&) = delete;

    /// Opens a definition.  density is in Geant4 units.  Any definition
    /// still open is discarded, with a warning.
    G4bool Begin(const G4String& name, G4double density);

    /// Constituents.  fraction is a mass fraction in (0, 1]; atoms is a
    /// count.  Both report failure rather than throwing.
    G4bool AddMaterial(const G4String& name, G4double fraction);
    G4bool AddElement(const G4String& symbol, G4double fraction);
    G4bool AddElementByAtoms(const G4String& symbol, G4int atoms);
    /// One isotope (mass number a) of an element, by mass fraction
    G4bool AddIsotope(const G4String& symbol, G4int a, G4double fraction);

    /// Validates and creates the material.  On failure nothing is created
    /// and the definition stays open so it can be corrected.
    G4bool Build();

    /// Throws away a definition in progress.
    void Cancel();

    G4bool IsOpen() const { return fOpen; }
    const G4String& Name() const { return fName; }

    /// The reason the last call failed, for a front end to show.
    const G4String& LastError() const { return fLastError; }

    /// Prints every material currently defined, or one in full.
    void List() const;
    void Print(const G4String& name) const;

private:
    MaterialBuilder() = default;

    struct Constituent {
        G4String name;
        G4double fraction = 0.;   ///< mass fraction, when atoms == 0
        G4int    atoms    = 0;    ///< number of atoms, when non-zero
        G4bool   isMaterial = false;
        G4int    isotopeA = 0;    ///< mass number of a one-isotope element
    };

    G4bool Fail(const G4String& reason);
    G4bool CheckOpen();

    G4String fName;
    G4double fDensity = 0.;
    std::vector<Constituent> fParts;
    G4bool fOpen = false;
    G4String fLastError;
};

#endif
