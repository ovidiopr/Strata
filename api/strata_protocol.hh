//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/api/strata_protocol.hh
// \brief Frames of the request and response protocol to the engine process.
//
// One opcode per entry point of strata_api.h, in the order they are
// declared there.  Both ends are built from the same source in the same
// build, so structs cross as their own bytes.

#ifndef STRATA_PROTOCOL_HH
#define STRATA_PROTOCOL_HH

#include "strata_pipe.hh"

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace strata {

enum Op : std::uint32_t {
    kStructSize = 1,
    kVersion,
    kGeant4Version,
    kDatasetCount,
    kGetDataset,
    kSetDataDir,
    kCreate,
    kDestroy,
    kInitialize,
    kThreadCount,
    kApply,
    kExecuteMacro,
    kBeamOn,
    kAbort,
    kWait,
    kState,
    kEventsDone,
    kEventsRequested,
    kProgress,
    kRunStatus,
    kLogPop,
    kLogPending,
    kLogClear,
    kLogDropped,
    kGetStats,
    kVoxelResultCount,
    kGetVoxelResult,
    kLayerCount,
    kGetLayer,
    kVoxelCount,
    kGetVoxel,
    kGetRandom,
    kWorldSize,
    kGetWorldMaterial,
    kGetTemperature,
    kMaterialCount,
    kGetMaterialName,
    kGetMaterialInfo,
    kGetMaterialComposition,
    kDamageDefaults,
    kDefinedMaterialCount,
    kGetDefinedMaterialName,
    kElementCount,
    kGetElementName,
    kPhysicsCount,
    kGetPhysicsName,
    kPhysicsIsOptional,
    kParticleCount,
    kGetParticleName,
    kH1Count,
    kGetH1Info,
    kGetH1Data,
    kGetH1Live,
    kLastError,
    kExitProcess,
    kGetCommandTree,
    kInitializeStart,
    kApplyStart,
    kBusy,
    kCommandStatus,
    kCommandWait,
    kOpCount
};

//==============================================================================

// A payload being written
class Writer {
public:
    void I32(std::int32_t v) { Raw(&v, sizeof(v)); }
    void I64(std::int64_t v) { Raw(&v, sizeof(v)); }
    void F64(double v)       { Raw(&v, sizeof(v)); }

    void Str(const char* s) {
        const std::uint32_t n = (s == nullptr) ? 0u
                                : static_cast<std::uint32_t>(std::strlen(s));
        Raw(&n, sizeof(n));
        if (n > 0) Raw(s, n);
    }

    void Raw(const void* p, std::size_t n) {
        const auto* b = static_cast<const unsigned char*>(p);
        fBytes.insert(fBytes.end(), b, b + n);
    }

    const std::vector<unsigned char>& Bytes() const { return fBytes; }

private:
    std::vector<unsigned char> fBytes;
};

//==============================================================================

// A payload being read.  Running off the end yields zeros rather than
// throwing, so a truncated frame fails as a wrong answer and not a crash
class Reader {
public:
    Reader(const unsigned char* p, std::size_t n) : fAt(p), fLeft(n) {}

    std::int32_t I32() { std::int32_t v = 0; Raw(&v, sizeof(v)); return v; }
    std::int64_t I64() { std::int64_t v = 0; Raw(&v, sizeof(v)); return v; }
    double F64()       { double v = 0.;     Raw(&v, sizeof(v)); return v; }

    std::string Str() {
        std::uint32_t n = 0;
        Raw(&n, sizeof(n));
        if (n == 0 || n > fLeft) return std::string();
        std::string s(reinterpret_cast<const char*>(fAt), n);
        fAt += n;
        fLeft -= n;
        return s;
    }

    bool Raw(void* p, std::size_t n) {
        if (fLeft < n) { std::memset(p, 0, n); fLeft = 0; return false; }
        std::memcpy(p, fAt, n);
        fAt += n;
        fLeft -= n;
        return true;
    }

    std::size_t Left() const { return fLeft; }

private:
    const unsigned char* fAt;
    std::size_t fLeft;
};

//==============================================================================

// A frame is a length, a word, and the payload.  The word is the opcode on
// the way in and the call's own return value on the way out
bool WriteFrame(Pipe p, std::uint32_t word, const std::vector<unsigned char>& payload);
bool ReadFrame(Pipe p, std::uint32_t& word, std::vector<unsigned char>& payload);

}  // namespace strata

#endif  // STRATA_PROTOCOL_HH
