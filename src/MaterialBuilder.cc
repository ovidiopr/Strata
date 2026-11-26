//==============================================================================
/// \file Strata/src/MaterialBuilder.cc
/// \brief Implementation of MaterialBuilder
//==============================================================================

#include "MaterialBuilder.hh"

#include <cmath>

#include "G4Element.hh"
#include "G4Material.hh"
#include "G4NistManager.hh"
#include "G4SystemOfUnits.hh"
#include "G4UnitsTable.hh"

//==============================================================================

namespace {

/// Mass fractions have to add up to one
constexpr G4double kFractionTolerance = 1.0e-4;

}  // namespace

//==============================================================================

MaterialBuilder* MaterialBuilder::Instance() {
    static MaterialBuilder theBuilder;
    return &theBuilder;
}

//==============================================================================

G4bool MaterialBuilder::Fail(const G4String& reason) {
    fLastError = reason;
    G4cout << "### /strata/material: " << reason << G4endl;
    return false;
}

//==============================================================================

G4bool MaterialBuilder::CheckOpen() {
    if (!fOpen) {
        return Fail("no material is being defined; use "
                    "/strata/material/create first");
    }
    return true;
}

//==============================================================================

G4bool MaterialBuilder::Begin(const G4String& name, G4double density) {
    if (fOpen) {
        G4cout << "### /strata/material: the unfinished definition of '"
               << fName << "' is discarded" << G4endl;
    }

    fName.clear();
    fDensity = 0.;
    fParts.clear();
    fOpen = false;
    fLastError.clear();

    if (name.empty()) return Fail("a material needs a name");

    if (G4Material::GetMaterial(name, false) != nullptr) {
        return Fail("a material called '" + name + "' already exists; "
                    "pick another name");
    }

    if (density <= 0.) {
        return Fail("the density of '" + name + "' has to be greater "
                    "than zero");
    }

    fName = name;
    fDensity = density;
    fOpen = true;
    return true;
}

//==============================================================================

G4bool MaterialBuilder::AddMaterial(const G4String& name, G4double fraction) {
    if (!CheckOpen()) return false;

    if (fraction <= 0. || fraction > 1.) {
        return Fail("the mass fraction of '" + name + "' has to lie in "
                    "(0, 1]");
    }

    // FindOrBuildMaterial searches the material table before the NIST
    // catalogue, so a material defined here earlier can be a constituent
    if (G4NistManager::Instance()->FindOrBuildMaterial(name) == nullptr) {
        return Fail("no material called '" + name + "' is known; "
                    "/strata/material/list shows what is defined");
    }

    fParts.push_back({name, fraction, 0, true});
    return true;
}

//==============================================================================

G4bool MaterialBuilder::AddElement(const G4String& symbol, G4double fraction) {
    if (!CheckOpen()) return false;

    if (fraction <= 0. || fraction > 1.) {
        return Fail("the mass fraction of '" + symbol + "' has to lie in "
                    "(0, 1]");
    }

    if (G4NistManager::Instance()->FindOrBuildElement(symbol) == nullptr) {
        return Fail("no element with symbol '" + symbol + "' is known");
    }

    fParts.push_back({symbol, fraction, 0, false});
    return true;
}

//==============================================================================

G4bool MaterialBuilder::AddElementByAtoms(const G4String& symbol, G4int atoms) {
    if (!CheckOpen()) return false;

    if (atoms <= 0) {
        return Fail("the number of '" + symbol + "' atoms has to be at "
                    "least one");
    }

    if (G4NistManager::Instance()->FindOrBuildElement(symbol) == nullptr) {
        return Fail("no element with symbol '" + symbol + "' is known");
    }

    fParts.push_back({symbol, 0., atoms, false});
    return true;
}

//==============================================================================

G4bool MaterialBuilder::Build() {
    if (!CheckOpen()) return false;

    if (fParts.empty()) {
        return Fail("'" + fName + "' has no constituents");
    }

    G4int byAtoms = 0;
    G4int byFraction = 0;
    G4double sum = 0.;
    for (const auto& part : fParts) {
        if (part.atoms > 0) {
            ++byAtoms;
        } else {
            ++byFraction;
            sum += part.fraction;
        }
    }

    if (byAtoms > 0 && byFraction > 0) {
        return Fail("'" + fName + "' mixes numbers of atoms with mass "
                    "fractions; Geant4 allows only one or the other");
    }

    if (byFraction > 0 && std::abs(sum - 1.0) > kFractionTolerance) {
        std::ostringstream os;
        os << "the mass fractions of '" << fName << "' add up to " << sum
           << " instead of 1";
        return Fail(os.str());
    }

    // Nothing below is allowed to fail, so the material table is never left
    // holding a half-built material
    auto* material = new G4Material(fName, fDensity,
                                    static_cast<G4int>(fParts.size()));
    auto* nist = G4NistManager::Instance();

    for (const auto& part : fParts) {
        if (part.isMaterial) {
            material->AddMaterial(nist->FindOrBuildMaterial(part.name),
                                  part.fraction);
        } else if (part.atoms > 0) {
            material->AddElement(nist->FindOrBuildElement(part.name),
                                 part.atoms);
        } else {
            material->AddElement(nist->FindOrBuildElement(part.name),
                                 part.fraction);
        }
    }

    G4cout << "### /strata/material: created " << fName << " at "
           << G4BestUnit(fDensity, "Volumic Mass") << " from "
           << fParts.size() << " constituent(s)" << G4endl;

    fOpen = false;
    fParts.clear();
    fLastError.clear();
    return true;
}

//==============================================================================

void MaterialBuilder::Cancel() {
    if (fOpen) {
        G4cout << "### /strata/material: definition of '" << fName
               << "' cancelled" << G4endl;
    }
    fOpen = false;
    fName.clear();
    fParts.clear();
}

//==============================================================================

void MaterialBuilder::List() const {
    const G4MaterialTable* table = G4Material::GetMaterialTable();
    G4cout << "### /strata/material: " << table->size()
           << " material(s) defined" << G4endl;
    for (const auto* material : *table) {
        G4cout << "    " << material->GetName() << "   "
               << G4BestUnit(material->GetDensity(), "Volumic Mass") << "   "
               << material->GetNumberOfElements() << " element(s)" << G4endl;
    }
}

//==============================================================================

void MaterialBuilder::Print(const G4String& name) const {
    const G4Material* material = G4Material::GetMaterial(name, false);
    if (material == nullptr) {
        G4cout << "### /strata/material: '" << name << "' is not defined"
               << G4endl;
        return;
    }
    G4cout << *material << G4endl;
}
