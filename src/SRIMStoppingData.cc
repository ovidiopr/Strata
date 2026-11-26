//==============================================================================
/// \file Strata/src/SRIMStoppingData.cc
/// \brief Implementation of SRIMStoppingTable and SRIMStoppingData
//==============================================================================

#include "SRIMStoppingData.hh"

#include "c2_function.hh"

#include "G4Material.hh"
#include "G4ParticleDefinition.hh"
#include "G4RunManager.hh"
#include "G4StateManager.hh"
#include "G4SystemOfUnits.hh"
#include "G4UnitsTable.hh"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <sstream>

//==============================================================================
namespace {

using Interp = log_log_interpolating_function_p<G4double>;

/// Lower-cases and trims a token, so that "MeV/(mg/cm2)" and
/// " MeV / (mg/cm2) " compare equal after whitespace is removed.
G4String Squash(const G4String& s) {
    G4String out;
    for (const char c : s)
        if (!std::isspace(static_cast<unsigned char>(c)))
            out.push_back(static_cast<char>(std::tolower(
                static_cast<unsigned char>(c))));
    return out;
}

G4bool IsNumber(const G4String& s, G4double& value) {
    if (s.empty()) return false;
    char* end = nullptr;
    value = std::strtod(s.c_str(), &end);
    return end != nullptr && *end == '\0';
}

/// Energy units as SRIM writes them in the first column.
G4bool EnergyUnit(const G4String& token, G4double& factor) {
    const G4String u = Squash(token);
    if (u == "ev")  { factor = eV;  return true; }
    if (u == "kev") { factor = keV; return true; }
    if (u == "mev") { factor = MeV; return true; }
    if (u == "gev") { factor = GeV; return true; }
    return false;
}

/// Converts a SRIM "Stopping Units" string into a multiplier that turns a
/// tabulated number into Geant4 internal units of energy per length.
/// Mass-normalised units need the target density, which SRIM also prints.
///
/// \return false for units Strata cannot convert (SRIM also offers
/// "eV / (1E15 atoms/cm2)" and L.S.S. reduced units, which need the areal
/// atom density or the reduced-energy scaling rather than a mass density).
G4bool StoppingUnitFactor(const G4String& text, G4double density,
                          G4double& factor, G4String& why) {
    const G4String u = Squash(text);

    struct Entry { const char* key; G4double energy; G4double length; };
    static const Entry perLength[] = {
        {"ev/angstrom", eV,  angstrom},
        {"kev/micron",  keV, micrometer},
        {"kev/um",      keV, micrometer},
        {"mev/mm",      MeV, mm},
        {"kev/mm",      keV, mm},
        {"mev/cm",      MeV, cm},
        {"kev/nm",      keV, nanometer},
        {"ev/nm",       eV,  nanometer}
    };
    for (const auto& e : perLength)
        if (u == Squash(e.key)) { factor = e.energy/e.length; return true; }

    struct MassEntry { const char* key; G4double energy; G4double areal; };
    static const MassEntry perMass[] = {
        {"mev/(mg/cm2)", MeV, mg/cm2},
        {"kev/(mg/cm2)", keV, mg/cm2},
        {"ev/(mg/cm2)",  eV,  mg/cm2},
        {"kev/(ug/cm2)", keV, 1.e-6*gram/cm2},
        {"ev/(ug/cm2)",  eV,  1.e-6*gram/cm2},
        {"mev/(g/cm2)",  MeV, g/cm2},
        {"kev/(g/cm2)",  keV, g/cm2}
    };
    for (const auto& e : perMass) {
        if (u != Squash(e.key)) continue;
        if (density <= 0.) {
            why = "the file uses mass-normalised stopping units but no target "
                  "density was found in it; add a '# density <value> g/cm3' "
                  "line or re-export SRIM with length units";
            return false;
        }
        factor = (e.energy/e.areal)*density;
        return true;
    }

    why = "unsupported stopping units '" + text + "'. Strata converts the "
          "length-normalised units (eV/Angstrom, keV/micron, MeV/mm, ...) and "
          "the mass-normalised ones (MeV/(mg/cm2), keV/(ug/cm2), ...); "
          "re-export from SRIM choosing one of those";
    return false;
}

}  // namespace

//==============================================================================
// SRIMStoppingTable
//==============================================================================

SRIMStoppingTable::SRIMStoppingTable()
    : fElectronic(nullptr), fNuclear(nullptr), fHasNuclear(false),
      fEmin(0.), fEmax(0.), fDEDXmin(0.), fDEDXmax(0.),
      fNuclearMin(0.), fNuclearMax(0.), fPoints(0) {}

//==============================================================================

SRIMStoppingTable::~SRIMStoppingTable() {
    delete static_cast<Interp*>(fElectronic);
    delete static_cast<Interp*>(fNuclear);
}

//==============================================================================

G4bool SRIMStoppingTable::Build(const std::vector<G4double>& energies,
                                const std::vector<G4double>& electronic,
                                const std::vector<G4double>& nuclear,
                                G4String& error) {
    if (energies.size() < 3) {
        error = "a stopping table needs at least three points";
        return false;
    }
    if (electronic.size() != energies.size()) {
        error = "energy and electronic dE/dx columns have different lengths";
        return false;
    }
    for (size_t i = 0; i < energies.size(); ++i) {
        if (energies[i] <= 0. || electronic[i] <= 0.) {
            error = "energies and electronic dE/dx must all be positive "
                    "(log-log interpolation)";
            return false;
        }
        if (i > 0 && energies[i] <= energies[i - 1]) {
            error = "energies must increase strictly";
            return false;
        }
    }

    try {
        auto* e = new Interp();
        e->load(energies, electronic, true, 0., true, 0.);
        fElectronic = e;
    } catch (const c2_exception& ex) {
        error = G4String("could not spline the electronic column: ") + ex.what();
        return false;
    }

    fHasNuclear = (nuclear.size() == energies.size());
    if (fHasNuclear) {
        for (const G4double v : nuclear)
            if (v <= 0.) { fHasNuclear = false; break; }
    }
    if (fHasNuclear) {
        try {
            auto* n = new Interp();
            n->load(energies, nuclear, true, 0., true, 0.);
            fNuclear = n;
            fNuclearMin = nuclear.front();
            fNuclearMax = nuclear.back();
        } catch (const c2_exception&) {
            fHasNuclear = false;      // not fatal: it is never used in transport
        }
    }

    fEmin = energies.front();
    fEmax = energies.back();
    fDEDXmin = electronic.front();
    fDEDXmax = electronic.back();
    fPoints = energies.size();
    return true;
}

//==============================================================================

G4double SRIMStoppingTable::ElectronicDEDX(G4double kinEnergy) const {
    if (fElectronic == nullptr) return 0.;
    if (kinEnergy <= fEmin) return fDEDXmin;
    if (kinEnergy >= fEmax) return fDEDXmax;
    return (*static_cast<Interp*>(fElectronic))(kinEnergy);
}

//==============================================================================

G4double SRIMStoppingTable::NuclearDEDX(G4double kinEnergy) const {
    if (!fHasNuclear || fNuclear == nullptr) return 0.;
    if (kinEnergy <= fEmin) return fNuclearMin;
    if (kinEnergy >= fEmax) return fNuclearMax;
    return (*static_cast<Interp*>(fNuclear))(kinEnergy);
}

//==============================================================================
// SRIMStoppingData
//==============================================================================

SRIMStoppingData& SRIMStoppingData::Instance() {
    static SRIMStoppingData theData;
    return theData;
}

//==============================================================================

SRIMStoppingData::~SRIMStoppingData() {
    for (auto& entry : fTables) delete entry.second;
}

//==============================================================================

G4String SRIMStoppingData::MakeKey(const G4String& particle,
                                   const G4String& material) {
    return particle + "|" + material;
}

//==============================================================================

void SRIMStoppingData::Clear() {
    for (auto& entry : fTables) delete entry.second;
    fTables.clear();
    fUsed.clear();
    fFellBack.clear();
}

//==============================================================================

std::vector<G4String> SRIMStoppingData::Keys() const {
    std::vector<G4String> out;
    out.reserve(fTables.size());
    for (const auto& entry : fTables) {
        G4String k = entry.first;
        const size_t sep = k.find('|');
        if (sep != std::string::npos) k[sep] = ' ';
        out.push_back(k);
    }
    return out;
}

//==============================================================================

const SRIMStoppingTable*
SRIMStoppingData::Find(const G4ParticleDefinition* particle,
                       const G4Material* material) const {
    if (particle == nullptr || material == nullptr) return nullptr;

    // An exact particle name wins; a generic entry for all ions is the
    // fallback, which is how a single "GenericIon in Si" table can serve a
    // whole beam cocktail.
    auto it = fTables.find(MakeKey(particle->GetParticleName(),
                                   material->GetName()));
    if (it != fTables.end()) return it->second;

    if (particle->GetAtomicNumber() > 0 || particle->GetPDGCharge() != 0.) {
        it = fTables.find(MakeKey("GenericIon", material->GetName()));
        if (it != fTables.end()) return it->second;
    }
    return nullptr;
}

//==============================================================================

G4bool SRIMStoppingData::GetElectronicDEDX(const G4ParticleDefinition* particle,
                                           const G4Material* material,
                                           G4double kinEnergy,
                                           G4double& dedx) const {
    const SRIMStoppingTable* table = Find(particle, material);
    const G4String key = (particle != nullptr && material != nullptr)
        ? particle->GetParticleName() + " in " + material->GetName()
        : G4String("(unknown)");

    if (table == nullptr || !table->InRange(kinEnergy)) {
        fFellBack.insert(key);
        return false;
    }
    dedx = table->ElectronicDEDX(kinEnergy);
    fUsed.insert(key);
    return true;
}

//==============================================================================

void SRIMStoppingData::Print() const {
    G4cout << "\n===== External stopping-power tables =====" << G4endl;
    if (fTables.empty()) {
        G4cout << " none loaded; the srim list is running entirely on Geant4's "
               << "own ICRU/ASTAR parameterisation." << G4endl;
    }
    for (const auto& entry : fTables) {
        G4String k = entry.first;
        const size_t sep = k.find('|');
        if (sep != std::string::npos) k.replace(sep, 1, " in ");
        const SRIMStoppingTable* t = entry.second;
        G4cout << "  " << k << ": " << t->Points() << " points, "
               << G4BestUnit(t->Emin(), "Energy") << " to "
               << G4BestUnit(t->Emax(), "Energy")
               << (t->HasNuclear() ? ", with nuclear column" : "")
               << "\n      from " << t->GetSource() << G4endl;
    }
    if (!fUsed.empty()) {
        G4cout << " served from a table:" << G4endl;
        for (const auto& k : fUsed) G4cout << "   " << k << G4endl;
    }
    if (!fFellBack.empty()) {
        G4cout << " fell back to Geant4 (no table, or outside its range):"
               << G4endl;
        for (const auto& k : fFellBack) G4cout << "   " << k << G4endl;
    }
    G4cout << "==========================================\n" << G4endl;
}

//==============================================================================

G4bool SRIMStoppingData::LoadFile(const G4String& particleName,
                                  const G4String& materialName,
                                  const G4String& fileName,
                                  G4String& error) {
    error = "";

    G4RunManager* rm = G4RunManager::GetRunManager();
    if (rm != nullptr && rm->GetCurrentRun() != nullptr
        && G4StateManager::GetStateManager()->GetCurrentState() == G4State_EventProc) {
        error = "stopping tables cannot be loaded while a run is in progress";
        return false;
    }

    std::ifstream in(fileName.c_str());
    if (!in) {
        error = "cannot open '" + fileName + "'";
        return false;
    }

    // Scan
    G4double density = 0.;                 // internal units
    G4String stoppingUnits;                // as written in the file
    G4double headerEnergyUnit = 0.;        // simple format only
    std::vector<G4double> energy, elec, nucl;

    G4String line;
    while (std::getline(in, line)) {
        // Strip a trailing CR so that files written on Windows parse.
        if (!line.empty() && line.back() == '\r') line.pop_back();

        const G4String squashed = Squash(line);

        // SRIM: " Target Density =  2.3200E+00 g/cm3 = 6.99E+22 atoms/cm3"
        if (squashed.find("targetdensity=") != std::string::npos
            || squashed.rfind("#density", 0) == 0) {
            std::istringstream ls(line);
            G4String token;
            G4double value = 0.;
            while (ls >> token) {
                G4double v;
                if (IsNumber(token, v)) { value = v; continue; }
                if (Squash(token) == "g/cm3" && value > 0.) {
                    density = value*g/cm3;
                    break;
                }
            }
            continue;
        }

        // SRIM: " Stopping Units =  MeV / (mg/cm2)"
        const size_t su = squashed.find("stoppingunits=");
        if (su != std::string::npos) {
            const size_t eq = line.find('=', line.find("nits"));
            if (eq != std::string::npos) stoppingUnits = line.substr(eq + 1);
            continue;
        }

        // Simple format header keywords.
        if (!line.empty() && line[0] == '#') {
            std::istringstream ls(line.substr(1));
            G4String key, value;
            ls >> key >> value;
            const G4String k = Squash(key);
            if (k == "dedx_unit" || k == "stopping_unit") stoppingUnits = value;
            else if (k == "energy_unit") {
                G4double f;
                if (EnergyUnit(value, f)) headerEnergyUnit = f;
            }
            continue;
        }

        // Data rows
        std::istringstream ls(line);
        std::vector<G4String> tok;
        G4String t;
        while (ls >> t) tok.push_back(t);
        if (tok.size() < 2) continue;

        G4double e = 0., se = 0., sn = 0.;
        if (!IsNumber(tok[0], e) || e <= 0.) continue;

        size_t next = 1;
        G4double eUnit = headerEnergyUnit;
        G4double unitFactor;
        if (EnergyUnit(tok[1], unitFactor)) {          // SRIM style: "10.00 eV"
            eUnit = unitFactor;
            next = 2;
        }
        if (eUnit <= 0.) continue;                      // no unit anywhere yet

        if (tok.size() <= next || !IsNumber(tok[next], se) || se <= 0.) continue;
        const G4bool haveNuclear =
            (tok.size() > next + 1) && IsNumber(tok[next + 1], sn) && sn > 0.;

        energy.push_back(e*eUnit);
        elec.push_back(se);
        nucl.push_back(haveNuclear ? sn : -1.);
    }

    if (energy.empty()) {
        error = "no data rows recognised in '" + fileName + "'. Expected either "
                "SRIM 'Stopping and Range Tables' output, or columns of "
                "energy / electronic dE/dx / nuclear dE/dx with a "
                "'# energy_unit' and '# dedx_unit' header";
        return false;
    }
    if (stoppingUnits.empty()) {
        error = "the stopping-power units are not declared in '" + fileName
              + "'. SRIM writes a 'Stopping Units =' line; for a plain "
                "columnar file add '# dedx_unit keV/um' or similar";
        return false;
    }

    G4double factor = 0.;
    G4String why;
    if (!StoppingUnitFactor(stoppingUnits, density, factor, why)) {
        error = why;
        return false;
    }

    G4bool allNuclear = true;
    for (size_t i = 0; i < elec.size(); ++i) {
        elec[i] *= factor;
        if (nucl[i] > 0.) nucl[i] *= factor; else allNuclear = false;
    }
    if (!allNuclear) nucl.clear();

    auto* table = new SRIMStoppingTable();
    G4String buildError;
    if (!table->Build(energy, elec, nucl, buildError)) {
        delete table;
        error = "'" + fileName + "': " + buildError;
        return false;
    }
    table->SetSource(fileName);

    const G4String key = MakeKey(particleName, materialName);
    auto existing = fTables.find(key);
    if (existing != fTables.end()) {
        delete existing->second;
        existing->second = table;
    } else {
        fTables[key] = table;
    }

    G4cout << "Strata: loaded stopping table for " << particleName << " in "
           << materialName << " -- " << table->Points() << " points, "
           << G4BestUnit(table->Emin(), "Energy") << " to "
           << G4BestUnit(table->Emax(), "Energy")
           << (table->HasNuclear() ? ", nuclear column present" : "")
           << G4endl;
    return true;
}

//==============================================================================
