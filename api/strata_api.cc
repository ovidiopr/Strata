//==============================================================================
/// \file Strata/api/strata_api.cc
/// \brief Implementation of the flat C interface to the Strata backend.
///
/// See strata_api.h for the contract.  Everything in here runs either on the
/// caller's thread (bookkeeping only) or on the private engine thread (all
/// Geant4 calls, without exception).
//==============================================================================

#include "strata_api.h"

#include "DetectorConstruction.hh"
#include "PhysicsList.hh"
#include "ActionInitialization.hh"
#include "SteppingVerbose.hh"
#include "RandomSetup.hh"
#include "StrataResults.hh"
#include "RunAction.hh"
#include "DamageCalculator.hh"

#include "G4RunManagerFactory.hh"
#include "G4RunManager.hh"
#include "G4UImanager.hh"
#include "G4UIcommand.hh"
#include "G4UIcommandTree.hh"
#include "G4UIparameter.hh"
#include "G4ApplicationState.hh"
#include "G4UIsession.hh"
#include "G4NistManager.hh"
#include "G4ParticleTable.hh"
#include "G4ParticleDefinition.hh"
#include "G4Material.hh"
#include "G4Element.hh"
#include "G4Version.hh"
#include "G4SystemOfUnits.hh"
#include "HistoManager.hh"
#include "G4EnvironmentUtils.hh"
#include "G4VSteppingVerbose.hh"
#include "G4AnalysisManager.hh"
#include "G4ToolsAnalysisManager.hh"
#include "Randomize.hh"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <set>
#include <vector>

#include <atomic>
#include <cstdio>
#include <iostream>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <ctime>
#include <deque>
#include <functional>
#include <mutex>
#include <limits>
#include <string>
#include <thread>
#include <vector>

#if defined(_WIN32)
#  include <process.h>
#else
#  include <unistd.h>
#endif

namespace {

/// Sets or, with an empty value, removes a variable in this library's own
/// environment
void SetEnv(const char* name, const char* value) {
#if defined(_WIN32)
    ::_putenv_s(name, value == nullptr ? "" : value);
#else
    if (value == nullptr || *value == '\0')
        ::unsetenv(name);
    else
        ::setenv(name, value, 1);
#endif
}

}  // namespace

//==============================================================================
namespace {

constexpr const char* kStrataVersion = "1.0.0";

/// Upper bound on the log ring buffer
constexpr std::size_t kMaxLogLines = 50000;

//------------------------------------------------------------------------------
/// Names accepted by /strata/physics/addPhysics
struct PhysicsEntry { const char* name; int optional; };

const PhysicsEntry kPhysicsLists[] = {
    // Local lists
    {"local",             0}, {"standardSS",        0}, {"standardNR",        0},
    {"srim",              0},
    // From geant4/source/physics_lists/builders
    {"standard_opt0",     0}, {"standard_opt1",     0}, {"standard_opt2",     0},
    {"standard_opt3",     0}, {"standard_opt4",     0}, {"standardATIMA",     0},
    {"ionGasModels",      0}, {"standardWVI",       0}, {"standardGS",        0},
    {"standard5D",        0}, {"livermore",         0}, {"penelope",          0},
    {"lowenergy",         0}, {"dna",               0}, {"dna_opt2",          0},
    {"dna_opt4",          0}, {"dna_opt6",          0},
    // Hadron therapy
    {"hadron_therapy",    0}, {"hadron_therapy_hp", 0},
    // Neutrons
    {"neutron_hp",        0},
    // Optional add-ons
    {"rad_decay",         1}, {"binary_cascade",    1}, {"extra_physics",     1},
    {"elastic",           1}, {"elastic_hp",        1}, {"elastic_hpt",       1},
    {"DElastic",          1},
    {"HElastic",          1}, {"binary",            1}, {"binary_ion",        1},
    {"gamma_nuc",         1}, {"stopping",          1}, {"qgsp_bic",          1},
    {"qgsp_bic_hp",       1}, {"neutron_tracking",  1}
};

constexpr int kPhysicsCount =
    static_cast<int>(sizeof(kPhysicsLists) / sizeof(kPhysicsLists[0]));

// Copies a std::string into a caller-supplied buffer
void CopyOut(const std::string& src, char* dst, int dstLen) {
    if (dst == nullptr || dstLen <= 0) return;
    const std::size_t n =
        std::min(src.size(), static_cast<std::size_t>(dstLen - 1));
    std::memcpy(dst, src.data(), n);
    dst[n] = '\0';
}

void CopyOut(const std::string& src, char* dst, std::size_t dstLen) {
    CopyOut(src, dst, static_cast<int>(dstLen));
}

}  // namespace

//==============================================================================
// Captures G4cout / G4cerr into a bounded, line-oriented ring buffer
//==============================================================================
class StrataLogSink : public G4UIsession {
public:
    struct Line { std::string text; bool isError; };

    G4int ReceiveG4cout(const G4String& msg) override { return Append(msg, false); }
    G4int ReceiveG4cerr(const G4String& msg) override { return Append(msg, true); }

    bool Pop(Line& out) {
        std::lock_guard<std::mutex> lock(fMutex);
        if (fLines.empty()) return false;
        out = std::move(fLines.front());
        fLines.pop_front();
        return true;
    }

    std::size_t Pending() const {
        std::lock_guard<std::mutex> lock(fMutex);
        return fLines.size();
    }

    void Clear() {
        std::lock_guard<std::mutex> lock(fMutex);
        fLines.clear();
        fPartialOut.clear();
        fPartialErr.clear();
        fDropped = 0;
    }

    long Dropped() const { return fDropped.load(std::memory_order_relaxed); }

private:
    G4int Append(const G4String& msg, bool isError) {
        std::lock_guard<std::mutex> lock(fMutex);
        std::string& partial = isError ? fPartialErr : fPartialOut;
        for (const char c : msg) {
            if (c == '\n') {
                Push(partial, isError);
                partial.clear();
            } else if (c != '\r') {
                partial.push_back(c);
            }
        }
        return 0;
    }

    void Push(const std::string& text, bool isError) {
        if (fLines.size() >= kMaxLogLines) {
            fLines.pop_front();
            fDropped.fetch_add(1, std::memory_order_relaxed);
        }
        fLines.push_back(Line{text, isError});
    }

    mutable std::mutex fMutex;
    std::deque<Line> fLines;
    std::string fPartialOut, fPartialErr;
    std::atomic<long> fDropped{0};
};

//==============================================================================
// One Geant4 session, owned by a private engine thread
//==============================================================================
struct StrataSession {
    // --- engine thread -------------------------------------------------
    std::thread              thread;
    std::mutex               queueMutex;
    std::condition_variable  queueCv;
    std::deque<std::function<void()>> tasks;
    bool                     stopRequested = false;

    // Handshake for startup: the constructor blocks until the engine has
    // either built the run manager or failed trying
    std::mutex               startMutex;
    std::condition_variable  startCv;
    bool                     started = false;
    bool                     startOk = false;

    // Signalled whenever a beamOn task completes.
    std::mutex               runMutex;
    std::condition_variable  runCv;

    // Geant4, only ever touched on the engine thread
    G4RunManager*            runManager = nullptr;
    DetectorConstruction*    detector = nullptr;
    int                      nThreads = 0;

    // Shared state
    std::atomic<int>  state{STRATA_STATE_IDLE};
    std::atomic<int>  runStatus{STRATA_OK};
    StrataLogSink     log;

    std::mutex        errorMutex;
    std::string       lastError;

    void SetError(const std::string& msg) {
        std::lock_guard<std::mutex> lock(errorMutex);
        lastError = msg;
    }

    // Queues a task
    void Post(std::function<void()> fn, bool wait) {
        if (!wait) {
            std::lock_guard<std::mutex> lock(queueMutex);
            tasks.push_back(std::move(fn));
            queueCv.notify_one();
            return;
        }

        std::mutex doneMutex;
        std::condition_variable doneCv;
        bool done = false;

        {
            std::lock_guard<std::mutex> lock(queueMutex);
            tasks.push_back([&] {
                fn();
                std::lock_guard<std::mutex> l(doneMutex);
                done = true;
                doneCv.notify_one();
            });
            queueCv.notify_one();
        }

        std::unique_lock<std::mutex> lock(doneMutex);
        doneCv.wait(lock, [&] { return done; });
    }
};

//==============================================================================
namespace {

// There can be only one Geant4's live session
std::mutex gSingletonMutex;
StrataSession* gSession = nullptr;

/// Engine thread entry point
void EngineMain(StrataSession* s, int nThreads) {
    bool ok = true;
    try {
        G4UImanager::GetUIpointer()->SetCoutDestination(&s->log);

        RandomSetup::Instance()->Apply();

        // A front end gets its histograms through strata_get_h1_data(), so
        // the run does not write them
        RunAction::SetWriteHistograms(false);

        G4VSteppingVerbose::SetInstance(new SteppingVerbose);

        if (nThreads > 0) {
            s->runManager = G4RunManagerFactory::CreateRunManager(
                G4RunManagerType::MT, nThreads);
            s->nThreads = nThreads;
        } else {
            s->runManager = G4RunManagerFactory::CreateRunManager(
                G4RunManagerType::SerialOnly);
            s->nThreads = 0;
        }

        s->detector = new DetectorConstruction();
        s->runManager->SetUserInitialization(s->detector);
        s->runManager->SetUserInitialization(new PhysicsList());
        s->runManager->SetUserInitialization(
            new ActionInitialization(s->detector));
    } catch (const std::exception& e) {
        s->SetError(std::string("Geant4 initialisation failed: ") + e.what());
        ok = false;
    } catch (...) {
        s->SetError("Geant4 initialisation failed with an unknown exception");
        ok = false;
    }

    {
        std::lock_guard<std::mutex> lock(s->startMutex);
        s->started = true;
        s->startOk = ok;
        s->startCv.notify_all();
    }
    if (!ok) return;

    // Serve the queue
    for (;;) {
        std::function<void()> task;
        {
            std::unique_lock<std::mutex> lock(s->queueMutex);
            s->queueCv.wait(lock, [s] {
                return s->stopRequested || !s->tasks.empty();
            });
            if (s->stopRequested && s->tasks.empty()) break;
            task = std::move(s->tasks.front());
            s->tasks.pop_front();
        }
        try {
            task();
        } catch (const std::exception& e) {
            s->SetError(std::string("exception on the engine thread: ") + e.what());
        } catch (...) {
            s->SetError("unknown exception on the engine thread");
        }
    }

    // Tear Geant4 down on the thread that built it
    delete s->runManager;
    s->runManager = nullptr;
    G4UImanager* ui = G4UImanager::GetUIpointer();
    if (ui != nullptr) ui->SetCoutDestination(nullptr);
}

// Applies a UI command on the engine thread and translates the Geant4 return code
int ApplyOnEngine(StrataSession* s, const std::string& command) {
    G4UImanager* ui = G4UImanager::GetUIpointer();
    if (ui == nullptr) {
        s->SetError("no G4UImanager");
        return STRATA_ERR_INTERNAL;
    }
    const G4int rc = ui->ApplyCommand(command);
    if (rc == fCommandSucceeded) return STRATA_OK;

    s->SetError("command rejected by Geant4 (code " + std::to_string(rc) +
                "): " + command);
    return STRATA_ERR_COMMAND;
}

// Guard used at the top of every exported function
inline bool Valid(StrataSession* s) { return s != nullptr && s->runManager != nullptr; }

}  // namespace

//==============================================================================
// Lifecycle
//==============================================================================

extern "C" int strata_struct_size(int which) {
    switch (which) {
        case STRATA_SIZE_RUN_STATS:    return static_cast<int>(sizeof(StrataRunStatsC));
        case STRATA_SIZE_VOXEL_RESULT: return static_cast<int>(sizeof(StrataVoxelResultC));
        case STRATA_SIZE_LAYER_INFO:   return static_cast<int>(sizeof(StrataLayerInfoC));
        case STRATA_SIZE_VOXEL_INFO:   return static_cast<int>(sizeof(StrataVoxelInfoC));
        case STRATA_SIZE_H1_INFO:      return static_cast<int>(sizeof(StrataH1InfoC));
        case STRATA_SIZE_DATASET:      return static_cast<int>(sizeof(StrataDatasetC));
        case STRATA_SIZE_MATERIAL_INFO: return static_cast<int>(sizeof(StrataMaterialInfoC));
        case STRATA_SIZE_ELEMENT_FRACTION: return static_cast<int>(sizeof(StrataElementFractionC));
        default:                       return STRATA_ERR_RANGE;
    }
}

//==============================================================================
// Datasets
//==============================================================================

namespace {

struct DatasetSpec {
    const char* variable;
    bool        required;      // Geant4 raises a fatal exception without it
};

// The twelve of Geant4 11, in the order geant4-config reports them
constexpr DatasetSpec kDatasets[] = {
    { "G4NEUTRONHPDATA",   false },
    { "G4LEDATA",          true  },
    { "G4LEVELGAMMADATA",  true  },
    { "G4RADIOACTIVEDATA", true  },
    { "G4PARTICLEXSDATA",  true  },
    { "G4PIIDATA",         false },
    { "G4REALSURFACEDATA", false },
    { "G4SAIDXSDATA",      false },
    { "G4ABLADATA",        true  },
    { "G4INCLDATA",        true  },
    { "G4ENSDFSTATEDATA",  true  },
    { "G4CHANNELINGDATA",  false }
};

constexpr int kDatasetCount =
    static_cast<int>(sizeof(kDatasets) / sizeof(kDatasets[0]));

// Whether a resolved path really holds a dataset
bool HoldsDataset(const char* path) {
    if (path == nullptr || *path == '\0') return false;

    std::error_code ec;
    const std::filesystem::path dir(path);
    if (!std::filesystem::is_directory(dir, ec)) return false;

    // The non-throwing iterator: an unreadable directory reads as empty
    // rather than as an exception crossing the C boundary
    std::filesystem::directory_iterator it(dir, ec), end;
    if (ec) return false;
    for (; it != end; it.increment(ec)) {
        if (ec) return false;
        const std::string name = it->path().filename().string();
        if (!name.empty() && name[0] == '.') continue;
        if (std::filesystem::is_regular_file(it->path(), ec)) return true;
    }
    return false;
}

}  // namespace

extern "C" int strata_set_data_dir(const char* dir) {
    {
        std::lock_guard<std::mutex> guard(gSingletonMutex);
        if (gSession != nullptr) return STRATA_ERR_STATE;
    }

    const bool clearing = (dir == nullptr || *dir == '\0');
    if (!clearing) {
        std::error_code ec;
        if (!std::filesystem::is_directory(dir, ec)) return STRATA_ERR_RANGE;
    }

    // A per-dataset variable beats GEANT4_DATA_DIR, so they go first
    for (const DatasetSpec& spec : kDatasets) SetEnv(spec.variable, "");

    SetEnv("GEANT4_DATA_DIR", clearing ? "" : dir);
    return STRATA_OK;
}

extern "C" int strata_dataset_count(void) { return kDatasetCount; }

extern "C" int strata_get_dataset(int index, StrataDatasetC* out) {
    if (out == nullptr) return STRATA_ERR_HANDLE;
    if (index < 0 || index >= kDatasetCount) return STRATA_ERR_RANGE;

    const DatasetSpec& spec = kDatasets[index];
    std::memset(out, 0, sizeof(*out));
    CopyOut(spec.variable, out->variable, sizeof(out->variable));
    out->required = spec.required ? 1 : 0;

    const char* path = G4FindDataDir(spec.variable);
    if (path != nullptr && *path != '\0') {
        CopyOut(path, out->path, sizeof(out->path));
        out->present = HoldsDataset(path) ? 1 : 0;
    }
    return STRATA_OK;
}

extern "C" const char* strata_version(void) { return kStrataVersion; }

extern "C" const char* strata_geant4_version(void) {
    static const std::string v = []{
        std::string raw = G4Version;        // e.g. "$Name: geant4-11-04-patch-03 $"
        const std::size_t a = raw.find("geant4");
        if (a == std::string::npos) return raw;
        std::string s = raw.substr(a);
        const std::size_t b = s.find_last_not_of(" $");
        if (b != std::string::npos) s = s.substr(0, b + 1);
        return s;
    }();
    return v.c_str();
}

extern "C" StrataSession* strata_create(int nThreads) {
    std::lock_guard<std::mutex> guard(gSingletonMutex);
    if (gSession != nullptr) return nullptr;

    auto* s = new StrataSession();
    s->thread = std::thread(EngineMain, s, nThreads);

    {
        std::unique_lock<std::mutex> lock(s->startMutex);
        s->startCv.wait(lock, [s] { return s->started; });
    }

    if (!s->startOk) {
        {
            std::lock_guard<std::mutex> lock(s->queueMutex);
            s->stopRequested = true;
            s->queueCv.notify_all();
        }
        if (s->thread.joinable()) s->thread.join();
        delete s;
        return nullptr;
    }

    gSession = s;
    return s;
}

extern "C" void strata_destroy(StrataSession* s) {
    if (s == nullptr) return;

    if (s->state.load() == STRATA_STATE_RUNNING) {
        strata_abort(s);
        strata_wait(s, -1);
    }

    {
        std::lock_guard<std::mutex> lock(s->queueMutex);
        s->stopRequested = true;
        s->queueCv.notify_all();
    }
    if (s->thread.joinable()) s->thread.join();

    {
        std::lock_guard<std::mutex> guard(gSingletonMutex);
        if (gSession == s) gSession = nullptr;
    }
    delete s;
}

extern "C" int strata_initialize(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (s->state.load() == STRATA_STATE_RUNNING) return STRATA_ERR_STATE;

    int rc = STRATA_OK;
    s->Post([&] { rc = ApplyOnEngine(s, "/run/initialize"); }, true);
    if (rc == STRATA_OK) s->state.store(STRATA_STATE_INITIALISED);
    return rc;
}

extern "C" int strata_thread_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return s->nThreads;
}

//==============================================================================
// Control
//==============================================================================

extern "C" int strata_apply(StrataSession* s, const char* command) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (command == nullptr) return STRATA_ERR_RANGE;
    if (s->state.load() == STRATA_STATE_RUNNING) {
        s->SetError("cannot apply a command while a run is in progress");
        return STRATA_ERR_STATE;
    }

    const std::string cmd(command);
    int rc = STRATA_OK;
    s->Post([&] { rc = ApplyOnEngine(s, cmd); }, true);
    return rc;
}

extern "C" int strata_execute_macro(StrataSession* s, const char* path) {
    if (path == nullptr) return STRATA_ERR_RANGE;
    const std::string cmd = std::string("/control/execute ") + path;
    return strata_apply(s, cmd.c_str());
}

extern "C" int strata_beam_on(StrataSession* s, long nEvents) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (nEvents <= 0) return STRATA_ERR_RANGE;

    int expected = STRATA_STATE_INITIALISED;
    if (!s->state.compare_exchange_strong(expected, STRATA_STATE_RUNNING)) {
        s->SetError(expected == STRATA_STATE_IDLE
                        ? "the geometry has not been initialised yet"
                        : "a run is already in progress");
        return STRATA_ERR_STATE;
    }

    StrataResultStore::Instance().BeginRun(nEvents);
    s->runStatus.store(STRATA_OK);

    const std::string cmd = "/run/beamOn " + std::to_string(nEvents);
    s->Post([s, cmd] {
        const int rc = ApplyOnEngine(s, cmd);
        s->runStatus.store(rc);
        s->state.store(STRATA_STATE_INITIALISED);
        std::lock_guard<std::mutex> lock(s->runMutex);
        s->runCv.notify_all();
    }, false);

    return STRATA_OK;
}

extern "C" int strata_abort(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (s->state.load() != STRATA_STATE_RUNNING) return STRATA_ERR_STATE;

    s->state.store(STRATA_STATE_ABORTING);
    // This flag is picked up by EventAction at the end of the current event,
    // on the thread that is actually running it
    StrataResultStore::Instance().RequestAbort();
    return STRATA_OK;
}

extern "C" int strata_wait(StrataSession* s, int timeoutMs) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;

    std::unique_lock<std::mutex> lock(s->runMutex);
    const auto finished = [s] {
        const int st = s->state.load();
        return st != STRATA_STATE_RUNNING && st != STRATA_STATE_ABORTING;
    };
    if (timeoutMs < 0) {
        s->runCv.wait(lock, finished);
        return STRATA_OK;
    }
    return s->runCv.wait_for(lock, std::chrono::milliseconds(timeoutMs), finished)
               ? STRATA_OK
               : STRATA_ERR_STATE;
}

extern "C" int strata_state(StrataSession* s) {
    if (s == nullptr) return STRATA_ERR_HANDLE;
    return s->state.load();
}

extern "C" long strata_events_done(StrataSession*) {
    return StrataResultStore::Instance().EventsDone();
}

extern "C" long strata_events_requested(StrataSession*) {
    return StrataResultStore::Instance().EventsRequested();
}

extern "C" double strata_progress(StrataSession*) {
    const long total = StrataResultStore::Instance().EventsRequested();
    if (total <= 0) return 0.0;
    const double f = static_cast<double>(StrataResultStore::Instance().EventsDone())
                     / static_cast<double>(total);
    return f < 0.0 ? 0.0 : (f > 1.0 ? 1.0 : f);
}

extern "C" int strata_run_status(StrataSession* s) {
    if (s == nullptr) return STRATA_ERR_HANDLE;
    return s->runStatus.load();
}

//==============================================================================
// Log
//==============================================================================

extern "C" int strata_log_pop(StrataSession* s, char* buf, int bufLen,
                              int* isError) {
    if (s == nullptr || buf == nullptr || bufLen <= 0) return 0;
    StrataLogSink::Line line;
    if (!s->log.Pop(line)) return 0;
    CopyOut(line.text, buf, bufLen);
    if (isError != nullptr) *isError = line.isError ? 1 : 0;
    return 1;
}

extern "C" int strata_log_pending(StrataSession* s) {
    if (s == nullptr) return 0;
    return static_cast<int>(s->log.Pending());
}

extern "C" void strata_log_clear(StrataSession* s) {
    if (s != nullptr) s->log.Clear();
}

extern "C" long strata_log_dropped(StrataSession* s) {
    return s == nullptr ? 0 : s->log.Dropped();
}

//==============================================================================
// Results
//==============================================================================

extern "C" int strata_get_stats(StrataSession* s, StrataRunStatsC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (out == nullptr) return STRATA_ERR_RANGE;

    StrataRunStats stats{};
    std::vector<StrataVoxelResult> voxels;
    if (!StrataResultStore::Instance().Get(stats, voxels)) {
        s->SetError("no run has finished yet");
        return STRATA_ERR_STATE;
    }
    static_assert(sizeof(StrataRunStats) == sizeof(StrataRunStatsC),
                  "the C and C++ run-statistics layouts have diverged");
    std::memcpy(out, &stats, sizeof(StrataRunStatsC));
    return STRATA_OK;
}

extern "C" int strata_voxel_result_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    StrataRunStats stats{};
    std::vector<StrataVoxelResult> voxels;
    if (!StrataResultStore::Instance().Get(stats, voxels)) return 0;
    return static_cast<int>(voxels.size());
}

extern "C" int strata_get_voxel_result(StrataSession* s, int index,
                                       StrataVoxelResultC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (out == nullptr) return STRATA_ERR_RANGE;

    StrataRunStats stats{};
    std::vector<StrataVoxelResult> voxels;
    if (!StrataResultStore::Instance().Get(stats, voxels)) return STRATA_ERR_STATE;
    if (index < 0 || index >= static_cast<int>(voxels.size())) return STRATA_ERR_RANGE;

    out->edep  = voxels[index].edep;
    out->ratio = voxels[index].ratio;
    out->dose  = voxels[index].dose;
    out->mass  = voxels[index].mass;
    return STRATA_OK;
}

//==============================================================================
// Geometry introspection
//==============================================================================

extern "C" int strata_layer_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] { n = s->detector->GetLayerNumber(); }, true);
    return n;
}

extern "C" int strata_get_layer(StrataSession* s, int index,
                                StrataLayerInfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (out == nullptr) return STRATA_ERR_RANGE;

    int rc = STRATA_OK;
    s->Post([&] {
        if (index < 0 || index >= s->detector->GetLayerNumber()) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        out->thickness = s->detector->GetLayerThickness(index);
        out->xMin      = s->detector->GetLayerXmin(index);
        out->xMax      = s->detector->GetLayerXmax(index);
        G4Material* mat = s->detector->GetLayerMaterial(index);
        // The density the layer really has.  GetLayerDensity is the override
        // asked for, which is zero whenever the catalogue value was taken,
        // so reporting it said 0 for almost every layer there has ever been
        out->density   = (mat != nullptr) ? mat->GetDensity()/(g/cm3) : 0.;
        // The name asked for: a density or temperature variant is Strata's
        // own, and a configuration that saved its name could not be read back
        const G4String& asked = s->detector->GetLayerMaterialName(index);
        CopyOut(!asked.empty() ? std::string(asked)
                : (mat != nullptr ? std::string(mat->GetName()) : std::string("(none)")),
                out->material, sizeof(out->material));
    }, true);
    return rc;
}

extern "C" int strata_voxel_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] { n = s->detector->GetVoxelNumber(); }, true);
    return n;
}

extern "C" int strata_get_voxel(StrataSession* s, int index,
                                StrataVoxelInfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (out == nullptr) return STRATA_ERR_RANGE;

    int rc = STRATA_OK;
    s->Post([&] {
        if (index < 0 || index >= s->detector->GetVoxelNumber()) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        out->sizeX = s->detector->GetVoxelXmax(index) - s->detector->GetVoxelXmin(index);
        out->sizeY = s->detector->GetVoxelYmax(index) - s->detector->GetVoxelYmin(index);
        out->sizeZ = s->detector->GetVoxelZmax(index) - s->detector->GetVoxelZmin(index);
        out->posX  = 0.5*(s->detector->GetVoxelXmax(index) + s->detector->GetVoxelXmin(index));
        out->posY  = 0.5*(s->detector->GetVoxelYmax(index) + s->detector->GetVoxelYmin(index));
        out->posZ  = 0.5*(s->detector->GetVoxelZmax(index) + s->detector->GetVoxelZmin(index));
        out->mass  = s->detector->GetVoxelMass(index)/gram;
    }, true);
    return rc;
}

extern "C" int strata_world_size(StrataSession* s, double* sizeX, double* sizeYZ) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    s->Post([&] {
        if (sizeX  != nullptr) *sizeX  = s->detector->GetWorldSizeX();
        if (sizeYZ != nullptr) *sizeYZ = s->detector->GetWorldSizeYZ();
    }, true);
    return STRATA_OK;
}

extern "C" int strata_get_world_material(StrataSession* s, char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    s->Post([&] {
        const G4Material* mat = s->detector->GetWorldMaterial();
        CopyOut(mat != nullptr ? std::string(mat->GetName()) : std::string("(none)"), buf, bufLen);
    }, true);
    return STRATA_OK;
}

extern "C" int strata_get_random(StrataSession* s, char* engine, int engineCap,
                                long* seed1, long* seed2, int* randomize) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    // RandomSetup is process state, not session state, but it is read on the
    // engine thread all the same
    s->Post([&] {
        const RandomSetup* r = RandomSetup::Instance();
        if (engine != nullptr) CopyOut(std::string(r->EngineName()), engine, engineCap);
        if (seed1 != nullptr) *seed1 = r->Seed1();
        if (seed2 != nullptr) *seed2 = r->Seed2();
        if (randomize != nullptr) *randomize = r->Randomize() ? 1 : 0;
    }, true);
    return STRATA_OK;
}

extern "C" double strata_get_temperature(StrataSession* s) {
    if (!Valid(s)) return 0.0;
    double t = 0.0;
    s->Post([&] { t = s->detector->GetTemperature(); }, true);
    return t;
}

//==============================================================================
// Catalogues
//==============================================================================

extern "C" int strata_damage_defaults(const char* material, double* ed, double* b, double* c) {
    DamageConstants k;
    if (material == nullptr || !DamageCalculator::BuiltInFor(material, k)) return 0;
    if (ed != nullptr) *ed = k.ed/CLHEP::eV;
    if (b != nullptr) *b = k.bArc;
    if (c != nullptr) *c = k.cArc;
    return 1;
}

extern "C" int strata_material_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] {
        n = static_cast<int>(
            G4NistManager::Instance()->GetNistMaterialNames().size());
    }, true);
    return n;
}

//==============================================================================
// Which of Geant4's five groups each predefined material belongs to
//==============================================================================

namespace {

struct MaterialGroups {
    std::size_t elementsEnd = 0;   // one past the last element
    std::size_t hep = 0;           // first HEP and nuclear material
    std::size_t space = 0;         // first space material
    std::size_t bio = 0;           // first bio-chemical material
    bool valid = false;
};

std::size_t IndexOfMaterial(const std::vector<G4String>& names,
                            const char* wanted) {
    for (std::size_t i = 0; i < names.size(); ++i)
        if (names[i] == wanted) return i;
    return names.size();
}

const MaterialGroups& Groups() {
    static const MaterialGroups groups = [] {
        MaterialGroups g;
        auto* nist = G4NistManager::Instance();
        const auto& names = nist->GetNistMaterialNames();
        const auto& elements = nist->GetNistElementNames();
        if (names.empty() || elements.empty()) return g;

        // Index 0 is the slot Geant4 keeps water in; the elements follow, one
        // per element, named after it
        g.elementsEnd = 1;
        while (g.elementsEnd < names.size()) {
            const G4String& n = names[g.elementsEnd];
            if (n.size() < 4 || n.compare(0, 3, "G4_") != 0) break;
            const G4String symbol = n.substr(3);
            bool isElement = false;
            for (const G4String& e : elements)
                if (e == symbol) { isElement = true; break; }
            if (!isElement) break;
            ++g.elementsEnd;
        }

        g.hep = IndexOfMaterial(names, "G4_lH2");
        g.space = IndexOfMaterial(names, "G4_KEVLAR");
        g.bio = IndexOfMaterial(names, "G4_CYTOSINE");

        g.valid = (g.elementsEnd > 1)
                  && (g.elementsEnd <= g.hep)
                  && (g.hep < g.space)
                  && (g.space < g.bio)
                  && (g.bio < names.size());
        return g;
    }();
    return groups;
}

int GroupOf(std::size_t index, std::size_t count) {
    const MaterialGroups& g = Groups();
    if (!g.valid || index >= count) return STRATA_MATERIAL_UNKNOWN;
    if (index == 0) return STRATA_MATERIAL_NIST;          // the water slot
    if (index < g.elementsEnd) return STRATA_MATERIAL_ELEMENT;
    if (index < g.hep) return STRATA_MATERIAL_NIST;
    if (index < g.space) return STRATA_MATERIAL_HEP;
    if (index < g.bio) return STRATA_MATERIAL_SPACE;
    return STRATA_MATERIAL_BIO;
}

}  // namespace

extern "C" int strata_get_material_info(StrataSession* s, int index,
                                        StrataMaterialInfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (out == nullptr) return STRATA_ERR_HANDLE;

    int rc = STRATA_OK;
    std::memset(out, 0, sizeof(*out));
    s->Post([&] {
        auto* nist = G4NistManager::Instance();
        const auto& names = nist->GetNistMaterialNames();
        if (index < 0 || index >= static_cast<int>(names.size())) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        CopyOut(names[index], out->name, sizeof(out->name));
        out->group = GroupOf(static_cast<std::size_t>(index), names.size());
        // GetNominalDensity takes the material index, whatever its parameter
        // is called; for an element that happens to be the atomic number
        out->density = nist->GetNominalDensity(index)/(g/cm3);
    }, true);
    return rc;
}

extern "C" int strata_get_material_name(StrataSession* s, int index,
                                        char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int rc = STRATA_OK;
    s->Post([&] {
        const auto& names = G4NistManager::Instance()->GetNistMaterialNames();
        if (index < 0 || index >= static_cast<int>(names.size())) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        CopyOut(names[index], buf, bufLen);
    }, true);
    return rc;
}

extern "C" int strata_get_material_composition(StrataSession* s, const char* name,
                                               StrataElementFractionC* out, int maxOut) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (name == nullptr) return STRATA_ERR_HANDLE;

    int rc = STRATA_OK;
    s->Post([&] {
        // Anything already built answers for itself, which is what covers
        // the materials this session has defined; only a catalogue name
        // has to be built to be read
        G4Material* mat = G4Material::GetMaterial(name, false);
        if (mat == nullptr) mat = G4NistManager::Instance()->FindOrBuildMaterial(name);
        if (mat == nullptr) {
            rc = STRATA_ERR_RANGE;
            return;
        }

        const auto n = static_cast<int>(mat->GetNumberOfElements());
        if (out == nullptr) {
            rc = n;              // asked for the count alone
            return;
        }

        const G4ElementVector* elements = mat->GetElementVector();
        const G4double* massFraction = mat->GetFractionVector();
        const G4double* atomDensity = mat->GetVecNbOfAtomsPerVolume();
        const G4double total = mat->GetTotNbOfAtomsPerVolume();

        const int written = std::min(n, maxOut);
        for (int i = 0; i < written; i++) {
            const G4Element* e = (*elements)[i];
            std::memset(&out[i], 0, sizeof(out[i]));
            CopyOut(e->GetName(), out[i].name, sizeof(out[i].name));
            CopyOut(e->GetSymbol(), out[i].symbol, sizeof(out[i].symbol));
            out[i].z = e->GetZasInt();
            out[i].a = e->GetA()/(g/mole);
            out[i].massFraction = massFraction[i];
            out[i].atomFraction = (total > 0.) ? atomDensity[i]/total : 0.;
            out[i].atomDensity = atomDensity[i]*cm3;
        }
        rc = written;
    }, true);
    return rc;
}

namespace {

// The materials that are not in the NIST catalogue, in table order.  A
// catalogue material joins the material table the moment anything builds
// it -- using it in a geometry, or asking what it is made of -- and it is
// not one of this session's own for having been read.
std::vector<G4Material*> DefinedMaterials() {
    const auto& nist = G4NistManager::Instance()->GetNistMaterialNames();
    const std::set<G4String> catalogue(nist.begin(), nist.end());

    std::vector<G4Material*> out;
    // Nor are the density and temperature variants Strata makes of a
    // layer's material (name_strata_...): they are not anyone's to pick
    for (G4Material* m : *G4Material::GetMaterialTable())
        if (catalogue.find(m->GetName()) == catalogue.end()
            && m->GetName().find("_strata_") == G4String::npos) out.push_back(m);
    return out;
}

}  // namespace

extern "C" int strata_defined_material_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] {
        n = static_cast<int>(DefinedMaterials().size());
    }, true);
    return n;
}

extern "C" int strata_get_defined_material_name(StrataSession* s, int index,
                                                char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int rc = STRATA_OK;
    s->Post([&] {
        const std::vector<G4Material*> defined = DefinedMaterials();
        if (index < 0 || index >= static_cast<int>(defined.size())) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        CopyOut(defined[index]->GetName(), buf, bufLen);
    }, true);
    return rc;
}

extern "C" int strata_element_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] {
        n = static_cast<int>(
            G4NistManager::Instance()->GetNistElementNames().size());
    }, true);
    return n;
}

extern "C" int strata_get_element_name(StrataSession* s, int index,
                                       char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int rc = STRATA_OK;
    s->Post([&] {
        const auto& names = G4NistManager::Instance()->GetNistElementNames();
        if (index < 0 || index >= static_cast<int>(names.size())) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        CopyOut(names[index], buf, bufLen);
    }, true);
    return rc;
}

extern "C" int strata_physics_count(void) { return kPhysicsCount; }

extern "C" int strata_get_physics_name(int index, char* buf, int bufLen) {
    if (index < 0 || index >= kPhysicsCount) return STRATA_ERR_RANGE;
    CopyOut(kPhysicsLists[index].name, buf, bufLen);
    return STRATA_OK;
}

extern "C" int strata_physics_is_optional(int index) {
    if (index < 0 || index >= kPhysicsCount) return STRATA_ERR_RANGE;
    return kPhysicsLists[index].optional;
}

namespace {

// Tabs and line ends would break the record, so they are written escaped
std::string EscapeField(const std::string& text) {
    std::string out;
    out.reserve(text.size());
    for (const char ch : text) {
        switch (ch) {
            case '\\': out += "\\\\"; break;
            case '\n':  out += "\\n"; break;
            case '\t':  out += "\\t"; break;
            case '\r':  break;
            default:    out += ch;
        }
    }
    return out;
}

std::string GuidanceText(const G4UIcommand* command) {
    std::string text;
    if (command == nullptr) return text;
    for (std::size_t i = 0; i < command->GetGuidanceEntries(); ++i) {
        if (i > 0) text += '\n';
        text += command->GetGuidanceLine(static_cast<G4int>(i));
    }
    return text;
}

const char* StateName(G4ApplicationState state) {
    switch (state) {
        case G4State_PreInit:    return "PreInit";
        case G4State_Init:       return "Init";
        case G4State_Idle:       return "Idle";
        case G4State_GeomClosed: return "GeomClosed";
        case G4State_EventProc:  return "EventProc";
        case G4State_Quit:       return "Quit";
        case G4State_Abort:      return "Abort";
    }
    return "?";
}

// D <path> <guidance>
// C <path> <states> <range> <guidance>
// P <name> <type> <omittable> <current as default> <default> <candidates> <range> <guidance>
// A P record belongs to the C record before it
void DumpCommandTree(G4UIcommandTree* tree, std::string& out) {
    if (tree == nullptr) return;
    out += "D\t" + EscapeField(tree->GetPathName()) + "\t"
           + EscapeField(GuidanceText(tree->GetGuidance())) + "\n";
    for (G4int i = 1; i <= tree->GetCommandEntry(); ++i) {
        G4UIcommand* command = tree->GetCommand(i);
        if (command == nullptr) continue;
        std::string states;
        for (const G4ApplicationState state : *command->GetStateList()) {
            if (!states.empty()) states += ' ';
            states += StateName(state);
        }
        out += "C\t" + EscapeField(command->GetCommandPath()) + "\t" + states
               + "\t" + EscapeField(command->GetRange()) + "\t"
               + EscapeField(GuidanceText(command)) + "\n";
        for (std::size_t k = 0; k < command->GetParameterEntries(); ++k) {
            const G4UIparameter* p = command->GetParameter(static_cast<G4int>(k));
            if (p == nullptr) continue;
            out += "P\t" + EscapeField(p->GetParameterName()) + "\t"
                   + std::string(1, p->GetParameterType()) + "\t"
                   + (p->IsOmittable() ? "1" : "0") + "\t"
                   + (p->GetCurrentAsDefault() ? "1" : "0") + "\t"
                   + EscapeField(p->GetDefaultValue()) + "\t"
                   + EscapeField(p->GetParameterCandidates()) + "\t"
                   + EscapeField(p->GetParameterRange()) + "\t"
                   + EscapeField(p->GetParameterGuidance()) + "\n";
        }
    }
    for (G4int i = 1; i <= tree->GetTreeEntry(); ++i)
        DumpCommandTree(tree->GetTree(i), out);
}

}  // namespace

extern "C" int strata_get_command_tree(StrataSession* s, char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    std::string text = "# strata command tree 1\n";
    s->Post([&] {
        G4UImanager* ui = G4UImanager::GetUIpointer();
        if (ui != nullptr) DumpCommandTree(ui->GetTree(), text);
    }, true);
    if (text.size() + 1 > static_cast<std::size_t>(std::numeric_limits<int>::max()))
        return STRATA_ERR_RANGE;
    CopyOut(text, buf, bufLen);
    return static_cast<int>(text.size() + 1);
}

extern "C" int strata_particle_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] { n = G4ParticleTable::GetParticleTable()->entries(); }, true);
    return n;
}

extern "C" int strata_get_particle_name(StrataSession* s, int index,
                                        char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int rc = STRATA_OK;
    s->Post([&] {
        G4ParticleTable* table = G4ParticleTable::GetParticleTable();
        if (index < 0 || index >= table->entries()) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        G4ParticleDefinition* p = table->GetParticle(index);
        CopyOut(p != nullptr ? std::string(p->GetParticleName()) : std::string(), buf, bufLen);
    }, true);
    return rc;
}

//==============================================================================
// Histograms
//==============================================================================

extern "C" int strata_h1_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    int n = 0;
    s->Post([&] {
        n = static_cast<int>(G4AnalysisManager::Instance()->GetNofH1s());
    }, true);
    return n;
}

extern "C" int strata_get_h1_info(StrataSession* s, int id, StrataH1InfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (out == nullptr) return STRATA_ERR_RANGE;

    int rc = STRATA_OK;
    s->Post([&] {
        auto* am = G4AnalysisManager::Instance();
        if (id < 0 || id >= static_cast<int>(am->GetNofH1s())) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        out->id     = id;
        out->active = am->GetH1Activation(id) ? 1 : 0;
        out->nbins  = am->GetH1Nbins(id);
        out->axis   = static_cast<int>(StrataH1AxisOf(id));
        out->xMin   = am->GetH1Xmin(id);
        out->xMax   = am->GetH1Xmax(id);
        out->width  = am->GetH1Width(id);
        // Geant4 offers no accessor for the binning function, but it writes
        // it into the axis annotation it builds
        out->logX   = StrataH1IsLogX(id) ? 1 : 0;
        if (out->logX) {
            out->xMin = std::pow(10.0, out->xMin);
            out->xMax = std::pow(10.0, out->xMax);
        }
        const G4double unit = am->GetH1Unit(id);
        out->unit   = (unit > 0.) ? unit : 1.0;
        // Strata's own title, not Geant4's
        CopyOut(StrataH1TitleOf(id), out->title, sizeof(out->title));
        CopyOut(am->GetH1XAxisTitle(id), out->xAxisTitle, sizeof(out->xAxisTitle));

        CopyOut(StrataH1YLabel(id), out->yAxisTitle, sizeof(out->yAxisTitle));

        auto* h = am->GetH1(id, false);
        out->entries = (h != nullptr) ? static_cast<double>(h->all_entries()) : 0.0;
    }, true);
    return rc;
}

extern "C" int strata_get_h1_live(StrataSession* s, int id, double* centres,
                                  double* heights, double* errors, int maxBins,
                                  double* entries) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (centres == nullptr || heights == nullptr || maxBins <= 0)
        return STRATA_ERR_RANGE;

    // No Post: the engine thread is busy running the events, and what is
    // wanted is not its own histograms but the copies the worker threads left
    return StrataResultStore::Instance().ReadH1(id, centres, heights, errors,
                                                maxBins, entries);
}

extern "C" int strata_get_h1_data(StrataSession* s, int id, double* centres,
                                  double* heights, double* errors, int maxBins) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (centres == nullptr || heights == nullptr || maxBins <= 0)
        return STRATA_ERR_RANGE;

    int rc = 0;
    s->Post([&] {
        auto* am = G4AnalysisManager::Instance();
        if (id < 0 || id >= static_cast<int>(am->GetNofH1s())) {
            rc = STRATA_ERR_RANGE;
            return;
        }
        auto* h = am->GetH1(id, false);
        if (h == nullptr) {
            s->SetError("histogram " + std::to_string(id) + " has no data");
            rc = STRATA_ERR_STATE;
            return;
        }
        const int nbins = std::min(static_cast<int>(h->axis().bins()), maxBins);
        // The centres come back exactly as Geant4 holds them, which for a
        // logarithmic axis means log10 of the energy
        for (int i = 0; i < nbins; ++i) {
            centres[i] = h->axis().bin_center(i);
            heights[i] = h->bin_height(i);
            if (errors != nullptr) errors[i] = h->bin_error(i);
        }
        rc = nbins;
    }, true);
    return rc;
}

//==============================================================================
// Errors
//==============================================================================

extern "C" const char* strata_last_error(StrataSession* s) {
    static const char* kNoSession = "invalid session handle";
    if (s == nullptr) return kNoSession;
    std::lock_guard<std::mutex> lock(s->errorMutex);
    return s->lastError.c_str();
}

//==============================================================================
// Process termination
//==============================================================================

extern "C" void strata_exit_process(int code) {
    std::fflush(nullptr);
    std::cout.flush();
    std::cerr.flush();
    _exit(code);
}

//==============================================================================
