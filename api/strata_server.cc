//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/api/strata_server.cc
// \brief The engine process: one request in, one response out.
//
// The descriptors to use are named by STRATA_FD_IN and STRATA_FD_OUT.  The
// protocol cannot share stdout or stderr: Geant4 and the libraries under it
// write there whenever they please.
//
// strata_beam_on returns as soon as the run is going, so a single loop
// serves the polling calls that follow it without needing a thread.

#include "strata_api.h"
#include "strata_protocol.hh"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

namespace {

using namespace strata;

Pipe EndFrom(const char* name) {
    return PipeFromText(std::getenv(name));
}

StrataSession* gSession = nullptr;

// A buffer for the calls that write a name into one
std::string TakeString(int cap, const std::vector<char>& buf) {
    if (cap <= 0) return std::string();
    const char* p = buf.data();
    return std::string(p, ::strnlen(p, static_cast<std::size_t>(cap)));
}

void Dispatch(std::uint32_t op, Reader& in, Writer& out) {
    switch (op) {
    case kStructSize:     out.I32(strata_struct_size(in.I32())); break;
    case kVersion:        out.Str(strata_version()); break;
    case kGeant4Version:  out.Str(strata_geant4_version()); break;
    case kDatasetCount:   out.I32(strata_dataset_count()); break;

    case kGetDataset: {
        const int index = in.I32();
        const bool want = in.I32() != 0;
        StrataDatasetC d{};
        const int rc = strata_get_dataset(index, want ? &d : nullptr);
        out.I32(rc);
        if (want) out.Raw(&d, sizeof(d));
        break;
    }

    case kSetDataDir: {
        const std::string dir = in.Str();
        out.I32(strata_set_data_dir(dir.empty() ? "" : dir.c_str()));
        break;
    }

    case kCreate: {
        gSession = strata_create(in.I32());
        out.I32(gSession != nullptr ? 1 : 0);
        break;
    }

    case kDestroy:
        strata_destroy(gSession);
        gSession = nullptr;
        break;

    case kInitialize:      out.I32(strata_initialize(gSession)); break;
    case kThreadCount:     out.I32(strata_thread_count(gSession)); break;

    case kApply: {
        const std::string cmd = in.Str();
        out.I32(strata_apply(gSession, cmd.c_str()));
        break;
    }

    case kExecuteMacro: {
        const std::string path = in.Str();
        out.I32(strata_execute_macro(gSession, path.c_str()));
        break;
    }

    case kInitializeStart: out.I32(strata_initialize_start(gSession)); break;

    case kApplyStart: {
        const std::string cmd = in.Str();
        out.I32(strata_apply_start(gSession, cmd.c_str()));
        break;
    }

    case kBusy:            out.I32(strata_busy(gSession)); break;
    case kCommandStatus:   out.I32(strata_command_status(gSession)); break;
    case kCommandWait:     out.I32(strata_command_wait(gSession, in.I32())); break;
    case kBeamOn:          out.I32(strata_beam_on(gSession, in.I64())); break;
    case kAbort:           out.I32(strata_abort(gSession)); break;
    case kWait:            out.I32(strata_wait(gSession, in.I32())); break;
    case kState:           out.I32(strata_state(gSession)); break;
    case kEventsDone:      out.I64(strata_events_done(gSession)); break;
    case kEventsRequested: out.I64(strata_events_requested(gSession)); break;
    case kProgress:        out.F64(strata_progress(gSession)); break;
    case kRunStatus:       out.I32(strata_run_status(gSession)); break;

    case kLogPop: {
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        int isError = 0;
        const int rc = strata_log_pop(gSession, buf.data(), cap, &isError);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        out.I32(isError);
        break;
    }

    case kLogPending:      out.I32(strata_log_pending(gSession)); break;
    case kLogClear:        strata_log_clear(gSession); break;
    case kLogDropped:      out.I64(strata_log_dropped(gSession)); break;

    case kGetStats: {
        const bool want = in.I32() != 0;
        StrataRunStatsC st{};
        const int rc = strata_get_stats(gSession, want ? &st : nullptr);
        out.I32(rc);
        if (want) out.Raw(&st, sizeof(st));
        break;
    }

    case kVoxelResultCount: out.I32(strata_voxel_result_count(gSession)); break;

    case kGetVoxelResult: {
        const int index = in.I32();
        const bool want = in.I32() != 0;
        StrataVoxelResultC v{};
        const int rc = strata_get_voxel_result(gSession, index, want ? &v : nullptr);
        out.I32(rc);
        if (want) out.Raw(&v, sizeof(v));
        break;
    }

    case kLayerCount:      out.I32(strata_layer_count(gSession)); break;

    case kGetLayer: {
        const int index = in.I32();
        const bool want = in.I32() != 0;
        StrataLayerInfoC l{};
        const int rc = strata_get_layer(gSession, index, want ? &l : nullptr);
        out.I32(rc);
        if (want) out.Raw(&l, sizeof(l));
        break;
    }

    case kVoxelCount:      out.I32(strata_voxel_count(gSession)); break;

    case kGetVoxel: {
        const int index = in.I32();
        const bool want = in.I32() != 0;
        StrataVoxelInfoC v{};
        const int rc = strata_get_voxel(gSession, index, want ? &v : nullptr);
        out.I32(rc);
        if (want) out.Raw(&v, sizeof(v));
        break;
    }

    case kGetRandom: {
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        long s1 = 0, s2 = 0;
        int randomize = 0;
        const int rc = strata_get_random(gSession, buf.data(), cap,
                                         &s1, &s2, &randomize);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        out.I64(s1);
        out.I64(s2);
        out.I32(randomize);
        break;
    }

    case kWorldSize: {
        double x = 0., yz = 0.;
        const int rc = strata_world_size(gSession, &x, &yz);
        out.I32(rc);
        out.F64(x);
        out.F64(yz);
        break;
    }

    case kGetWorldMaterial: {
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_world_material(gSession, buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kGetTemperature:  out.F64(strata_get_temperature(gSession)); break;
    case kMaterialCount:   out.I32(strata_material_count(gSession)); break;

    case kGetMaterialName: {
        const int index = in.I32();
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_material_name(gSession, index, buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kGetMaterialInfo: {
        const int index = in.I32();
        const bool want = in.I32() != 0;
        StrataMaterialInfoC m{};
        const int rc = strata_get_material_info(gSession, index, want ? &m : nullptr);
        out.I32(rc);
        if (want) out.Raw(&m, sizeof(m));
        break;
    }

    case kDamageDefaults: {
        const std::string name = in.Str();
        double ed = 0., b = 0., c = 0.;
        out.I32(strata_damage_defaults(name.c_str(), &ed, &b, &c));
        out.F64(ed);
        out.F64(b);
        out.F64(c);
        break;
    }

    case kGetMaterialComposition: {
        const std::string name = in.Str();
        const int maxOut = in.I32();
        std::vector<StrataElementFractionC> els(maxOut > 0 ? maxOut : 1);
        const int rc = strata_get_material_composition(
                gSession, name.c_str(), maxOut > 0 ? els.data() : nullptr, maxOut);
        out.I32(rc);
        if (rc > 0) out.Raw(els.data(), sizeof(els[0])*static_cast<std::size_t>(rc));
        break;
    }

    case kDefinedMaterialCount:
        out.I32(strata_defined_material_count(gSession));
        break;

    case kGetDefinedMaterialName: {
        const int index = in.I32();
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_defined_material_name(gSession, index,
                                                        buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kElementCount:    out.I32(strata_element_count(gSession)); break;

    case kGetElementName: {
        const int index = in.I32();
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_element_name(gSession, index, buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kPhysicsCount:    out.I32(strata_physics_count()); break;

    case kGetPhysicsName: {
        const int index = in.I32();
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_physics_name(index, buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kPhysicsIsOptional: out.I32(strata_physics_is_optional(in.I32())); break;
    case kParticleCount:     out.I32(strata_particle_count(gSession)); break;

    case kGetParticleName: {
        const int index = in.I32();
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_particle_name(gSession, index, buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kGetCommandTree: {
        const int cap = in.I32();
        std::vector<char> buf(cap > 0 ? cap : 1, '\0');
        const int rc = strata_get_command_tree(gSession, buf.data(), cap);
        out.I32(rc);
        out.Str(TakeString(cap, buf).c_str());
        break;
    }

    case kH1Count:         out.I32(strata_h1_count(gSession)); break;

    case kGetH1Info: {
        const int id = in.I32();
        const bool want = in.I32() != 0;
        StrataH1InfoC h{};
        const int rc = strata_get_h1_info(gSession, id, want ? &h : nullptr);
        out.I32(rc);
        if (want) out.Raw(&h, sizeof(h));
        break;
    }

    case kGetH1Data: {
        const int id = in.I32();
        const int maxBins = in.I32();
        const std::size_t cap = maxBins > 0 ? static_cast<std::size_t>(maxBins) : 1;
        std::vector<double> c(cap), h(cap), e(cap);
        const int rc = strata_get_h1_data(gSession, id, c.data(), h.data(),
                                          e.data(), maxBins);
        out.I32(rc);
        if (rc > 0) {
            const std::size_t n = sizeof(double)*static_cast<std::size_t>(rc);
            out.Raw(c.data(), n);
            out.Raw(h.data(), n);
            out.Raw(e.data(), n);
        }
        break;
    }

    case kGetH1Live: {
        const int id = in.I32();
        const int maxBins = in.I32();
        const std::size_t cap = maxBins > 0 ? static_cast<std::size_t>(maxBins) : 1;
        std::vector<double> c(cap), h(cap), e(cap);
        double entries = 0.;
        const int rc = strata_get_h1_live(gSession, id, c.data(), h.data(),
                                          e.data(), maxBins, &entries);
        out.I32(rc);
        out.F64(entries);
        if (rc > 0) {
            const std::size_t n = sizeof(double)*static_cast<std::size_t>(rc);
            out.Raw(c.data(), n);
            out.Raw(h.data(), n);
            out.Raw(e.data(), n);
        }
        break;
    }

    case kLastError:       out.Str(strata_last_error(gSession)); break;

    case kExitProcess:
        // Nothing is written back: the caller is told by the pipe closing
        strata_exit_process(in.I32());
        break;

    default:
        out.I32(STRATA_ERR_RANGE);
        break;
    }
}

}  // namespace

//==============================================================================

int main() {
    const Pipe gIn = EndFrom("STRATA_FD_IN");
    const Pipe gOut = EndFrom("STRATA_FD_OUT");
    if (gIn == kNoPipe || gOut == kNoPipe) return 1;

    std::uint32_t op = 0;
    std::vector<unsigned char> request;

    while (ReadFrame(gIn, op, request)) {
        Reader in(request.data(), request.size());
        Writer out;
        Dispatch(op, in, out);
        if (!WriteFrame(gOut, op, out.Bytes())) break;
    }

    // The front end has gone; take Geant4 down the way the library does
    strata_exit_process(0);
    return 0;
}
