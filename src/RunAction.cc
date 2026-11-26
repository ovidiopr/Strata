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
/// \file Strata/src/RunAction.cc
/// \brief Implementation of the RunAction class
//
//
//==============================================================================
//==============================================================================

#include <cstdlib>
#include <cstdio>
#include <fstream>

#include "RunAction.hh"

#include "G4Threading.hh"

#include <algorithm>
#include <chrono>
#include <exception>
#include <filesystem>
#include <map>
#include <vector>
#include <sstream>
#include "RandomSetup.hh"
#include "RunActionMessenger.hh"

#include "DetectorConstruction.hh"
#include "PrimaryGeneratorAction.hh"
#include "HistoManager.hh"
#include "StrataResults.hh"
#include "Run.hh"

#include "G4Run.hh"
#include "G4Event.hh"
#include "G4EventManager.hh"
#include "G4UnitsTable.hh"
#include "G4EmCalculator.hh"
#include "G4VProcess.hh"

#include "Randomize.hh"
#include "G4SystemOfUnits.hh"
#include <iomanip>

//==============================================================================

namespace {

// File names are matched in the form the filesystem keeps them
using NativeString = std::filesystem::path::string_type;

NativeString NativeWithSuffix(const std::filesystem::path& p, const char* suffix) {
    NativeString s = p.native();
    for (; *suffix != '\0'; ++suffix)
        s.push_back(static_cast<NativeString::value_type>(*suffix));
    return s;
}

bool StartsWith(const NativeString& s, const NativeString& prefix) {
    return s.size() >= prefix.size() && s.compare(0, prefix.size(), prefix) == 0;
}

bool AllDigits(const NativeString& s) {
    return !s.empty() && std::all_of(s.begin(), s.end(), [](NativeString::value_type c) {
        return c >= '0' && c <= '9';
    });
}

}  // namespace

//==============================================================================


RunAction::RunAction(DetectorConstruction* det, PrimaryGeneratorAction* kin)
        : G4UserRunAction(), fDetector(det), fPrimary(kin),
          fRun(nullptr), fHistoManager(nullptr),
          fAnalysisOpen(false),
          fScratchFile(""),
          fWantedFile(""),
          fSavePrim(false),
          fSaveCasc(false),
          fPrimName("primaries.txt"),
          fCascName("cascades.txt") {

    // Book predefined histograms
    fHistoManager = new HistoManager();

    // Create messenger
    fRunMessenger = new RunActionMessenger(this);
}

//==============================================================================

G4bool RunAction::fgWriteHistograms = true;

//==============================================================================

RunAction::~RunAction() {
    delete fHistoManager;

    if (fPrimFile.is_open()) fPrimFile.close();
    if (fCascFile.is_open()) fCascFile.close();

    delete fRunMessenger;
}

//==============================================================================

G4Run* RunAction::GenerateRun() {
    fRun = new Run(fDetector);
    return fRun;
}

//==============================================================================

void RunAction::BeginOfRunAction(const G4Run* aRun) {
    // Pick the stream for this run before anything draws from it: with
    // automatic seeding on, this is where a run becomes a different run.
    // In multithreaded mode the master seeds the workers from here.
    RandomSetup::Instance()->PrepareRun();
    if (isMaster) G4Random::showEngineStatus();

    // Arm the progress counter.  Only the master knows how many events were
    // requested; workers must not reset it underneath each other.
    if (isMaster)
        StrataResultStore::Instance().BeginRun(aRun->GetNumberOfEventToBeProcessed());

    // Keep run condition
    if (fPrimary) {
        G4ParticleDefinition* particle
                = fPrimary->GetParticleGun()->GetParticleDefinition();
        G4double energy = fPrimary->GetParticleGun()->GetParticleEnergy();
        fRun->SetPrimary(particle, energy);
    }

    // Histograms.  The master keeps the merged contents of the previous run
    // in memory (see EndOfRunAction), so clear them before a new one starts.
    G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();
    fAnalysisOpen = false;
    if (analysisManager->IsActive()) {
        // Whether or not a file is wanted, the merged contents of the last
        // run have to go, or a second run would add to the first.
        if (isMaster) analysisManager->Reset();

        if (fgWriteHistograms) {
            fAnalysisOpen = analysisManager->OpenFile();
            if (!fAnalysisOpen) {
                G4ExceptionDescription ed;
                ed << "The analysis output file could not be created.\n"
                   << "The run will go ahead and the histograms will be "
                   << "filled in memory, but nothing will be written.\n"
                   << "Give /analysis/setFileName a path in a writable "
                   << "directory to keep the output.";
                G4Exception("RunAction::BeginOfRunAction", "Strata_FILE_0001",
                            JustWarning, ed);
            }
        }
        else if (G4Threading::IsMultithreadedApplication()) {
            // A front end wants the histograms in memory and no file
            fWantedFile = analysisManager->GetFileName();
            // The name only has to be unique among whatever else is running.
            // A %TEMP% the narrow code page cannot spell throws here; the
            // working directory will do instead
            std::string where;
            try {
                where = (std::filesystem::temp_directory_path() / "strata-merge-").string();
            } catch (const std::exception&) {
                where = "strata-merge-";
            }
            std::ostringstream name;
            name << where
                 << std::chrono::steady_clock::now().time_since_epoch().count()
                 << '-' << G4Threading::G4GetThreadId() << ".root";
            fScratchFile = name.str();
            analysisManager->SetFileName(fScratchFile);
            fAnalysisOpen = analysisManager->OpenFile();
        }
    }

    // Activate saving to file
    if (fSavePrim) OpenTrackFile(fPrimFile, fPrimName);
    if (fSaveCasc) OpenTrackFile(fCascFile, fCascName);
}

//==============================================================================

/// The part a given thread writes: "tracks.txt" becomes "tracks_t0.txt"
/// Empty when this thread writes the file itself, which is the sequential
/// case and the master
G4String RunAction::TrackPartName(const G4String& aName) {
    if (!G4Threading::IsMultithreadedApplication()) return "";
    const G4int tid = G4Threading::G4GetThreadId();
    if (tid < 0) return "";                   // the master writes no steps
    const std::filesystem::path p{std::string(aName)};
    std::ostringstream part;
    part << (p.parent_path() / p.stem()).string() << "_t" << tid
         << p.extension().string();
    return part.str();
}

void RunAction::OpenTrackFile(std::ofstream& aFile, const G4String& aName) {
    const G4String part = TrackPartName(aName);
    if (part.empty()) {
        // This is the file the user asked for, and it gets the one header
        aFile.open(aName, std::ios::out);
        aFile << "#ev. " << "stp. " << "id " << "parent " << "name "
              << "time " << "x " << "y " << "z " << "px "
              << "py " << "pz " << "Ek" << " proc\n";
        // A worker will append to it, so the master must not hold it open
        if (G4Threading::IsMultithreadedApplication()) aFile.close();
    } else {
        // A worker's own part, with no header of its own
        aFile.open(part, std::ios::out);
    }
}

/// Joins the per-thread parts onto the file the user asked for and
/// removes them
void RunAction::MergeTrackFile(const G4String& aName) {
    if (!G4Threading::IsMultithreadedApplication()) return;

    const std::filesystem::path whole{std::string(aName)};
    const NativeString stem = NativeWithSuffix(whole.stem(), "_t");
    const NativeString ext = whole.extension().native();
    std::error_code ec;
    std::filesystem::path dir = whole.parent_path();
    if (dir.empty()) dir = std::filesystem::current_path(ec);

    std::vector<std::filesystem::path> partPaths;
    for (const auto& entry : std::filesystem::directory_iterator(dir, ec)) {
        const NativeString n = entry.path().filename().native();
        if (n.size() < stem.size() + ext.size() || !StartsWith(n, stem)
            || entry.path().extension().native() != ext)
            continue;
        if (!AllDigits(n.substr(stem.size(), n.size() - stem.size() - ext.size())))
            continue;
        partPaths.push_back(entry.path());
    }
    if (partPaths.empty()) return;

    std::vector<std::ifstream> parts(partPaths.size());
    std::vector<std::string> head(partPaths.size());
    std::vector<long> headEvent(partPaths.size(), -1);

    // The first line of each part, and the event it belongs to
    auto advance = [&](std::size_t i) {
        headEvent[i] = -1;
        while (std::getline(parts[i], head[i])) {
            if (head[i].empty()) continue;
            headEvent[i] = std::strtol(head[i].c_str(), nullptr, 10);
            return;
        }
    };
    for (std::size_t i = 0; i < parts.size(); ++i) {
        parts[i].open(partPaths[i], std::ios::in);
        if (parts[i].is_open()) advance(i);
    }

    std::ofstream out(std::string(aName), std::ios::out | std::ios::app);
    if (out.is_open()) {
        for (;;) {
            std::size_t best = parts.size();
            for (std::size_t i = 0; i < parts.size(); ++i)
                if (headEvent[i] >= 0
                    && (best == parts.size() || headEvent[i] < headEvent[best]))
                    best = i;
            if (best == parts.size()) break;
            out << head[best] << '\n';
            advance(best);
        }
        out.close();
    }

    for (std::size_t i = 0; i < parts.size(); ++i) {
        if (parts[i].is_open()) parts[i].close();
        std::filesystem::remove(partPaths[i], ec);
    }
}

//==============================================================================

void RunAction::EndOfRunAction(const G4Run*) {
    // One last copy of this thread's spectra, with every event in it, before
    // anything else touches them
    if (!isMaster || !G4Threading::IsMultithreadedApplication())
        StrataPublishLiveH1(true);

    // Print Run summary and finish saving to file
    if (isMaster) fRun->EndOfRun();

    // Save histograms
    G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();
    if (analysisManager->IsActive() && fAnalysisOpen) {
        analysisManager->Write();
        // CloseFile() resets the histograms by default, which would leave
        // nothing for a front end to plot once the run is over
        analysisManager->CloseFile(!isMaster);
    }

    // The merge is done and the master is holding it; delete the file
    if (!fScratchFile.empty()) {
        std::error_code ec;
        const std::filesystem::path p{std::string(fScratchFile)};
        std::filesystem::remove(p, ec);
        const NativeString parts = NativeWithSuffix(p.stem(), "_t");
        try {
            for (const auto& entry :
                 std::filesystem::directory_iterator(p.parent_path(), ec)) {
                if (StartsWith(entry.path().filename().native(), parts))
                    std::filesystem::remove(entry.path(), ec);
            }
        } catch (const std::exception& e) {
            G4cerr << "Strata: scratch histogram files may be left in the "
                   << "temporary directory: " << e.what() << G4endl;
        }
        analysisManager->SetFileName(fWantedFile);
        fScratchFile.clear();
        fWantedFile.clear();
    }

    // Show Rndm status
    if (isMaster) G4Random::showEngineStatus();

    // Close primaries and cascades files
    if (fPrimFile.is_open()) fPrimFile.close();
    if (fCascFile.is_open()) fCascFile.close();

    // Then join the workers' parts onto the file the user asked for
    // A file that cannot be merged is a lost file, not a lost run: an
    // exception out of here leaves Geant4's master waiting for ever
    if (isMaster) {
        try {
            if (fSavePrim) MergeTrackFile(fPrimName);
            if (fSaveCasc) MergeTrackFile(fCascName);
        } catch (const std::exception& e) {
            G4cerr << "Strata: the track files could not be merged: " << e.what() << G4endl;
        }
    }
}

//==============================================================================

void RunAction::WriteToFiles(const G4Step* step) {
    const G4Track* track = step->GetTrack();
    if (!track) {
        G4cout << "No track - Exiting...\n";
        return;
    }
    const int nstep = track->GetCurrentStepNumber();
    const int id = track->GetTrackID();
    const int parentID = track->GetParentID();
    const G4String particleName = track->GetDynamicParticle()->GetParticleDefinition()->GetParticleName();
    const G4VProcess* process = track->GetCreatorProcess();
    G4String processName;
    if (process != nullptr) {
        processName = process->GetProcessName();
    } else processName = "Primary";

    // The event id Geant4 assigns, which is unique over the whole run
    const G4Event* event = G4EventManager::GetEventManager()->GetConstCurrentEvent();
    const int eventId = (event != nullptr) ? event->GetEventID() : -1;

    // get initial and final points in a step of the particle between two interactions
    const G4StepPoint* pnt1 = step->GetPreStepPoint();
    const G4StepPoint* pnt2 = step->GetPostStepPoint();

    // properties of particle at G4StepPoint pnt1 (only for step 1 to get first point of particle trajectory)
    if (nstep == 1) {
        if (id == 1) { // Primary
            if (fSavePrim) {
                fPrimFile << eventId << " " << nstep - 1 << " " << id << " "
                          << parentID << " " << particleName << " ";
            }
        } else { // Cascades
            if (fSaveCasc) {
                fCascFile << eventId << " " << nstep - 1 << " " << id << " "
                          << parentID << " " << particleName << " ";
            }
        }
        const G4ThreeVector& pos = pnt1->GetPosition();
        const G4double dt_global = pnt1->GetGlobalTime();
        const G4ThreeVector mom = pnt1->GetMomentum();
        const G4double ekin = pnt1->GetKineticEnergy();
        //const G4double ene = pnt1->GetTotalEnergy();

        if (id == 1) { // Primary
            if (fSavePrim) {
                fPrimFile << dt_global << " "
                          << pos[0] << " " << pos[1] << " " << pos[2] << " "
                          << mom[0] << " " << mom[1] << " " << mom[2] << " "
                          << ekin << " " << processName << "\n";
            }
        } else {   // Cascades
            if (fSaveCasc) {
                fCascFile << dt_global << " "
                          << pos[0] << " " << pos[1] << " " << pos[2] << " "
                          << mom[0] << " " << mom[1] << " " << mom[2] << " "
                          << ekin << " " << processName << "\n";
            }
        }
    }

    // properties of particle at G4StepPoint pnt2
    if (pnt2) {
        if (id == 1) { //ar primary
            if (fSavePrim) {
                fPrimFile << eventId << " " << nstep << " " << id << " "
                          << parentID << " " << particleName << " ";
            }
        } else { //ar cascades
            if (fSaveCasc) {
                fCascFile << eventId << " " << nstep << " " << id << " "
                          << parentID << " " << particleName << " ";
            }
        }
        const G4ThreeVector& pos = pnt2->GetPosition();
        const G4double dt_global = pnt2->GetGlobalTime();
        const G4ThreeVector mom = pnt2->GetMomentum();
        const G4double ekin = pnt2->GetKineticEnergy();
        //const G4double ene = pnt2->GetTotalEnergy();

        if (id == 1) { //ar primary
            if (fSavePrim) {
                fPrimFile << dt_global << " "
                          << pos[0] << " " << pos[1] << " " << pos[2] << " "
                          << mom[0] << " " << mom[1] << " " << mom[2] << " "
                          << ekin << " " << processName << "\n";
            }
        } else {   //ar cascades
            if (fSaveCasc) {
                fCascFile << dt_global << " "
                          << pos[0] << " " << pos[1] << " " << pos[2] << " "
                          << mom[0] << " " << mom[1] << " " << mom[2] << " "
                          << ekin << " " << processName << "\n";
            }
        }
    } else { //ar in case some error arises
        G4cout << "Error saving track info!!\n";
    }
}

//==============================================================================

void RunAction::SetSavePrimaries(const G4bool value) {
    if (value != fSavePrim) {
        fSavePrim = value;
    }
}

//==============================================================================

void RunAction::SetSaveCascades(const G4bool value) {
    if (value != fSaveCasc) {
        fSaveCasc = value;
    }
}

//==============================================================================

void RunAction::SetPrimariesName(const G4String& value) {
    if (value != fPrimName) {
        fPrimName = value;
    }
}

//==============================================================================

void RunAction::SetCascadesName(const G4String& value) {
    if (value != fCascName) {
        fCascName = value;
    }
}

//==============================================================================
