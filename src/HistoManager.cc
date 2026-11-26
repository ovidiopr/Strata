//
// ********************************************************************
// * License and Disclaimer                                           *
// *                                                                  *
// * The  Geant4 software  is  copyright of the Copyright Holders  of *
// * the Geant4 Collaboration.  It is provided  under  the terms  and *
// * conditions of the Geant4 Software License,  included in the file *
// * LICENSE and available at  http://cern.ch/geant4/license .  These *
// * include a list of copyright holders.                             *
// *                                                                  *
// * Neither the authors of this software system, nor their employing *
// * institutes,nor the agencies providing financial support for this *
// * work  make  any representation or  warranty, express or implied, *
// * regarding  this  software system or assume any liability for its *
// * use.  Please see the license in the file  LICENSE  and URL above *
// * for the full disclaimer and the limitation of liability.         *
// *                                                                  *
// * This  code  implementation is the result of  the  scientific and *
// * technical work of the GEANT4 collaboration.                      *
// * By using,  copying,  modifying or  distributing the software (or *
// * any work based  on the software)  you  agree  to acknowledge its *
// * use  in  resulting  scientific  publications,  and indicate your *
// * acceptance of all terms of the Geant4 Software license.          *
// ********************************************************************
//
/// \file Strata/src/HistoManager.cc
/// \brief Implementation of the HistoManager class
//
//
// 
//==============================================================================
//==============================================================================

#include "HistoManager.hh"

#include "G4UnitsTable.hh"

#include <cmath>
#include <string>
#include "StrataResults.hh"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <vector>

#include <cstring>
#include "G4UnitsTable.hh"

//==============================================================================

HistoManager::HistoManager()
        : fFileName("strata") {
    Book();
}

//==============================================================================

HistoManager::~HistoManager() {
    // Geant4 11 migration: do NOT delete the analysis manager here
}

//==============================================================================

// What each axis measures, so that a front end does not have to guess it
// from the title or keep its own list of magic numbers
const char* const kTitle[] =
         // Primaries
        {"dummy",                                                          //0
         "Stopping power (electronic)",                                    //1
         "Stopping power (nuclear)",                                       //2
         "Projectile range",                                               //3
         // Displacement damage
         "Displacements per atom per unit fluence (NRT)",                   //4
         "Displacements per atom per unit fluence (arc-dpa)",               //5
         "Energy of primary knock-on atoms",                                //6
         "dummy", "dummy", "dummy",                                         //7-9
         // Secondaries
         "Energy deposited in the target: dN/dE",                           //10
         "Energy of charged secondaries at creation",                       //11
         "Energy of gamma secondaries at creation",                         //12
         "Energy of charged at creation: log10(Ekin)",                      //13
         "Energy of gammas at creation: log10(Ekin)",                       //14
         "X vertex of charged secondaries (all)",                           //15
         "X vertex of charged secondaries (not absorbed)",                  //16
         "Energy of neutron secondaries at creation",                       //17
         "Energy of neutrons at creation: log10(Ekin)",                     //18
         "dummy",                                                           //19
         // Transmitted (charged)
         "Kinetic energy at exit of target (transmitted, charged): dN/dE",  //20
         "Energy fluence (transmitted, charged): dE/dOmega",                //21
         "Space angle (transmitted, charged): dN/dOmega",                   //22
         "Projected angle at exit of target (transmitted, charged)",        //23
         "Projected position at exit of target (transmitted, charged)",     //24
         "Radius at exit of target (transmitted, charged)",                 //25
         "dummy", "dummy", "dummy", "dummy",                                //26-29
         // Transmitted (neutral)
         "Kinetic energy at exit of target (transmitted, neutral): dN/dE",  //30
         "Energy fluence (transmitted, neutral): dE/dOmega",                //31
         "Space angle (transmitted, neutral): dN/dOmega",                   //32
         "Projected angle at exit of target (transmitted, neutral)",        //33
         // Transmitted (neutron)
         "Kinetic energy at exit of target (transmitted, neutron): dN/dE",  //34
         "Energy fluence (transmitted, neutron): dE/dOmega",                //35
         "Space angle (transmitted, neutron): dN/dOmega",                   //36
         "Projected angle at exit of target (transmitted, neutron)",        //37
         "dummy", "dummy",                                                  //38-39
         // Reflected (charged)
         "Kinetic energy at exit of target (reflected, charged): dN/dE",    //40
         "Energy fluence (reflected, charged): dE/dOmega",                  //41
         "Space angle (reflected, charged): dN/dOmega",                     //42
         "Projected angle at exit of target (reflected, charged)",          //43
         "dummy", "dummy", "dummy", "dummy", "dummy", "dummy",              //44-49
         // Reflected (neutral)
         "Kinetic energy at exit of target (reflected, neutral): dN/dE",    //50
         "Energy fluence (reflected, neutral): dE/dOmega",                  //51
         "Space angle (reflected, neutral): dN/dOmega",                     //52
         "Projected angle at exit of target (reflected, neutral)",          //53
         // Reflected (neutron)
         "Kinetic energy at exit of target (reflected, neutron): dN/dE",    //54
         "Energy fluence (reflected, neutron): dE/dOmega",                  //55
         "Space angle (reflected, neutron): dN/dOmega",                     //56
         "Projected angle at exit of target (reflected, neutron)",          //57
         "dummy", "dummy",                                                  //58-59
         // Extras
         "Energy of Auger e- at creation",                                  //60
         "Energy of fluorescence gamma at creation",                        //61
         "Energy of Auger e- at creation (log scale)",                      //62
         "Energy of fluorescence gamma at creation (log scale)",            //63
         "Energy of PIXE Auger e- at creation",                             //64
         "Energy of PIXE gamma at creation",                                //65
         "Energy of PIXE Auger e- at creation (log scale)",                 //66
         "Energy of PIXE gamma at creation (log scale)",                    //67
         "Energy of DNA Auger e- at creation",                              //68
         "Energy of DNA gamma at creation",                                 //69
         "Energy of DNA Auger e- at creation (log scale)",                  //70
         "Energy of DNA gamma at creation (log scale)",                      //71
         "dummy", "dummy", "dummy", "dummy", "dummy", "dummy",              //72-77
         "dummy", "dummy",                                                  //78-79
         // Forced detection: what a detector at the chosen angle would
         // count, per incident ion
         "RBS spectrum"                                                     //80
        };

const StrataH1Axis kAxis[] = {
    kH1None,                                                            //0
    kH1Length, kH1Length, kH1Length,                                        //1-3
    kH1Length, kH1Length, kH1Energy, kH1None, kH1None, kH1None,                  //4-9
    kH1Energy,                                                          //10
    kH1Energy, kH1Energy,                                                 //11-12
    // 13 and 14 are 11 and 12 again with logarithmic bins: StackingAction
    // fills all four with the same energy, so the axis is an energy and
    // log10 is only how /analysis/h1/set was told to space the bins
    kH1Energy, kH1Energy,                                                 //13-14
    kH1Length, kH1Length,                                                 //15-16
    kH1Energy, kH1Energy, kH1None,                                          //17-19
    // Transmitted: the beam goes on through, so the angle is forward
    kH1Energy, kH1FwdAngle, kH1FwdAngle, kH1FwdAngle, kH1Length, kH1Length,       //20-25
    kH1None, kH1None, kH1None, kH1None,                                       //26-29
    kH1Energy, kH1FwdAngle, kH1FwdAngle, kH1FwdAngle,                         //30-33
    kH1Energy, kH1FwdAngle, kH1FwdAngle, kH1FwdAngle, kH1None, kH1None,          //34-39
    // Reflected: it comes back out, so the angle is backward
    kH1Energy, kH1BackAngle, kH1BackAngle, kH1BackAngle,                      //40-43
    kH1None, kH1None, kH1None, kH1None, kH1None, kH1None,                         //44-49
    kH1Energy, kH1BackAngle, kH1BackAngle, kH1BackAngle,                      //50-53
    kH1Energy, kH1BackAngle, kH1BackAngle, kH1BackAngle, kH1None, kH1None,       //54-59
    // Likewise here: the log-scale spectra are the linear ones rebinned
    kH1Energy, kH1Energy, kH1Energy, kH1Energy,                               //60-63
    kH1Energy, kH1Energy, kH1Energy, kH1Energy,                               //64-67
    kH1Energy, kH1Energy, kH1Energy, kH1Energy,                               //68-71
    kH1None, kH1None, kH1None, kH1None, kH1None, kH1None,                         //72-77
    kH1None, kH1None,                                                     //78-79
    kH1Energy                                                           //80
};

// What the y axis counts.  Geant4 keeps one axis annotation per dimension
// and an H1 has only one, so it cannot hold this and it is reported from
// here instead.
// %s stands for the unit of the x axis, which is what the per-width
// normalisation divides by; StrataH1YLabel fills it in
const char* const kYLabel[] = {
    "", "dE/dx (MeV/%s)", "dE/dx (MeV/%s)", "fraction of events",     //0-3
    "dpa per ion/cm2", "dpa per ion/cm2", "recoils/event", "", "", "", //4-9
    "dN/dE (1/%s)",                                                   //10
    "secondaries/event", "secondaries/event",                         //11-12
    "secondaries/event", "secondaries/event",                         //13-14
    "secondaries/event", "secondaries/event",                         //15-16
    "secondaries/event", "secondaries/event", "",                     //17-19
    "dN/dE (1/%s)", "dE/dOmega (MeV/sr/event)", "dN/dOmega (1/sr/event)",
    "projections/event", "tracks", "tracks",                          //20-25
    "", "", "", "",                                                   //26-29
    "dN/dE (1/%s)", "dE/dOmega (MeV/sr/event)", "dN/dOmega (1/sr/event)",
    "projections/event",                                              //30-33
    "dN/dE (1/%s)", "dE/dOmega (MeV/sr/event)", "dN/dOmega (1/sr/event)",
    "projections/event", "", "",                                      //34-39
    "dN/dE (1/%s)", "dE/dOmega (MeV/sr/event)", "dN/dOmega (1/sr/event)",
    "projections/event",                                              //40-43
    "", "", "", "", "", "",                                           //44-49
    "dN/dE (1/%s)", "dE/dOmega (MeV/sr/event)", "dN/dOmega (1/sr/event)",
    "projections/event",                                              //50-53
    "dN/dE (1/%s)", "dE/dOmega (MeV/sr/event)", "dN/dOmega (1/sr/event)",
    "projections/event", "", "",                                      //54-59
    "electrons/event", "photons/event", "electrons/event", "photons/event",
    "electrons/event", "photons/event", "electrons/event", "photons/event",
    "electrons/event", "photons/event", "electrons/event", "photons/event",
    "", "", "", "", "", "",                                           //72-77
    "", "",                                                           //78-79
    "counts/ion"                                                        //80
};

static_assert(sizeof(kTitle)/sizeof(kTitle[0]) == kStrataH1Count,
              "one title per histogram");
static_assert(sizeof(kAxis)/sizeof(kAxis[0]) == kStrataH1Count,
              "one axis description per histogram");
// What Run::EndOfRunAction divides each one by.  Only these six are touched;
// everything else keeps its counts.
const StrataH1Norm kNorm[] = {
    kH1Raw,                                                             //0
    kH1PerEventPerWidth, kH1PerEventPerWidth, kH1PerEvent,                  //1-3
    kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1Raw, kH1Raw, kH1Raw,                //4-9
    kH1PerEventPerWidth,                                                //10
    // Secondaries at creation: the labels have always said per event
    kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent,       //11-16
    kH1PerEvent, kH1PerEvent, kH1Raw,                                       //17-19
    // The four exit families are the same quantities for different
    // particles, so they are normalised alike.  dOmega is already divided
    // out when the track is counted, in TrackingAction
    kH1PerEventPerWidth, kH1PerEvent, kH1PerEvent, kH1PerEvent,                 //20-23
    kH1Raw, kH1Raw, kH1Raw, kH1Raw, kH1Raw, kH1Raw,                               //24-29
    kH1PerEventPerWidth, kH1PerEvent, kH1PerEvent, kH1PerEvent,                 //30-33
    kH1PerEventPerWidth, kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1Raw, kH1Raw,     //34-39
    kH1PerEventPerWidth, kH1PerEvent, kH1PerEvent, kH1PerEvent,                 //40-43
    kH1Raw, kH1Raw, kH1Raw, kH1Raw, kH1Raw, kH1Raw,                               //44-49
    kH1PerEventPerWidth, kH1PerEvent, kH1PerEvent, kH1PerEvent,                 //50-53
    kH1PerEventPerWidth, kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1Raw, kH1Raw,     //54-59
    // De-excitation, PIXE and DNA spectra, likewise labelled per event
    kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent,                //60-64
    kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent, kH1PerEvent,                //65-69
    kH1PerEvent, kH1PerEvent,                                               //70-71
    // The forced-detection yield is already per incident ion once the
    // events are divided out
    kH1Raw, kH1Raw, kH1Raw, kH1Raw, kH1Raw, kH1Raw,                               //72-77
    kH1Raw, kH1Raw,                                                         //78-79
    kH1PerEvent                                                         //80
};

static_assert(sizeof(kNorm)/sizeof(kNorm[0]) == kStrataH1Count,
              "one normalisation per histogram");

static_assert(sizeof(kYLabel)/sizeof(kYLabel[0]) == kStrataH1Count,
              "one y-axis label per histogram");

// Geant4 does not give a title back until the histogram has been activated
const char* StrataH1TitleOf(G4int id) {
    if (id < 0 || id >= kStrataH1Count) return "";
    return kTitle[id];
}

G4bool StrataH1IsReal(G4int id) {
    return std::strcmp(StrataH1TitleOf(id), "dummy") != 0;
}

StrataH1Axis StrataH1AxisOf(G4int id) {
    if (id < 0 || id >= kStrataH1Count) return kH1None;
    return kAxis[id];
}

const char* StrataH1YLabelOf(G4int id) {
    if (id < 0 || id >= kStrataH1Count) return "";
    return kYLabel[id];
}

StrataH1Norm StrataH1NormOf(G4int id) {
    if (id < 0 || id >= kStrataH1Count) return kH1Raw;
    return kNorm[id];
}

// Geant4 reports a bin width in the unit the histogram was declared with,
// not in its internal units
G4String StrataH1XUnitSymbol(G4int id) {
    G4String category;
    switch (StrataH1AxisOf(id)) {
        case kH1Length:    category = "Length"; break;
        case kH1Energy:    category = "Energy"; break;
        case kH1FwdAngle:
        case kH1BackAngle: category = "Angle";  break;
        default:           return "";
    }

    auto* am = G4AnalysisManager::Instance();
    if (id < 0 || id >= static_cast<G4int>(am->GetNofH1s())) return "";
    // A histogram booked without a unit reports 1, which is Geant4's own
    const G4double value = am->GetH1Unit(id);
    if (value <= 0.) return "";

    for (G4UnitsCategory* cat : G4UnitDefinition::GetUnitsTable()) {
        if (cat->GetName() != category) continue;
        for (const G4UnitDefinition* unit : cat->GetUnitsList())
            if (std::fabs(unit->GetValue() - value) <= 1e-12*std::fabs(value))
                return unit->GetSymbol();
    }
    return "";
}

G4bool StrataH1IsLogX(G4int id) {
    auto* am = G4AnalysisManager::Instance();
    if (id < 0 || id >= static_cast<G4int>(am->GetNofH1s())) return false;
    // Geant4 writes "<axis title> <fcn>( <unit>)", so with no axis title of
    // its own the annotation reads " log10( [keV])", leading space and all
    return am->GetH1XAxisTitle(id).find("log10(") != std::string::npos;
}

G4String StrataH1YLabel(G4int id) {
    G4String label = StrataH1YLabelOf(id);
    const std::size_t at = label.find("%s");
    if (at == std::string::npos) return label;

    G4String unit = StrataH1XUnitSymbol(id);
    // Nothing sensible to say about a histogram that has not been booked
    if (unit.empty()) unit = "bin";
    label.replace(at, 2, unit);
    return label;
}

void HistoManager::Book() {
    // Create or get analysis manager
    // The choice of analysis technology is done via selection of a namespace
    // in HistoManager.hh
    G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();
    analysisManager->SetDefaultFileType("root");
    analysisManager->SetFileName(fFileName);
    analysisManager->SetVerboseLevel(1);
    analysisManager->SetActivation(true);    // Enable inactivation of histograms

    // Define histograms start values
    const G4int kMaxHisto = kStrataH1Count;
    const G4String id[] = {"0",  "1",  "2",  "3",  "4",  "5",  "6",  "7",  "8",  "9",
                           "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
                           "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
                           "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
                           "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
                           "50", "51", "52", "53", "54", "55", "56", "57", "58", "59",
                           "60", "61", "62", "63", "64", "65", "66", "67", "68", "69",
                           "70", "71", "72", "73", "74", "75", "76", "77", "78", "79",
                           "80"};


    // Default values (to be reset via /analysis/h1/set command)
    G4int nbins = 100;
    G4double vmin = 0.;
    G4double vmax = 100.;

    // Create all histograms as inactivated, as we have not yet set nbins, vmin, vmax
    for (G4int k = 0; k < kMaxHisto; k++) {
        G4int ih = analysisManager->CreateH1("h" + id[k], kTitle[k], nbins, vmin, vmax);
        analysisManager->SetH1Activation(ih, false);
    }
}

//==============================================================================
// Live spectra
//
// Each thread copies what it has into StrataResultStore between events, so a
// front end can draw a spectrum while the run is still going
//==============================================================================

namespace {

/// How often one thread publishes
constexpr long kLivePublishMs = 250;

/// Slots are handed out on first publication rather than taken from
/// G4Threading, so the numbering holds whatever run manager is in use
std::atomic<int> gNextSlot{0};

}  // namespace

void StrataPublishLiveH1(G4bool aForce) {
    static thread_local int tSlot = -1;
    static thread_local long tEvents = 0;
    static thread_local std::chrono::steady_clock::time_point tLast{};
    static thread_local StrataLiveH1 tCopy;

    // Called once per event while the run goes on, and once more when it
    // ends, which is also where the count for the next run is cleared
    if (!aForce) ++tEvents;

    const auto now = std::chrono::steady_clock::now();
    if (!aForce && tSlot >= 0
        && now - tLast < std::chrono::milliseconds(kLivePublishMs)) return;
    tLast = now;
    if (tSlot < 0) tSlot = gNextSlot.fetch_add(1);

    auto* analysisManager = G4AnalysisManager::Instance();
    const G4int n = std::min(kStrataH1Count,
                             static_cast<G4int>(analysisManager->GetNofH1s()));
    for (G4int id = 0; id < n; ++id) {
        // A histogram that was never switched on has no object behind it
        auto* h = analysisManager->GetH1(id, false);
        if (h == nullptr) continue;

        const std::size_t bins = h->axis().bins();
        tCopy.centres.resize(bins);
        tCopy.heights.resize(bins);
        tCopy.errors.resize(bins);
        for (std::size_t i = 0; i < bins; ++i) {
            // As stored, the same as strata_get_h1_data()
            tCopy.centres[i] = h->axis().bin_center(static_cast<G4int>(i));
            tCopy.heights[i] = h->bin_height(static_cast<G4int>(i));
            tCopy.errors[i] = h->bin_error(static_cast<G4int>(i));
        }
        tCopy.entries = static_cast<double>(h->all_entries());
        tCopy.width = analysisManager->GetH1Width(id);
        tCopy.events = tEvents;
        tCopy.norm = static_cast<int>(StrataH1NormOf(id));
        StrataResultStore::Instance().PublishH1(tSlot, id, tCopy);
    }

    if (aForce) tEvents = 0;
}
