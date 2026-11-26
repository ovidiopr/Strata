//==============================================================================
//
//  RandomSetup.cc: see RandomSetup.hh.
//
//==============================================================================

#include "RandomSetup.hh"
#include "RandomMessenger.hh"

#include "Randomize.hh"
#include "G4Threading.hh"
#include "G4RunManager.hh"

#include "CLHEP/Random/RanecuEngine.h"
#include "CLHEP/Random/MixMaxRng.h"
#include "CLHEP/Random/MTwistEngine.h"
#include "CLHEP/Random/Ranlux64Engine.h"
#include "CLHEP/Random/RanluxppEngine.h"
#include "CLHEP/Random/JamesRandom.h"

#include <algorithm>
#include <random>
#include <sstream>

namespace {

/// The largest seed RanecuEngine accepts; the other engines take anything
constexpr long kMaxSeed = 2147483562L;

}  // namespace

//==============================================================================

RandomSetup* RandomSetup::Instance() {
    static RandomSetup theSetup;
    return &theSetup;
}

//==============================================================================

RandomSetup::RandomSetup()
        : fMessenger(nullptr),
          fOwnedEngine(nullptr),
          fEngineName(EngineNames().front()),
          fAppliedEngine(""),
          fSeed1(0),
          fSeed2(0),
          fRandomize(true),
          fSeedsApplied(false) {
    DrawSeeds(fSeed1, fSeed2);
    fMessenger = new RandomMessenger(this);
}

//==============================================================================

RandomSetup::~RandomSetup() {
    delete fMessenger;
    // Not the engine: CLHEP still points at it for as long as anything can
    // draw a number, and this object outlives the run manager only at exit
}

//==============================================================================

const std::vector<G4String>& RandomSetup::EngineNames() {
    static const std::vector<G4String> names = {
        "ranecu",    // CLHEP::RanecuEngine     Strata's default
        "mixmax",    // CLHEP::MixMaxRng
        "mtwist",    // CLHEP::MTwistEngine
        "ranlux64",  // CLHEP::Ranlux64Engine
        "ranluxpp",  // CLHEP::RanluxppEngine
        "james"      // CLHEP::HepJamesRandom   Geant4's own default
    };
    return names;
}

//==============================================================================

void RandomSetup::DrawSeeds(long& seed1, long& seed2) {
    std::random_device rd;
    // Two draws of the device, widened so that implementations with a
    // 32-bit result still fill the range, and reduced to what RanecuEngine
    // will take
    const unsigned long long a =
        (static_cast<unsigned long long>(rd()) << 32) ^ rd();
    const unsigned long long b =
        (static_cast<unsigned long long>(rd()) << 32) ^ rd();
    seed1 = static_cast<long>(a % static_cast<unsigned long long>(kMaxSeed)) + 1;
    seed2 = static_cast<long>(b % static_cast<unsigned long long>(kMaxSeed)) + 1;
}

//==============================================================================

G4bool RandomSetup::SetEngine(const G4String& name) {
    const std::vector<G4String>& names = EngineNames();
    if (std::find(names.begin(), names.end(), name) == names.end()) {
        G4cout << "RandomSetup: '" << name << "' is not a generator Strata "
               << "knows; the engine is unchanged." << G4endl;
        return false;
    }
    fEngineName = name;
    return true;
}

//==============================================================================

void RandomSetup::SetSeeds(long seed1, long seed2) {
    if (seed1 < 1) seed1 = 1;
    if (seed2 < 1) seed2 = 1;
    if (seed1 > kMaxSeed) seed1 = 1 + (seed1 % kMaxSeed);
    if (seed2 > kMaxSeed) seed2 = 1 + (seed2 % kMaxSeed);

    fSeed1 = seed1;
    fSeed2 = seed2;
    fRandomize = false;
    fSeedsApplied = false;
}

//==============================================================================

void RandomSetup::SetRandomize(G4bool value) {
    fRandomize = value;
    if (value) {
        DrawSeeds(fSeed1, fSeed2);
        fSeedsApplied = false;
    }
}

//==============================================================================

void RandomSetup::Apply() {
    if (fAppliedEngine != fEngineName) {
        CLHEP::HepRandomEngine* engine = nullptr;
        if (fEngineName == "ranecu")        engine = new CLHEP::RanecuEngine;
        else if (fEngineName == "mixmax")   engine = new CLHEP::MixMaxRng;
        else if (fEngineName == "mtwist")   engine = new CLHEP::MTwistEngine;
        else if (fEngineName == "ranlux64") engine = new CLHEP::Ranlux64Engine;
        else if (fEngineName == "ranluxpp") engine = new CLHEP::RanluxppEngine;
        else if (fEngineName == "james")    engine = new CLHEP::HepJamesRandom;
        else                                engine = new CLHEP::RanecuEngine;

        CLHEP::HepRandom::setTheEngine(engine);
        // The engine that was in use is deliberately not deleted
        fOwnedEngine = engine;

        fAppliedEngine = fEngineName;
        fSeedsApplied = false;    // a new engine starts from its own default
    }

    if (!fSeedsApplied) {
        const long seeds[3] = {fSeed1, fSeed2, 0};
        CLHEP::HepRandom::setTheSeeds(seeds, 2);
        fSeedsApplied = true;
    }
}

//==============================================================================

void RandomSetup::PrepareRun() {
    // Workers draw from their own engine, seeded by the master from this
    // stream; only the master decides what the stream is
    if (!G4Threading::IsMasterThread()) return;

    if (fRandomize) {
        DrawSeeds(fSeed1, fSeed2);
        fSeedsApplied = false;
    }
    Apply();
    Print();

    // Fixed seeds reproduce a serial run exactly
    if (!fRandomize && G4RunManager::GetRunManager()
        && G4RunManager::GetRunManager()->GetNumberOfThreads() > 1)
        G4cout << "                exact repetition needs one thread; with "
               << "several, use /run/eventModulo 1 0 and expect the last "
               << "digits to move" << G4endl;
}

//==============================================================================

G4String RandomSetup::ReproductionCommand() const {
    std::ostringstream os;
    os << "/strata/random/seeds " << fSeed1 << " " << fSeed2;
    return os.str();
}

//==============================================================================

void RandomSetup::Print() const {
    G4cout << "Random numbers: " << fEngineName << ", seeds " << fSeed1
           << " " << fSeed2
           << (fRandomize ? " (drawn for this run)" : " (set by the user)")
           << G4endl;
    if (fRandomize)
        G4cout << "                repeat this run with:  "
               << ReproductionCommand() << G4endl;
}
