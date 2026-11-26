//==============================================================================
/// \file Strata/include/SRIMStoppingData.hh
/// \brief Externally supplied electronic stopping powers.
///
/// Strata does not ship SRIM's stopping-power tables; they are SRIM's, they
/// are a fit rather than a theory, and redistributing them is not ours to
/// do.  What Strata ships is the mechanism: load a table you generated
/// yourself, and the "srim" physics list will use it instead of Geant4's
/// ICRU/ASTAR parameterisation wherever it applies.
///
/// Two input formats are accepted:
///
///   * the output of SRIM's "Stopping and Range Tables" module, saved as
///     text, in any of the length- or mass-normalised stopping units SRIM
///     offers;
///   * a plain columnar file with a short keyword header, which is easier to
///     produce from a script and is what `strata_dedx` writes.
///
/// A table is keyed by (particle name, material name).  Where no table has
/// been loaded the models fall back to Geant4, and say so once.
//==============================================================================

#ifndef SRIMStoppingData_h
#define SRIMStoppingData_h 1

#include "globals.hh"

#include <map>
#include <set>
#include <vector>

class G4Material;
class G4ParticleDefinition;

//==============================================================================
/// One projectile/target pair: a tabulated electronic stopping power, and
/// optionally the nuclear stopping power that came with it.
///
/// Both are stored in Geant4 internal units (energy per unit length) on an
/// energy grid in internal units, and interpolated as a cubic spline in
/// log-log space, which is how stopping powers behave over a wide energy
/// range.
//==============================================================================
class SRIMStoppingTable {
public:
    SRIMStoppingTable();
    ~SRIMStoppingTable();

    /// Fills the table.  Energies must be increasing and positive; dE/dx
    /// values must be positive.  Returns false, with a reason in \a error,
    /// if the data cannot be interpolated.
    G4bool Build(const std::vector<G4double>& energies,
                 const std::vector<G4double>& electronic,
                 const std::vector<G4double>& nuclear,
                 G4String& error);

    /// Electronic stopping power at \a kinEnergy.  Outside the tabulated
    /// range the end values are held constant rather than extrapolated: a
    /// spline run off the end of a stopping-power table produces nonsense,
    /// and the caller is told through InRange() if it matters.
    G4double ElectronicDEDX(G4double kinEnergy) const;

    /// Nuclear stopping power, or 0 if the file carried no such column.
    ///
    /// Not used for transport.  Nuclear stopping in Strata comes from
    /// G4ScreenedNuclearRecoil, which produces the recoils themselves and so
    /// fills the NIEL spectra; adding SRIM's tabulated nuclear stopping on
    /// top of it would count the same energy loss twice.  The column is read
    /// and kept so that the two can be compared (see doc/srim-comparison.md)
    /// and reported, not so that it can be used.
    G4double NuclearDEDX(G4double kinEnergy) const;

    G4bool HasNuclear() const { return fHasNuclear; }
    G4bool InRange(G4double kinEnergy) const {
        return kinEnergy >= fEmin && kinEnergy <= fEmax;
    }
    G4double Emin() const { return fEmin; }
    G4double Emax() const { return fEmax; }
    size_t Points() const { return fPoints; }

    void SetSource(const G4String& s) { fSource = s; }
    const G4String& GetSource() const { return fSource; }

private:
    SRIMStoppingTable(const SRIMStoppingTable&) = delete;
    SRIMStoppingTable& operator=(const SRIMStoppingTable&) = delete;

    void* fElectronic;   ///< log_log_interpolating_function_p<G4double>*
    void* fNuclear;      ///< ditto, or null
    G4bool fHasNuclear;
    G4double fEmin, fEmax;
    G4double fDEDXmin, fDEDXmax;      ///< clamped end values, electronic
    G4double fNuclearMin, fNuclearMax;
    size_t fPoints;
    G4String fSource;
};

//==============================================================================
/// Process-wide registry of loaded tables.
///
/// Read from Geant4 worker threads during tracking, written only from the
/// master before /run/initialize, which is the same discipline the material
/// table follows.  Loading a table once a run has started is refused.
//==============================================================================
class SRIMStoppingData {
public:
    static SRIMStoppingData& Instance();

    /// Parses \a fileName and stores it under (particle, material).
    /// \a particleName is a Geant4 particle name ("proton", "alpha",
    /// "GenericIon", or an ion name such as "He3"); \a materialName is a
    /// Geant4 material name as it appears in the material table.
    /// Returns false and fills \a error on any problem.
    G4bool LoadFile(const G4String& particleName,
                    const G4String& materialName,
                    const G4String& fileName,
                    G4String& error);

    /// Looks up a table.  Returns null when none was loaded for the pair.
    const SRIMStoppingTable* Find(const G4ParticleDefinition* particle,
                                  const G4Material* material) const;

    /// Convenience used by the models: true when a table covers this point,
    /// in which case \a dedx receives the unrestricted electronic stopping
    /// power.  Also records the pair for the end-of-initialisation report.
    G4bool GetElectronicDEDX(const G4ParticleDefinition* particle,
                             const G4Material* material,
                             G4double kinEnergy,
                             G4double& dedx) const;

    void Clear();
    size_t Size() const { return fTables.size(); }

    /// Prints what is loaded and, after a run, which pairs actually fell
    /// back to Geant4.  Worth reading before trusting a comparison.
    void Print() const;

    /// Names of the loaded tables, "particle in material".
    std::vector<G4String> Keys() const;

private:
    SRIMStoppingData() = default;
    ~SRIMStoppingData();
    SRIMStoppingData(const SRIMStoppingData&) = delete;
    SRIMStoppingData& operator=(const SRIMStoppingData&) = delete;

    static G4String MakeKey(const G4String& particle, const G4String& material);

    std::map<G4String, SRIMStoppingTable*> fTables;
    mutable std::set<G4String> fUsed;       ///< pairs served from a table
    mutable std::set<G4String> fFellBack;   ///< pairs served by Geant4
};

//==============================================================================
#endif
