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
/// \file Strata/include/RunAction.hh
/// \brief Definition of the RunAction class
//
//
//==============================================================================
//==============================================================================

#ifndef RunAction_h
#define RunAction_h 1

#include "G4UserRunAction.hh"
#include "globals.hh"
#include <fstream>

//==============================================================================

class Run;
class RunActionMessenger;
class DetectorConstruction;
class PrimaryGeneratorAction;
class HistoManager;
class G4Step;

//==============================================================================

class RunAction : public G4UserRunAction {

public:
    /// Whether a run writes its histograms to disk.  True for the batch
    /// executable, which is what a macro expects; the shared library turns
    /// it off when it creates a session, because a front end reads the
    /// histograms out of memory through the API and a file it never asked
    /// for is at best clutter, and at worst the process writing into a
    /// directory it was launched from rather than the one it works in.
    /// Process-wide rather than per-thread: it is read once per run and
    /// the messenger has to reach every worker.
    static void SetWriteHistograms(G4bool value) { fgWriteHistograms = value; }
    static G4bool WriteHistograms() { return fgWriteHistograms; }


    RunAction(DetectorConstruction* det, PrimaryGeneratorAction* prim = 0);
    ~RunAction();

    virtual G4Run* GenerateRun();
    virtual void BeginOfRunAction(const G4Run*);
    virtual void EndOfRunAction(const G4Run*);

    void WriteToFiles(const G4Step*);

    void SetSavePrimaries(const G4bool);
    void SetSaveCascades(const G4bool);
    void SetPrimariesName(const G4String&);
    void SetCascadesName(const G4String&);

    inline G4bool GetSavePrimaries() const { return fSavePrim; };
    inline G4bool GetSaveCascades() const { return fSaveCasc; };
    inline G4String GetPrimariesName() const { return fPrimName; };
    inline G4String GetCascadesName() const { return fCascName; };

private:
    DetectorConstruction* fDetector;
    PrimaryGeneratorAction* fPrimary;
    Run* fRun;
    HistoManager* fHistoManager;

    RunActionMessenger* fRunMessenger;

    /// Did OpenFile() succeed for this run?  Geant4 only warns when it
    /// cannot create the analysis file and then crashes inside Write(),
    /// so the result has to be remembered and checked.
    G4bool fAnalysisOpen;

    /// The throwaway file a multithreaded run has to be written to even
    /// when no output was asked for, and the name that was displaced to
    /// make room for it.  Empty in every other case.
    G4String fScratchFile;
    G4String fWantedFile;

    static G4bool fgWriteHistograms;

    G4bool fSavePrim;           //opr Save primaries file
    G4bool fSaveCasc;           //opr Save cascades file
    std::ofstream fPrimFile;    //ar  Primaries file
    std::ofstream fCascFile;    //ar  Cascades file

    /// The per-thread part of a track file, empty when this thread writes
    /// the whole file itself
    static G4String TrackPartName(const G4String&);
    /// Opens either the file itself or this thread's part of it
    static void OpenTrackFile(std::ofstream&, const G4String&);
    /// Appends the parts to the whole file and removes them
    static void MergeTrackFile(const G4String&);
    G4String fPrimName;         //opr Primaries file name
    G4String fCascName;         //opr Cascades file name
};

//==============================================================================

#endif

