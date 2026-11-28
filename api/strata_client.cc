//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/api/strata_client.cc
// \brief strata_api.h over a pipe to an engine process.
//
// Every entry point of strata_api.h is here a second time, forwarding to
// the engine process instead of to Geant4 in this one.  A front end links
// this or the library itself and cannot tell the difference, except that
// the engine can now be killed and started again, and that a fatal
// exception in Geant4 no longer takes the front end with it.
//
// The engine executable is named by STRATA_ENGINE, or looked for beside
// the current working directory.

#include "strata_api.h"
#include "strata_protocol.hh"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

using namespace strata;

// The handle a front end holds.  The engine owns the only real session, so
// this says no more than whether one has been made
int gHandle = 0;

Process gChild = kNoProcess;
std::string gDataDir;        // replayed to every new child
Pipe gToChild = kNoPipe;
Pipe gFromChild = kNoPipe;
std::string gError;

// Closing our ends is what tells the engine to leave; it is given a moment
// to do so before it is killed
constexpr int kGraceMs = 2000;

void Reap() {
    PipeClose(gToChild);
    PipeClose(gFromChild);
    ProcessStop(gChild, kGraceMs);
    gHandle = 0;
}

// The pipes broke.  An engine that ended says how, which is the difference
// between "stopped answering" and "could not find the Geant4 DLLs"
void EngineLost() {
    gError = "the engine process stopped answering";
    unsigned long code = 0;
    if (ProcessExitCode(gChild, 1000, code)) gError += ": " + ProcessExitText(code);
    Reap();
}

// Beside this library, then beside its bin directory, then the working
// directory.  STRATA_ENGINE overrides the lot
std::string EnginePath() {
    const std::string named = EngineOverride();
    if (!named.empty()) return named;

    const std::string dir = ThisLibraryDir();
    if (!dir.empty()) {
        const std::string beside = dir + "/" + kEngineName;
        if (Runnable(beside)) return beside;
        const std::string installed = dir + "/../bin/" + kEngineName;
        if (Runnable(installed)) return installed;
    }
    return std::string("./") + kEngineName;
}

// Requests go in on the child's descriptor 3, responses out on its 4
bool Spawn() {
    if (gChild != kNoProcess) return true;

    PipeEnds toChild;
    PipeEnds fromChild;
    if (!PipePair(toChild, true)) return false;
    if (!PipePair(fromChild, false)) {
        PipeClose(toChild.parent);
        PipeClose(toChild.child);
        return false;
    }

    const std::string path = EnginePath();
    if (!ProcessStart(path, toChild, fromChild, gChild)) {
        PipeClose(toChild.parent);
        PipeClose(toChild.child);
        PipeClose(fromChild.parent);
        PipeClose(fromChild.child);
        gError = "cannot start the engine process (" + path + ")";
        return false;
    }

    // The engine holds the other two now
    PipeClose(toChild.child);
    PipeClose(fromChild.child);
    gToChild = toChild.parent;
    gFromChild = fromChild.parent;

    // A new child has not been told where the datasets are
    if (!gDataDir.empty()) {
        Writer w;
        w.Str(gDataDir.c_str());
        std::uint32_t echoed = 0;
        std::vector<unsigned char> reply;
        if (!WriteFrame(gToChild, kSetDataDir, w.Bytes())
            || !ReadFrame(gFromChild, echoed, reply)
            || echoed != kSetDataDir) {
            EngineLost();
            return false;
        }
    }
    return true;
}

// One request, one response.  A dead engine leaves the reply empty, and
// every caller reads zeros out of it rather than stale numbers
bool Call(std::uint32_t op, const Writer& request, std::vector<unsigned char>& reply) {
    reply.clear();
    if (!Spawn()) return false;

    std::uint32_t echoed = 0;
    if (!WriteFrame(gToChild, op, request.Bytes())
        || !ReadFrame(gFromChild, echoed, reply)
        || echoed != op) {
        EngineLost();
        return false;
    }
    return true;
}

// The shapes that come back often enough to be worth a helper
int CallInt(std::uint32_t op, const Writer& request) {
    std::vector<unsigned char> reply;
    if (!Call(op, request, reply)) return STRATA_ERR_STATE;
    Reader in(reply.data(), reply.size());
    return in.I32();
}

long CallLong(std::uint32_t op) {
    std::vector<unsigned char> reply;
    if (!Call(op, Writer(), reply)) return 0;
    Reader in(reply.data(), reply.size());
    return static_cast<long>(in.I64());
}

double CallDouble(std::uint32_t op) {
    std::vector<unsigned char> reply;
    if (!Call(op, Writer(), reply)) return 0.;
    Reader in(reply.data(), reply.size());
    return in.F64();
}

// A name written into the caller's buffer
int CallName(std::uint32_t op, const Writer& request, char* buf, int bufLen) {
    std::vector<unsigned char> reply;
    if (!Call(op, request, reply)) return STRATA_ERR_STATE;
    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    const std::string name = in.Str();
    if (buf != nullptr && bufLen > 0) {
        const std::size_t n = std::min(static_cast<std::size_t>(bufLen - 1),
                                       name.size());
        std::memcpy(buf, name.data(), n);
        buf[n] = '\0';
    }
    return rc;
}

// A struct written into the caller's struct.  Whether the caller passed one
// at all is forwarded, so that the engine's own function decides what a
// missing one means rather than this side guessing: the library answers
// STRATA_ERR_RANGE for some of these and STRATA_ERR_HANDLE for others
int CallStruct(std::uint32_t op, Writer& request, void* out, std::size_t size) {
    request.I32(out != nullptr ? 1 : 0);
    if (out != nullptr) std::memset(out, 0, size);

    std::vector<unsigned char> reply;
    if (!Call(op, request, reply)) return STRATA_ERR_STATE;
    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    if (out != nullptr) in.Raw(out, size);
    return rc;
}

bool Valid(StrataSession* s) { return s != nullptr && gChild != kNoProcess; }

}  // namespace

//==============================================================================

extern "C" int strata_struct_size(int which) {
    Writer w;
    w.I32(which);
    return CallInt(kStructSize, w);
}

extern "C" const char* strata_version(void) {
    static std::string value;
    std::vector<unsigned char> reply;
    if (!Call(kVersion, Writer(), reply)) return "";
    Reader in(reply.data(), reply.size());
    value = in.Str();
    return value.c_str();
}

extern "C" const char* strata_geant4_version(void) {
    static std::string value;
    std::vector<unsigned char> reply;
    if (!Call(kGeant4Version, Writer(), reply)) return "";
    Reader in(reply.data(), reply.size());
    value = in.Str();
    return value.c_str();
}

extern "C" int strata_dataset_count(void) {
    return CallInt(kDatasetCount, Writer());
}

extern "C" int strata_get_dataset(int index, StrataDatasetC* out) {
    Writer w;
    w.I32(index);
    return CallStruct(kGetDataset, w, out, sizeof(*out));
}

extern "C" int strata_set_data_dir(const char* dir) {
    gDataDir = (dir != nullptr) ? dir : "";
    Writer w;
    w.Str(dir);
    return CallInt(kSetDataDir, w);
}

//==============================================================================

extern "C" StrataSession* strata_create(int nThreads) {
    if (gHandle != 0) return nullptr;
    Writer w;
    w.I32(nThreads);
    if (CallInt(kCreate, w) != 1) return nullptr;
    gHandle = 1;
    return reinterpret_cast<StrataSession*>(&gHandle);
}

extern "C" void strata_destroy(StrataSession* s) {
    if (!Valid(s)) return;
    // An engine busy with a command would only answer when it is done
    if (CallInt(kBusy, Writer()) != 1) {
        std::vector<unsigned char> reply;
        Call(kDestroy, Writer(), reply);
    }
    Reap();
}

extern "C" int strata_initialize(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kInitialize, Writer());
}

extern "C" int strata_thread_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kThreadCount, Writer());
}

extern "C" int strata_apply(StrataSession* s, const char* command) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.Str(command);
    return CallInt(kApply, w);
}

extern "C" int strata_execute_macro(StrataSession* s, const char* path) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.Str(path);
    return CallInt(kExecuteMacro, w);
}

extern "C" int strata_initialize_start(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kInitializeStart, Writer());
}

extern "C" int strata_apply_start(StrataSession* s, const char* command) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.Str(command);
    return CallInt(kApplyStart, w);
}

extern "C" int strata_busy(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kBusy, Writer());
}

extern "C" int strata_command_status(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kCommandStatus, Writer());
}

extern "C" int strata_command_wait(StrataSession* s, int timeoutMs) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(timeoutMs);
    return CallInt(kCommandWait, w);
}

extern "C" int strata_beam_on(StrataSession* s, long nEvents) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I64(nEvents);
    return CallInt(kBeamOn, w);
}

extern "C" int strata_abort(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kAbort, Writer());
}

extern "C" int strata_wait(StrataSession* s, int timeoutMs) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(timeoutMs);
    return CallInt(kWait, w);
}

extern "C" int strata_state(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kState, Writer());
}

extern "C" long strata_events_done(StrataSession* s) {
    if (!Valid(s)) return 0;
    return CallLong(kEventsDone);
}

extern "C" long strata_events_requested(StrataSession* s) {
    if (!Valid(s)) return 0;
    return CallLong(kEventsRequested);
}

extern "C" double strata_progress(StrataSession* s) {
    if (!Valid(s)) return 0.;
    return CallDouble(kProgress);
}

extern "C" int strata_run_status(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kRunStatus, Writer());
}

//==============================================================================

extern "C" int strata_log_pop(StrataSession* s, char* buf, int bufLen, int* isError) {
    if (isError != nullptr) *isError = 0;
    if (!Valid(s)) return STRATA_ERR_HANDLE;

    Writer w;
    w.I32(bufLen);
    std::vector<unsigned char> reply;
    if (!Call(kLogPop, w, reply)) return STRATA_ERR_STATE;

    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    const std::string line = in.Str();
    const int flag = in.I32();
    if (buf != nullptr && bufLen > 0) {
        const std::size_t n = std::min(static_cast<std::size_t>(bufLen - 1),
                                       line.size());
        std::memcpy(buf, line.data(), n);
        buf[n] = '\0';
    }
    if (isError != nullptr) *isError = flag;
    return rc;
}

extern "C" int strata_log_pending(StrataSession* s) {
    if (!Valid(s)) return 0;
    return CallInt(kLogPending, Writer());
}

extern "C" void strata_log_clear(StrataSession* s) {
    if (!Valid(s)) return;
    std::vector<unsigned char> reply;
    Call(kLogClear, Writer(), reply);
}

extern "C" long strata_log_dropped(StrataSession* s) {
    if (!Valid(s)) return 0;
    return CallLong(kLogDropped);
}

//==============================================================================

extern "C" int strata_get_stats(StrataSession* s, StrataRunStatsC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    return CallStruct(kGetStats, w, out, sizeof(*out));
}

extern "C" int strata_voxel_result_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kVoxelResultCount, Writer());
}

extern "C" int strata_get_voxel_result(StrataSession* s, int index,
                                       StrataVoxelResultC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    return CallStruct(kGetVoxelResult, w, out, sizeof(*out));
}

extern "C" int strata_layer_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kLayerCount, Writer());
}

extern "C" int strata_get_layer(StrataSession* s, int index, StrataLayerInfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    return CallStruct(kGetLayer, w, out, sizeof(*out));
}

extern "C" int strata_voxel_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kVoxelCount, Writer());
}

extern "C" int strata_get_voxel(StrataSession* s, int index, StrataVoxelInfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    return CallStruct(kGetVoxel, w, out, sizeof(*out));
}

extern "C" int strata_get_random(StrataSession* s, char* engine, int engineCap,
                                 long* seed1, long* seed2, int* randomize) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;

    Writer w;
    w.I32(engineCap);
    std::vector<unsigned char> reply;
    if (!Call(kGetRandom, w, reply)) return STRATA_ERR_STATE;

    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    const std::string name = in.Str();
    const long s1 = static_cast<long>(in.I64());
    const long s2 = static_cast<long>(in.I64());
    const int rnd = in.I32();
    if (engine != nullptr && engineCap > 0) {
        const std::size_t n = std::min(static_cast<std::size_t>(engineCap - 1),
                                       name.size());
        std::memcpy(engine, name.data(), n);
        engine[n] = '\0';
    }
    if (seed1 != nullptr) *seed1 = s1;
    if (seed2 != nullptr) *seed2 = s2;
    if (randomize != nullptr) *randomize = rnd;
    return rc;
}

extern "C" int strata_world_size(StrataSession* s, double* sizeX, double* sizeYZ) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;

    std::vector<unsigned char> reply;
    if (!Call(kWorldSize, Writer(), reply)) return STRATA_ERR_STATE;

    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    const double x = in.F64();
    const double yz = in.F64();
    if (sizeX != nullptr) *sizeX = x;
    if (sizeYZ != nullptr) *sizeYZ = yz;
    return rc;
}

extern "C" int strata_get_world_material(StrataSession* s, char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(bufLen);
    return CallName(kGetWorldMaterial, w, buf, bufLen);
}

extern "C" double strata_get_temperature(StrataSession* s) {
    if (!Valid(s)) return 0.;
    return CallDouble(kGetTemperature);
}

//==============================================================================

extern "C" int strata_material_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kMaterialCount, Writer());
}

extern "C" int strata_get_material_name(StrataSession* s, int index,
                                        char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    w.I32(bufLen);
    return CallName(kGetMaterialName, w, buf, bufLen);
}

extern "C" int strata_get_material_info(StrataSession* s, int index,
                                        StrataMaterialInfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    return CallStruct(kGetMaterialInfo, w, out, sizeof(*out));
}

extern "C" int strata_damage_defaults(const char* material, double* ed, double* b, double* c) {
    if (material == nullptr) return 0;
    Writer w;
    w.Str(material);
    std::vector<unsigned char> reply;
    if (!Call(kDamageDefaults, w, reply)) return 0;
    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    const double ved = in.F64(), vb = in.F64(), vc = in.F64();
    if (rc != 1) return rc;
    if (ed != nullptr) *ed = ved;
    if (b != nullptr) *b = vb;
    if (c != nullptr) *c = vc;
    return 1;
}

extern "C" int strata_get_material_composition(StrataSession* s, const char* name,
                                               StrataElementFractionC* out,
                                               int maxOut) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    if (name == nullptr) return STRATA_ERR_HANDLE;

    Writer w;
    w.Str(name);
    w.I32(out != nullptr ? maxOut : 0);
    std::vector<unsigned char> reply;
    if (!Call(kGetMaterialComposition, w, reply)) return STRATA_ERR_STATE;

    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    if (rc > 0 && out != nullptr)
        in.Raw(out, sizeof(*out)*static_cast<std::size_t>(rc));
    return rc;
}

extern "C" int strata_defined_material_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kDefinedMaterialCount, Writer());
}

extern "C" int strata_get_defined_material_name(StrataSession* s, int index,
                                                char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    w.I32(bufLen);
    return CallName(kGetDefinedMaterialName, w, buf, bufLen);
}

extern "C" int strata_element_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kElementCount, Writer());
}

extern "C" int strata_get_element_name(StrataSession* s, int index,
                                       char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    w.I32(bufLen);
    return CallName(kGetElementName, w, buf, bufLen);
}

extern "C" int strata_physics_count(void) {
    return CallInt(kPhysicsCount, Writer());
}

extern "C" int strata_get_physics_name(int index, char* buf, int bufLen) {
    Writer w;
    w.I32(index);
    w.I32(bufLen);
    return CallName(kGetPhysicsName, w, buf, bufLen);
}

extern "C" int strata_physics_is_optional(int index) {
    Writer w;
    w.I32(index);
    return CallInt(kPhysicsIsOptional, w);
}

extern "C" int strata_particle_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kParticleCount, Writer());
}

extern "C" int strata_get_particle_name(StrataSession* s, int index,
                                        char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(index);
    w.I32(bufLen);
    return CallName(kGetParticleName, w, buf, bufLen);
}

//==============================================================================

extern "C" int strata_get_command_tree(StrataSession* s, char* buf, int bufLen) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(bufLen);
    return CallName(kGetCommandTree, w, buf, bufLen);
}

//==============================================================================

extern "C" int strata_h1_count(StrataSession* s) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    return CallInt(kH1Count, Writer());
}

extern "C" int strata_get_h1_info(StrataSession* s, int id, StrataH1InfoC* out) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;
    Writer w;
    w.I32(id);
    return CallStruct(kGetH1Info, w, out, sizeof(*out));
}

namespace {

// The three columns of a spectrum, however they were asked for
int ReadBins(Reader& in, int rc, double* centres, double* heights,
             double* errors, int maxBins) {
    if (rc <= 0) return rc;
    const int n = std::min(rc, maxBins);
    const std::size_t bytes = sizeof(double)*static_cast<std::size_t>(rc);
    std::vector<double> c(static_cast<std::size_t>(rc));
    std::vector<double> h(static_cast<std::size_t>(rc));
    std::vector<double> e(static_cast<std::size_t>(rc));
    in.Raw(c.data(), bytes);
    in.Raw(h.data(), bytes);
    in.Raw(e.data(), bytes);
    const std::size_t take = sizeof(double)*static_cast<std::size_t>(n);
    if (centres != nullptr) std::memcpy(centres, c.data(), take);
    if (heights != nullptr) std::memcpy(heights, h.data(), take);
    if (errors != nullptr) std::memcpy(errors, e.data(), take);
    return n;
}

}  // namespace

extern "C" int strata_get_h1_data(StrataSession* s, int id, double* centres,
                                  double* heights, double* errors, int maxBins) {
    if (!Valid(s)) return STRATA_ERR_HANDLE;

    Writer w;
    w.I32(id);
    w.I32(maxBins);
    std::vector<unsigned char> reply;
    if (!Call(kGetH1Data, w, reply)) return STRATA_ERR_STATE;

    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    return ReadBins(in, rc, centres, heights, errors, maxBins);
}

extern "C" int strata_get_h1_live(StrataSession* s, int id, double* centres,
                                  double* heights, double* errors, int maxBins,
                                  double* entries) {
    if (entries != nullptr) *entries = 0.;
    if (!Valid(s)) return STRATA_ERR_HANDLE;

    Writer w;
    w.I32(id);
    w.I32(maxBins);
    std::vector<unsigned char> reply;
    if (!Call(kGetH1Live, w, reply)) return STRATA_ERR_STATE;

    Reader in(reply.data(), reply.size());
    const int rc = in.I32();
    const double n = in.F64();
    if (entries != nullptr) *entries = n;
    return ReadBins(in, rc, centres, heights, errors, maxBins);
}

//==============================================================================

extern "C" const char* strata_last_error(StrataSession* s) {
    static std::string value;
    if (gChild == kNoProcess) {
        value = gError;
        return value.c_str();
    }
    std::vector<unsigned char> reply;
    if (!Call(kLastError, Writer(), reply)) {
        value = gError;
        return value.c_str();
    }
    Reader in(reply.data(), reply.size());
    value = in.Str();
    return value.c_str();
}

extern "C" void strata_exit_process(int code) {
    if (gChild != kNoProcess) {
        Writer w;
        w.I32(code);
        WriteFrame(gToChild, kExitProcess, w.Bytes());
        Reap();
    }
}
