//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/api/strata_protocol.cc
// \brief Implementation of the frame transport

#include "strata_protocol.hh"

namespace strata {

namespace {

// Enough for a histogram of any size the analysis manager will give us,
// and small enough that a confused length is not an allocation
constexpr std::uint32_t kMaxPayload = 64u*1024u*1024u;

}  // namespace

//==============================================================================

bool WriteFrame(Pipe p, std::uint32_t word,
                const std::vector<unsigned char>& payload) {
    const std::uint32_t n = static_cast<std::uint32_t>(payload.size());
    if (!PipeWriteAll(p, &n, sizeof(n))) return false;
    if (!PipeWriteAll(p, &word, sizeof(word))) return false;
    if (n == 0) return true;
    return PipeWriteAll(p, payload.data(), n);
}

//==============================================================================

bool ReadFrame(Pipe p, std::uint32_t& word,
               std::vector<unsigned char>& payload) {
    std::uint32_t n = 0;
    if (!PipeReadAll(p, &n, sizeof(n))) return false;
    if (!PipeReadAll(p, &word, sizeof(word))) return false;
    if (n > kMaxPayload) return false;
    payload.resize(n);
    if (n == 0) return true;
    return PipeReadAll(p, payload.data(), n);
}

}  // namespace strata
