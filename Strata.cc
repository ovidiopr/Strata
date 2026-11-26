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
/// \file Strata/Strata.cc
/// \brief Strata's main program
//
// 
//==============================================================================
//==============================================================================

#include <vector>
#include <string>
#include <filesystem>
#include <system_error>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#elif defined(__APPLE__)
#include <mach-o/dyld.h>
#endif

#include "G4Types.hh"

#ifdef G4MULTITHREADED
#include "G4MTRunManager.hh"
#else
#include "G4RunManager.hh"
#endif

#include "G4UImanager.hh"
#include "Randomize.hh"
#include "RandomSetup.hh"

#include "DetectorConstruction.hh"
#include "PhysicsList.hh"
#include "PrimaryGeneratorAction.hh"

#include "ActionInitialization.hh"
#include "Run.hh"
#include "SteppingVerbose.hh"

#include "G4UIExecutive.hh"
#include "G4VisExecutive.hh"

//==============================================================================

namespace fs = std::filesystem;

// The folder of this executable, with links resolved
fs::path ExecutableDir(const char* argv0) {
    fs::path exe = argv0;
#if defined(_WIN32)
    wchar_t buf[MAX_PATH];
    if (GetModuleFileNameW(nullptr, buf, MAX_PATH) > 0) exe = buf;
#elif defined(__APPLE__)
    uint32_t size = 0;
    _NSGetExecutablePath(nullptr, &size);
    std::string buf(size, '\0');
    if (_NSGetExecutablePath(buf.data(), &size) == 0) exe = buf.c_str();
#else
    exe = "/proc/self/exe";
#endif
    std::error_code ec;
    const fs::path real = fs::canonical(exe, ec);
    return (ec ? fs::absolute(argv0, ec) : real).parent_path();
}

// The macros folder: the working directory's first, then the installed one
fs::path MacrosDir(const char* argv0) {
    const fs::path exe = ExecutableDir(argv0);
    const fs::path candidates[] = {
        fs::current_path() / "macros",
        exe / "macros",                          // build tree, Windows
        exe / ".." / "Resources" / "macros",     // macOS bundle
        exe / ".." / "share" / "strata" / "macros",
        exe / ".." / ".." / "share" / "strata" / "macros"};  // Debian
    std::error_code ec;
    for (const auto& dir : candidates)
        if (fs::exists(dir / "vis.mac", ec)) return fs::weakly_canonical(dir, ec);
    return "macros";
}

int main(int argc, char** argv) {
    enum mode_states {readMacros, readThreads};

    std::vector<G4String> macroFiles;
    G4int numThreads = 0;
    G4bool graphicalMode = false;
    G4bool batchVis = false;

    std::vector<G4String> args;
    args.assign(argv, argv + argc);

    std::string help_msg("Usage: " + args[0] + " [-h] [-g]" +
#ifdef G4MULTITHREADED
                         " [-n Threads]" +
#endif
                         " [-v] [file.mac ...]\n" +
                         "            -h --> Show this message.\n" +
                         "            -g --> Graphical (interactive) mode.\n" +
                         "            -v --> Build the visualisation manager in batch mode,\n"
                         "                   so a macro can write a picture with a\n"
                         "                   file-based driver (VRML2FILE, HepRepFile,\n"
                         "                   RayTracer, ...) without opening a window.\n" +
#ifdef G4MULTITHREADED
                         "            -n --> Define number of threads.\n" +
#endif
                         "                   All other arguments are interpreted as macro files.\n");

    // Now remove first element (exe name)
    args.erase (args.begin());

    G4int mode = readMacros;
    for (const auto& arg : args) {
        // Detecting new read mode (if it is a valid -key)
        if (arg == "-h") {
            std::cout << help_msg << std::endl;
            return 0;
        }

        if (arg == "-g") {
            graphicalMode = true;
            mode = readMacros;
            continue;
        }

        if (arg == "-v") {
            batchVis = true;
            mode = readMacros;
            continue;
        }

#ifdef G4MULTITHREADED
        if (arg == "-n") {
            mode = readThreads;
            continue;
        }

        if (mode == readThreads) {
            numThreads = std::stoi(arg);
            mode = readMacros;
            continue;
        }
#endif

        // If nothing else, then the argument is the name of a macro file
        macroFiles.push_back(arg);
        std::cout << arg << "\n";
    }

    // If no macro name was provided, set an interactive session
    if (macroFiles.empty())
        graphicalMode = true;

    // Detect interactive mode and define UI session
    G4UIExecutive* ui = nullptr;
    if (graphicalMode)
        ui = new G4UIExecutive(argc, argv);

    // The generator and the seeds
    RandomSetup::Instance()->Apply();

    // Verbose output class
    G4VSteppingVerbose::SetInstance(new SteppingVerbose);

    // Construct the default run manager
#ifdef G4MULTITHREADED
    auto* runManager = new G4MTRunManager;
    G4int nThreads = std::min(G4Threading::G4GetNumberOfCores(), 4);
    if (numThreads > 0)
        nThreads = numThreads;

    runManager->SetNumberOfThreads(nThreads);
    G4cout << "===== Strata is started with "
           << runManager->GetNumberOfThreads() << " threads =====" << G4endl;
#else
    auto* runManager = new G4RunManager;
#endif

    // Set mandatory initialization classes
    auto* detector = new DetectorConstruction();
    auto* physics = new PhysicsList();

    runManager->SetUserInitialization(detector);
    runManager->SetUserInitialization(physics);

    // Set user action classes
    runManager->SetUserInitialization(new ActionInitialization(detector));

    // Initialize visualization
    G4VisManager* visManager = nullptr;

    // Get the pointer to the User Interface manager
    G4UImanager* UImanager = G4UImanager::GetUIpointer();

    // Run macros from the 'macros' directory, here or where Strata is installed
    const fs::path macros = MacrosDir(argv[0]);
    const std::string visInit = (macros / "vis_init.mac").string();
    const std::string vis = (macros / "vis.mac").string();
#if defined(_WIN32)
    UImanager->SetMacroSearchPath("macros");  // ':' separates the entries
#else
    UImanager->SetMacroSearchPath("macros:" + macros.string());
#endif
    UImanager->ParseMacroSearchPath();
    // The visualisation manager is what makes /vis commands work at all
    if (ui || batchVis) {
        visManager = new G4VisExecutive;
        visManager->Initialize();
    }

    if (ui) {
        // Interactive mode
        if (macroFiles.empty()) {
            UImanager->ExecuteMacroFile(visInit.c_str());
            UImanager->ExecuteMacroFile(vis.c_str());
        } else {
            // Initialize before calling the gui
            G4String command = "/control/execute ";
            for (const auto& fileName : macroFiles) {
                UImanager->ApplyCommand(command + fileName);
            }
            // Now load the visualization config
            UImanager->ExecuteMacroFile(vis.c_str());
        }
        ui->SessionStart();
        delete ui;
    } else {
        // Batch mode
        G4String command = "/control/execute ";
        for (const auto& fileName : macroFiles) {
            UImanager->ApplyCommand(command + fileName);
        }
    }

    // Job termination
    delete visManager;
    delete runManager;
}

//==============================================================================
