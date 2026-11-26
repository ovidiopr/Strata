//==============================================================================
/// \file Strata/include/StrataResults.hh
/// \brief Machine-readable snapshot of a finished run.
///
/// Run::EndOfRun() has always printed its results to G4cout.  That is fine
/// for a batch job but useless to a GUI, so the same numbers are also
/// published here, in a plain-old-data structure that can be handed across
/// a C ABI without any C++ types in the signature.
///
/// Units are Geant4 internal units throughout (MeV, mm, rad, gray); the
/// presentation layer is responsible for converting them for display.
//==============================================================================

#ifndef StrataResults_h
#define StrataResults_h 1

#include <atomic>
#include <mutex>
#include <map>
#include <vector>

//==============================================================================

// One thread's copy of one histogram, taken between events.  Raw counts:
// what end of run divides by is carried along rather than applied, because
// the number of events to divide by is still growing.
struct StrataLiveH1 {
    std::vector<double> centres, heights, errors;
    double entries = 0;
    double width = 0;      // bin width, for a dN/dx normalisation
    long   events = 0;     // events this thread has finished
    int    norm = 0;       // a StrataH1Norm
};

struct StrataRunStats {
    int    valid;                  ///< 0 until at least one run has finished
    long   events;                 ///< number of events processed

    char   particle[64];           ///< name of the primary particle
    double beamEnergy;             ///< kinetic energy of the primary
    double targetThickness;        ///< total thickness of the multilayer
    int    layers;                 ///< number of layers
    double meanDensity;            ///< sum of the layer densities

    double edep, edepRms;          ///< energy deposited per event
    double niel, nielRms;          ///< non-ionizing energy deposited per event
    double energyBalance;          ///< edep + leakage, per event

    double projRange, projRangeRms;
    double meanPrimarySteps;

    double trakLenCharged, trakLenChargedRms;
    double trakLenNeutral, trakLenNeutralRms;
    double stepsCharged, stepsChargedRms;
    double stepsNeutral, stepsNeutralRms;

    double gammaPerEvent, electronPerEvent, positronPerEvent;

    double transmitPrimary, transmitAny;   ///< per cent of events
    double reflectPrimary, reflectAny;     ///< per cent of events

    double leakPrimary, leakPrimaryRms;
    double leakSecondary, leakSecondaryRms;

    double meanDEdx;               ///< from the simulation
    double stoppingPower;          ///< meanDEdx scaled by the mean density
    double dedxRestricted;         ///< from the G4EmCalculator tables
    double dedxFull;
    double stopPowerRestricted;
    double stopPowerFull;

    double mscRms;                 ///< rms projected angle, central part
    double mscHighland;            ///< Highland formula
    double mscThetaCentral;        ///< half-width of the central part
    double mscTailRatio;           ///< per cent
};

//==============================================================================

struct StrataVoxelResult {
    double edep;    ///< cumulated energy deposited in the voxel
    double ratio;   ///< per cent of the total energy deposited
    double dose;    ///< edep / mass
    double mass;    ///< voxel mass
};

//==============================================================================
/// Process-wide store for the last finished run plus a live event counter.
///
/// Written from the Geant4 master thread at end of run, read by whichever
/// thread drives the user interface, so every access is guarded.
//==============================================================================

class StrataResultStore {
public:
    static StrataResultStore& Instance();

    /// Called by Run::EndOfRun() once the statistics are complete.
    void Publish(const StrataRunStats& stats,
                 const std::vector<StrataVoxelResult>& voxels);

    /// Copies out the last published run.  Returns false if there is none.
    bool Get(StrataRunStats& stats,
             std::vector<StrataVoxelResult>& voxels) const;

    void Clear();

    // --- live progress -------------------------------------------------
    /// Called at begin of run on the master thread.
    void BeginRun(long nEventsRequested);
    /// Called at end of every event, from any worker thread.
    void CountEvent() { fDone.fetch_add(1, std::memory_order_relaxed); }

    // --- aborting ------------------------------------------------------
    /// Asks the event loop to stop.  Called from whatever thread the front
    /// end lives on.
    ///
    /// G4RunManager::AbortRun() cannot be used from there: it reads the
    /// state manager, which is thread-local, so on any thread other than
    /// the one running the loop it sees G4State_PreInit, decides no run is
    /// in progress and returns without doing anything.  The loop therefore
    /// has to abort itself, which is what EventAction does at the end of
    /// each event when it sees this flag.
    void RequestAbort() { fAbort.store(true, std::memory_order_relaxed); }
    bool AbortRequested() const { return fAbort.load(std::memory_order_relaxed); }

    // --- live spectra ---------------------------------------------------
    /// Takes a copy of one histogram as the calling thread has it.
    ///
    /// In multithreaded mode Geant4 does not merge the worker histograms
    /// into the master until G4AnalysisManager::Write(), so during a run the
    /// master holds nothing and the only numbers that exist are the ones each
    /// worker has.  A worker cannot be asked for them from outside either,
    /// since the analysis manager is thread-local.  So each thread leaves a
    /// copy here between events and whoever wants to draw a spectrum while
    /// the run goes on adds the copies up.
    ///
    /// `slot` identifies the publishing thread and is its own for the life of
    /// the process.  Called from the thread that owns the histogram.
    void PublishH1(int slot, int id, const StrataLiveH1& copy);

    /// Adds up what every thread has published for one histogram, divided by
    /// the events so far exactly as end of run will divide it by the events
    /// in the whole run, so the curve keeps its scale when the run ends.
    /// Returns the number of bins written, or 0 when nothing has been
    /// published yet.  Called from whatever thread the front end lives on.
    int ReadH1(int id, double* centres, double* heights, double* errors,
               int maxBins, double* entries) const;

    long EventsDone() const { return fDone.load(std::memory_order_relaxed); }
    long EventsRequested() const { return fRequested.load(std::memory_order_relaxed); }

private:
    StrataResultStore() = default;

    mutable std::mutex fMutex;
    StrataRunStats fStats{};
    std::vector<StrataVoxelResult> fVoxels;

    std::map<int, std::vector<StrataLiveH1>> fLive;   // [histogram id][slot]
    mutable std::mutex fLiveMutex;

    std::atomic<bool> fAbort{false};
    std::atomic<long> fDone{0};
    std::atomic<long> fRequested{0};
};

//==============================================================================
#endif
