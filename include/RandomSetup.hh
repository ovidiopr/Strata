//==============================================================================
//
//  RandomSetup.hh: which pseudo-random generator Strata uses, and how it is
//  seeded.
//
//  CLHEP's engine is process-global state: one engine, set once, shared by
//  the Geant4 kernel and by every model that draws a number.  This class is
//  the single place that writes it, so that the choice can be made from a
//  macro or a front end instead of by editing main().
//
//  The default is a different stream on every run.  PrepareRun() draws a
//  fresh pair of seeds from std::random_device before each run and prints
//  them in the form of the command that reproduces that run, so a result
//  that turns out to be interesting can be repeated exactly.  Setting the
//  seeds explicitly turns that off: from then on the run is whatever the
//  given seeds produce.
//
//==============================================================================

#ifndef RandomSetup_h
#define RandomSetup_h 1

#include "globals.hh"

#include <vector>

namespace CLHEP { class HepRandomEngine; }

class RandomMessenger;

class RandomSetup {
public:
    // The one instance, created on first use
    static RandomSetup* Instance();

    ~RandomSetup();

    RandomSetup(const RandomSetup&) = delete;
    RandomSetup& operator=(const RandomSetup&) = delete;

    // Names accepted by /strata/random/engine
    static const std::vector<G4String>& EngineNames();

    // Installs the chosen engine
    G4bool SetEngine(const G4String& name);

    const G4String& EngineName() const { return fEngineName; }

    // Switches automatic seeding off: the run that follows is reproducible
    void SetSeeds(long seed1, long seed2);

    // Back to a different stream on every run
    void SetRandomize(G4bool value);

    G4bool Randomize() const { return fRandomize; }
    long Seed1() const { return fSeed1; }
    long Seed2() const { return fSeed2; }

    // Installs the engine and the current seeds
    void Apply();

    // Called by RunAction on the master at the start of every run
    void PrepareRun();

    // The line that reproduces the current stream
    G4String ReproductionCommand() const;

    // Prints the engine, the seeds and how they were obtained
    void Print() const;

private:
    RandomSetup();

    // Two non-deterministic seeds
    static void DrawSeeds(long& seed1, long& seed2);

    RandomMessenger* fMessenger;

    // The engine this class allocated, if any
    CLHEP::HepRandomEngine* fOwnedEngine;

    G4String fEngineName;
    G4String fAppliedEngine;

    long fSeed1;
    long fSeed2;
    G4bool fRandomize;
    G4bool fSeedsApplied;
};

#endif
