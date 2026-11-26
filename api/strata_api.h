/*============================================================================
 * Strata/api/strata_api.h
 *
 * Flat C interface to the Strata Geant4 backend.
 *
 * Why this layer exists
 * ---------------------
 * Geant4 is a C++ library whose public surface is built on virtual
 * inheritance, templates and name-mangled symbols.  Free Pascal can link
 * against C symbols only, so everything the front end needs is funnelled
 * through the functions below: plain C types, opaque handles, no exceptions
 * crossing the boundary, no ownership transferred to the caller.
 *
 * Threading model
 * ---------------
 * Geant4's run manager is tied to the thread that created it, and in
 * multithreaded mode that thread is the "master".  The library therefore
 * owns a private engine thread: strata_create() starts it, the run manager
 * is built there, and every call below is marshalled onto it.  Calls are
 * synchronous (they block until the engine has executed them) except
 * strata_beam_on(), which returns immediately and leaves the run going.
 *
 * The caller must never touch Geant4 directly, and must not call into this
 * library from more than one thread at a time for a given session.
 *
 * Progress and log output are polled, not pushed: no callback is ever
 * invoked on a foreign thread, which keeps the binding safe for GUI
 * toolkits (such as the LCL) that require all widget access to happen on
 * the main thread.
 *
 * All energies are in MeV, lengths in mm, angles in rad, doses in gray --
 * Geant4 internal units.  String arguments are NUL-terminated UTF-8.
 *==========================================================================*/

#ifndef STRATA_API_H
#define STRATA_API_H

#include <stddef.h>

#if defined(_WIN32)
#  if defined(STRATA_BUILDING_DLL)
#    define STRATA_API __declspec(dllexport)
#  else
#    define STRATA_API __declspec(dllimport)
#  endif
#  define STRATA_CALL __cdecl
#else
#  define STRATA_API __attribute__((visibility("default")))
#  define STRATA_CALL
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Status codes
typedef enum {
    STRATA_OK            =  0,
    STRATA_ERR_HANDLE    = -1,  // null or already destroyed session
    STRATA_ERR_STATE     = -2,  // wrong state, e.g. busy, or not initialised
    STRATA_ERR_COMMAND   = -3,  // the UI command was rejected by Geant4
    STRATA_ERR_RANGE     = -4,  // index out of range
    STRATA_ERR_INTERNAL  = -5   // a C++ exception was caught at the border
} StrataStatus;

// Engine states, as reported by strata_state()
typedef enum {
    STRATA_STATE_IDLE        = 0,  // created, geometry not built yet
    STRATA_STATE_INITIALISED = 1,  // /run/initialize done, ready to run
    STRATA_STATE_RUNNING     = 2,  // a beam is in progress
    STRATA_STATE_ABORTING    = 3   // abort requested, run still unwinding
} StrataState;

typedef struct StrataSession StrataSession;

//Run statistics
typedef struct {
    int    valid;
    long   events;

    char   particle[64];
    double beamEnergy;
    double targetThickness;
    int    layers;
    double meanDensity;          // g/cm3

    double edep, edepRms;
    double niel, nielRms;
    double energyBalance;

    double projRange, projRangeRms;
    double meanPrimarySteps;

    double trakLenCharged, trakLenChargedRms;
    double trakLenNeutral, trakLenNeutralRms;
    double stepsCharged, stepsChargedRms;
    double stepsNeutral, stepsNeutralRms;

    double gammaPerEvent, electronPerEvent, positronPerEvent;

    double transmitPrimary, transmitAny;
    double reflectPrimary, reflectAny;

    double leakPrimary, leakPrimaryRms;
    double leakSecondary, leakSecondaryRms;

    double meanDEdx;
    double stoppingPower;        // MeV cm2/g
    double dedxRestricted;       // MeV/mm
    double dedxFull;             // MeV/mm
    double stopPowerRestricted;  // MeV cm2/g
    double stopPowerFull;        // MeV cm2/g

    double mscRms;
    double mscHighland;
    double mscThetaCentral;
    double mscTailRatio;
} StrataRunStatsC;

// What one test volume absorbed
typedef struct {
    double edep;              // MeV, cumulative over the run
    double ratio;             // per cent of the energy the TARGET absorbed
    double dose;              // gray
    double mass;              // gram
} StrataVoxelResultC;

// Geometry description, read back from DetectorConstruction
typedef struct {
    double thickness;         // mm
    double density;
    double xMin, xMax;        // mm, from the entrance face
    char   material[128];
} StrataLayerInfoC;

typedef struct {
    double sizeX, sizeY, sizeZ;   // mm
    double posX, posY, posZ;      // mm, centre, in the target frame
    double mass;                  // gram
} StrataVoxelInfoC;

// What the x axis of a histogram measures
typedef enum {
    STRATA_AXIS_NONE      = 0,  // dimensionless, or a slot never shown
    STRATA_AXIS_LENGTH    = 1,  // a depth or a position in the target
    STRATA_AXIS_ENERGY    = 2,
    STRATA_AXIS_FWD_ANGLE = 3,  // leaves through the far face: 0..90 deg
    STRATA_AXIS_BACK_ANGLE= 4,  // comes back out: 90..180 deg
    STRATA_AXIS_LOG       = 5   // log10 of an energy, so dimensionless
} StrataAxisKind;

// One histogram, as held by G4AnalysisManager
typedef struct {
    int    id;
    int    active;
    int    nbins;
    int    axis;              // a StrataAxisKind
    double xMin, xMax, width;
    int    logX;
    // How large that unit is in Geant4's internal units
    double unit;
    double entries;
    char   title[256];
    char   xAxisTitle[128];
    // Geant4 keeps one axis annotation per dimension and an H1 has only one,
    // so it cannot hold a y-axis title; this is Strata's own
    char   yAxisTitle[128];
} StrataH1InfoC;

// One Geant4 dataset, as Geant4 itself resolves it
typedef struct {
    char variable[32];        // e.g. "G4LEDATA"
    char path[512];           // resolved directory, empty if unresolved
    int  present;             // 1 if path exists and is a directory
    int  required;            // 1 if Geant4 aborts when it is missing
} StrataDatasetC;

// Struct identifiers for strata_struct_size()
typedef enum {
    STRATA_SIZE_RUN_STATS     = 0,
    STRATA_SIZE_VOXEL_RESULT  = 1,
    STRATA_SIZE_LAYER_INFO    = 2,
    STRATA_SIZE_VOXEL_INFO    = 3,
    STRATA_SIZE_H1_INFO       = 4,
    STRATA_SIZE_DATASET       = 5,
    STRATA_SIZE_MATERIAL_INFO = 6,
    STRATA_SIZE_ELEMENT_FRACTION = 7
} StrataStructId;

// sizeof() the struct named by a StrataStructId, or STRATA_ERR_RANGE
STRATA_API int STRATA_CALL strata_struct_size(int which);

// Lifecycle

// Version of the library, "major.minor.patch"
STRATA_API const char* STRATA_CALL strata_version(void);

// Version of the Geant4 the library was built against
STRATA_API const char* STRATA_CALL strata_geant4_version(void);

// The Geant4 datasets, and whether Geant4 can find each one
STRATA_API int STRATA_CALL strata_dataset_count(void);
STRATA_API int STRATA_CALL strata_get_dataset(int index, StrataDatasetC* out);

// Points Geant4 at a directory of datasets, as geant4.sh does
STRATA_API int STRATA_CALL strata_set_data_dir(const char* dir);

// Creates the engine thread and the Geant4 run manager
STRATA_API StrataSession* STRATA_CALL strata_create(int nThreads);

// Aborts any running beam, tears down Geant4 and joins the engine thread
STRATA_API void STRATA_CALL strata_destroy(StrataSession* s);

// Builds the geometry and the physics tables (/run/initialize)
STRATA_API int STRATA_CALL strata_initialize(StrataSession* s);

// Number of worker threads actually in use (0 for a serial run manager)
STRATA_API int STRATA_CALL strata_thread_count(StrataSession* s);

// Control

// Applies one Geant4 UI command, e.g. "/strata/geometry/layerNumber 3"
STRATA_API int STRATA_CALL strata_apply(StrataSession* s, const char* command);

// Executes a macro file through /control/execute
STRATA_API int STRATA_CALL strata_execute_macro(StrataSession* s, const char* path);

// Starts a run of nEvents and returns immediately
STRATA_API int STRATA_CALL strata_beam_on(StrataSession* s, long nEvents);

// Requests a soft abort of the running beam
STRATA_API int STRATA_CALL strata_abort(StrataSession* s);

// Blocks until the current run finishes
STRATA_API int STRATA_CALL strata_wait(StrataSession* s, int timeoutMs);

STRATA_API int  STRATA_CALL strata_state(StrataSession* s);
STRATA_API long STRATA_CALL strata_events_done(StrataSession* s);
STRATA_API long STRATA_CALL strata_events_requested(StrataSession* s);
// Fraction in [0,1]; 0 if no run has been started
STRATA_API double STRATA_CALL strata_progress(StrataSession* s);
// STRATA_OK if the last run completed, STRATA_ERR_* otherwise
STRATA_API int STRATA_CALL strata_run_status(StrataSession* s);

// Log: G4cout and G4cerr are redirected into a bounded ring buffer

// Copies the oldest pending line into buf (NUL-terminated, truncated if
// needed) and removes it
STRATA_API int STRATA_CALL strata_log_pop(StrataSession* s, char* buf,
                                          int bufLen, int* isError);
STRATA_API int STRATA_CALL strata_log_pending(StrataSession* s);
STRATA_API void STRATA_CALL strata_log_clear(StrataSession* s);
// Lines dropped because the ring buffer was full since the last clear
STRATA_API long STRATA_CALL strata_log_dropped(StrataSession* s);

// Results

STRATA_API int STRATA_CALL strata_get_stats(StrataSession* s,
                                            StrataRunStatsC* out);
STRATA_API int STRATA_CALL strata_voxel_result_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_voxel_result(StrataSession* s, int index,
                                                   StrataVoxelResultC* out);

// Geometry introspection

STRATA_API int STRATA_CALL strata_layer_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_layer(StrataSession* s, int index,
                                            StrataLayerInfoC* out);
STRATA_API int STRATA_CALL strata_voxel_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_voxel(StrataSession* s, int index,
                                            StrataVoxelInfoC* out);
// Which generator is in use, the seeds it was given, and whether fresh
//  seeds are drawn for every run
STRATA_API int STRATA_CALL strata_get_random(StrataSession* s,
                                             char* engine, int engineCap,
                                             long* seed1, long* seed2,
                                             int* randomize);

STRATA_API int STRATA_CALL strata_world_size(StrataSession* s,
                                             double* sizeX, double* sizeYZ);
STRATA_API int STRATA_CALL strata_get_world_material(StrataSession* s,
                                                     char* buf, int bufLen);
STRATA_API double STRATA_CALL strata_get_temperature(StrataSession* s);

// Catalogues for populating the user interface
typedef enum {
    STRATA_MATERIAL_UNKNOWN = 0,
    STRATA_MATERIAL_ELEMENT = 1,   // G4_H ... G4_Cf, one per element
    STRATA_MATERIAL_NIST    = 2,   // the NIST compounds
    STRATA_MATERIAL_HEP     = 3,   // liquids, PbWO4, the alloys, CR39
    STRATA_MATERIAL_SPACE   = 4,   // Kevlar, Dacron, neoprene
    STRATA_MATERIAL_BIO     = 5    // the bases and the DNA set
} StrataMaterialGroup;

typedef struct {
    char   name[64];
    int    group;             // a StrataMaterialGroup
    double density;           // The density Geant4 would build it with, in g/cm3

} StrataMaterialInfoC;

// One element of a material
typedef struct {
    char   name[64];          // "Nitrogen"
    char   symbol[8];         // "N"
    int    z;                 // atomic number
    double a;                 // molar mass, g/mole
    double massFraction;      // of the material's mass, 0 to 1
    double atomFraction;      // of its atoms, 0 to 1
    double atomDensity;       // atoms per cm3

} StrataElementFractionC;

STRATA_API int STRATA_CALL strata_material_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_material_name(StrataSession* s, int index,
                                                    char* buf, int bufLen);

// The same material, with the group it belongs to and the density Geant4
// would build it with
STRATA_API int STRATA_CALL strata_get_material_info(StrataSession* s, int index,
                                                    StrataMaterialInfoC* out);

// What a material is made of, by name rather than by index so that the same
// call answers for the catalogue and for anything built in this session
STRATA_API int STRATA_CALL strata_get_material_composition(StrataSession* s,
                                                           const char* name,
                                                           StrataElementFractionC* out,
                                                           int maxOut);

// Built-in threshold displacement energy (eV) and arc-dpa constants of a
// material: 1 if it has them, 0 if not
STRATA_API int STRATA_CALL strata_damage_defaults(const char* material, double* ed,
                                                  double* b, double* c);

// Materials that are not in the NIST catalogue: the dozen Strata builds
// itself, and whatever this session has defined or given a new density to
STRATA_API int STRATA_CALL strata_defined_material_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_defined_material_name(StrataSession* s,
                                                    int index,
                                                    char* buf, int bufLen);

// Chemical element symbols known to NIST, e.g. "Si"; index from 0
STRATA_API int STRATA_CALL strata_element_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_element_name(StrataSession* s, int index,
                                                   char* buf, int bufLen);

// Physics list names accepted by /strata/physics/addPhysics
STRATA_API int STRATA_CALL strata_physics_count(void);
STRATA_API int STRATA_CALL strata_get_physics_name(int index, char* buf, int bufLen);
// 1 if the entry at index is an optional add-on rather than a base list
STRATA_API int STRATA_CALL strata_physics_is_optional(int index);

// Every Geant4 UI directory and command with its parameters, as text: one
// record per line, fields separated by tabs, see strata_api.cc for the
// layout.  Returns the length the text needs, terminator included, and
// copies as much as fits into buf (nothing when bufLen is 0).
STRATA_API int STRATA_CALL strata_get_command_tree(StrataSession* s,
                                                   char* buf, int bufLen);

// Particle names known to the particle table after initialisation
STRATA_API int STRATA_CALL strata_particle_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_particle_name(StrataSession* s, int index,
                                                    char* buf, int bufLen);

// Histograms

STRATA_API int STRATA_CALL strata_h1_count(StrataSession* s);
STRATA_API int STRATA_CALL strata_get_h1_info(StrataSession* s, int id,
                                              StrataH1InfoC* out);

// Fills centres[] and heights[] with up to maxBins points and returns the
// number written, or a negative StrataStatus
STRATA_API int STRATA_CALL strata_get_h1_data(StrataSession* s, int id,
                                              double* centres, double* heights,
                                              double* errors, int maxBins);

// The same points, as they stand while a run is still going
STRATA_API int STRATA_CALL strata_get_h1_live(StrataSession* s, int id,
                                              double* centres, double* heights,
                                              double* errors, int maxBins,
                                              double* entries);

// Errors
STRATA_API const char* STRATA_CALL strata_last_error(StrataSession* s);

// Process termination
STRATA_API void STRATA_CALL strata_exit_process(int code);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* STRATA_API_H */
