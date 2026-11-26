//==============================================================================
/// \file Strata/src/StrataResults.cc
/// \brief Implementation of the StrataResultStore class
//==============================================================================

#include "StrataResults.hh"
#include "HistoManager.hh"

#include <algorithm>
#include <cmath>
#include <cstring>

//==============================================================================

StrataResultStore& StrataResultStore::Instance() {
    static StrataResultStore theStore;
    return theStore;
}

//==============================================================================

void StrataResultStore::Publish(const StrataRunStats& stats,
                                const std::vector<StrataVoxelResult>& voxels) {
    std::lock_guard<std::mutex> lock(fMutex);
    fStats = stats;
    fStats.valid = 1;
    fVoxels = voxels;
}

//==============================================================================

bool StrataResultStore::Get(StrataRunStats& stats,
                            std::vector<StrataVoxelResult>& voxels) const {
    std::lock_guard<std::mutex> lock(fMutex);
    if (!fStats.valid) return false;
    stats = fStats;
    voxels = fVoxels;
    return true;
}

//==============================================================================

void StrataResultStore::Clear() {
    std::lock_guard<std::mutex> lock(fMutex);
    std::memset(&fStats, 0, sizeof(fStats));
    fVoxels.clear();
}

//==============================================================================

void StrataResultStore::BeginRun(long nEventsRequested) {
    fAbort.store(false, std::memory_order_relaxed);
    fDone.store(0, std::memory_order_relaxed);
    fRequested.store(nEventsRequested, std::memory_order_relaxed);

    // Last run's copies say nothing about this one
    std::lock_guard<std::mutex> guard(fLiveMutex);
    fLive.clear();
}

//==============================================================================

void StrataResultStore::PublishH1(int slot, int id, const StrataLiveH1& copy) {
    if (slot < 0 || id < 0) return;

    std::lock_guard<std::mutex> guard(fLiveMutex);
    std::vector<StrataLiveH1>& slots = fLive[id];
    if (static_cast<int>(slots.size()) <= slot) slots.resize(slot + 1);
    slots[slot] = copy;
}

int StrataResultStore::ReadH1(int id, double* centres, double* heights,
                              double* errors, int maxBins,
                              double* entries) const {
    if (centres == nullptr || heights == nullptr || maxBins <= 0) return 0;
    if (entries != nullptr) *entries = 0.0;

    std::lock_guard<std::mutex> guard(fLiveMutex);
    const auto found = fLive.find(id);
    if (found == fLive.end()) return 0;

    int nbins = 0;
    long events = 0;
    double width = 0;
    int norm = 0;
    for (const StrataLiveH1& one : found->second) {
        if (one.heights.empty()) continue;

        const int n = std::min(static_cast<int>(one.heights.size()), maxBins);
        if (nbins == 0) {
            // The first thread with anything to say sets the binning; the
            // rest agree with it, filling the same histogram
            for (int i = 0; i < n; ++i) {
                centres[i] = one.centres[i];
                heights[i] = 0.0;
                if (errors != nullptr) errors[i] = 0.0;
            }
            nbins = n;
            width = one.width;
            norm = one.norm;
        }
        for (int i = 0; i < std::min(n, nbins); ++i) {
            heights[i] += one.heights[i];
            // Independent sums, so the errors add in quadrature and the root
            // is taken once everything is in
            if (errors != nullptr && i < static_cast<int>(one.errors.size()))
                errors[i] += one.errors[i]*one.errors[i];
        }
        if (entries != nullptr) *entries += one.entries;
        events += one.events;
    }

    if (errors != nullptr)
        for (int i = 0; i < nbins; ++i) errors[i] = std::sqrt(errors[i]);

    // The division end of run does, over the events that are actually in the
    // sum above
    double scale = 1.0;
    if (events > 0) {
        if (norm == kH1PerEvent) scale = 1.0/static_cast<double>(events);
        else if (norm == kH1PerEventPerWidth && width > 0)
            scale = 1.0/(static_cast<double>(events)*width);
    }
    if (scale != 1.0)
        for (int i = 0; i < nbins; ++i) {
            heights[i] *= scale;
            if (errors != nullptr) errors[i] *= scale;
        }
    return nbins;
}

//==============================================================================
