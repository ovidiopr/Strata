//==============================================================================
/// \file Strata/tools/strata_dedx.cc
/// \brief Tabulate, or check, electronic stopping powers.
///
/// Two jobs, both of which the SRIM comparison needs:
///
///   --dump      write Geant4's own electronic stopping power for a
///               projectile/material pair, in the columnar format
///               /strata/physics/srim/loadTable reads.  Use it to put
///               Geant4 and SRIM side by side in a plot, and as the
///               starting point for a hand-edited table.
///
///   --compare   load a table, run the same pair through the 'srim' physics
///               list, and report the difference between what the table says
///               and what Geant4 then computes.  Feeding back a table that
///               was dumped from Geant4 must reproduce it: that is the
///               round-trip test of the parser, the interpolation and the
///               model wiring.
///
/// Usage:
///   strata_dedx --dump    <particle> <material> <out-file> [emin_keV emax_keV points]
///                         [--table <file>]
///   strata_dedx --compare <particle> <material> <table>   [emin_keV emax_keV points]
///
/// With --table, --dump loads that table and runs the 'srim' list, so that
/// dumping the same grid with and without it measures how faithfully the
/// tabulated grid reproduces the curve it was sampled from.
///
/// Energies are per particle, not per nucleon.  --dump writes to a file
/// rather than to stdout because Geant4 prints its banner there.
//==============================================================================

#include "DetectorConstruction.hh"
#include "PhysicsList.hh"
#include "SRIMStoppingData.hh"

#include "G4EmCalculator.hh"
#include "G4Material.hh"
#include "G4NistManager.hh"
#include "G4ParticleDefinition.hh"
#include "G4ParticleTable.hh"
#include "G4RunManagerFactory.hh"
#include "G4SystemOfUnits.hh"
#include "G4UImanager.hh"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

namespace {

void Usage(const char* argv0) {
    std::printf(
        "usage: %s --dump    <particle> <material> <out-file> "
        "[emin_keV emax_keV points] [--table <file>]\n"
        "       %s --compare <particle> <material> <table> "
        "[emin_keV emax_keV points]\n",
        argv0, argv0);
}

std::vector<G4double> Grid(G4double eminKeV, G4double emaxKeV, int points) {
    std::vector<G4double> e;
    e.reserve(points);
    const G4double lmin = std::log(eminKeV);
    const G4double step = (std::log(emaxKeV) - lmin)/(points - 1);
    for (int i = 0; i < points; ++i) e.push_back(std::exp(lmin + i*step)*keV);
    return e;
}

}  // namespace

//==============================================================================

int main(int argc, char** argv) {
    if (argc < 4) { Usage(argv[0]); return 2; }

    const std::string mode = argv[1];
    const G4String particleName = argv[2];
    const G4String materialName = argv[3];

    if (argc < 5) { Usage(argv[0]); return 2; }
    const G4String fileArg = argv[4];      // out-file for dump, table for compare
    const int firstEnergyArg = 5;
    if (mode != "--compare" && mode != "--dump") {
        Usage(argv[0]);
        return 2;
    }
    const G4String tableFile = fileArg;

    G4double eminKeV = 1.0, emaxKeV = 1.0e4;
    int points = 100;
    G4String preloadTable;
    {
        int i = firstEnergyArg;
        auto takeNumber = [&](G4double& target) {
            if (i < argc && argv[i][0] != '-') { target = std::atof(argv[i]); ++i; }
        };
        G4double p = points;
        takeNumber(eminKeV);
        takeNumber(emaxKeV);
        takeNumber(p);
        points = static_cast<int>(p);
        for (; i < argc; ++i)
            if (std::string(argv[i]) == "--table" && i + 1 < argc)
                preloadTable = argv[++i];
    }
    if (points < 3 || eminKeV <= 0. || emaxKeV <= eminKeV) {
        std::fprintf(stderr, "bad energy range\n");
        return 2;
    }

    // --- a minimal Geant4 session ----------------------------------------
    auto* runManager =
        G4RunManagerFactory::CreateRunManager(G4RunManagerType::SerialOnly);
    auto* detector = new DetectorConstruction();
    runManager->SetUserInitialization(detector);
    runManager->SetUserInitialization(new PhysicsList());

    G4UImanager* ui = G4UImanager::GetUIpointer();
    ui->ApplyCommand("/control/verbose 0");
    ui->ApplyCommand("/run/verbose 0");

    // The material has to be in the geometry for the physics tables to cover
    // it, so make the single layer out of it.
    ui->ApplyCommand("/strata/geometry/layerNumber 1");
    ui->ApplyCommand("/strata/geometry/layerMaterial 0 " + materialName);

    if (mode == "--compare") {
        G4String error;
        if (!SRIMStoppingData::Instance().LoadFile(particleName, materialName,
                                                   tableFile, error)) {
            std::fprintf(stderr, "cannot load table: %s\n", error.c_str());
            return 1;
        }
        ui->ApplyCommand("/strata/physics/addPhysics srim");
    } else if (!preloadTable.empty()) {
        G4String error;
        if (!SRIMStoppingData::Instance().LoadFile(particleName, materialName,
                                                   preloadTable, error)) {
            std::fprintf(stderr, "cannot load table: %s\n", error.c_str());
            return 1;
        }
        ui->ApplyCommand("/strata/physics/addPhysics srim");
    } else {
        ui->ApplyCommand("/strata/physics/addPhysics standardNR");
    }

    ui->ApplyCommand("/run/initialize");
    ui->ApplyCommand("/run/beamOn 0");   // forces the physics tables to build

    G4Material* material =
        G4NistManager::Instance()->FindOrBuildMaterial(materialName);
    if (material == nullptr) material = G4Material::GetMaterial(materialName);
    if (material == nullptr) {
        std::fprintf(stderr, "unknown material '%s'\n", materialName.c_str());
        return 1;
    }
    G4ParticleDefinition* particle =
        G4ParticleTable::GetParticleTable()->FindParticle(particleName);
    if (particle == nullptr) {
        std::fprintf(stderr, "unknown particle '%s'\n", particleName.c_str());
        return 1;
    }

    G4EmCalculator calc;
    const std::vector<G4double> energies = Grid(eminKeV, emaxKeV, points);

    if (mode == "--dump") {
        std::FILE* out = std::fopen(fileArg.c_str(), "w");
        if (out == nullptr) {
            std::fprintf(stderr, "cannot write '%s'\n", fileArg.c_str());
            return 1;
        }
        #define OUT(...) std::fprintf(out, __VA_ARGS__)
        OUT("# strata stopping table\n");
        OUT("# generated by strata_dedx, this is NOT SRIM output\n");
        OUT("# physics %s\n",
            preloadTable.empty() ? "standardNR (Geant4 ICRU/ASTAR)"
                                 : "srim, driven by the table below");
        if (!preloadTable.empty()) OUT("# source_table %s\n", preloadTable.c_str());
        OUT("# particle %s\n", particleName.c_str());
        OUT("# material %s\n", materialName.c_str());
        OUT("# density %.6g g/cm3\n", material->GetDensity()/(g/cm3));
        OUT("# energy_unit keV\n");
        OUT("# dedx_unit keV/um\n");
        OUT("# %-14s %-16s %-16s\n", "energy", "electronic", "nuclear");
        for (const G4double e : energies) {
            const G4double se = calc.ComputeElectronicDEDX(e, particle, material);
            const G4double sn = calc.ComputeNuclearDEDX(e, particle, material);
            OUT("  %-14.6g %-16.8g %-16.8g\n",
                e/keV, se/(keV/um), sn/(keV/um));
        }
        #undef OUT
        std::fclose(out);
        std::printf("wrote %s (%d points, %.4g to %.4g keV)\n",
                    fileArg.c_str(), points, eminKeV, emaxKeV);
        delete runManager;
        return 0;
    }

    // --- compare ----------------------------------------------------------
    const SRIMStoppingTable* table =
        SRIMStoppingData::Instance().Find(particle, material);
    if (table == nullptr) {
        std::fprintf(stderr, "the table did not register for %s in %s\n",
                     particleName.c_str(), materialName.c_str());
        return 1;
    }

    std::printf("# comparing the loaded table against what the 'srim' list "
                "computes\n");
    std::printf("# %-12s %-16s %-16s %-10s\n",
                "E [keV]", "table [keV/um]", "Geant4 [keV/um]", "rel.diff");

    G4double worst = 0.;
    G4double worstAt = 0.;
    int compared = 0;
    for (const G4double e : energies) {
        if (!table->InRange(e)) continue;      // clamped region is not a test
        const G4double fromTable = table->ElectronicDEDX(e);
        const G4double fromG4 = calc.ComputeElectronicDEDX(e, particle, material);
        if (fromTable <= 0.) continue;
        const G4double rel = std::fabs(fromG4 - fromTable)/fromTable;
        if (rel > worst) { worst = rel; worstAt = e; }
        ++compared;
        std::printf("  %-12.6g %-16.8g %-16.8g %-10.3g\n",
                    e/keV, fromTable/(keV/um), fromG4/(keV/um), rel);
    }

    std::printf("\n%d points compared; worst relative difference %.3g at "
                "%.4g keV\n", compared, worst, worstAt/keV);

    delete runManager;

    // A round trip through the dump/load path should agree to well inside a
    // per cent; anything larger means the table is not reaching the model.
    const G4double tolerance = 0.01;
    if (compared < 3) {
        std::printf("FAILED: too few points inside the tabulated range\n");
        return 1;
    }
    if (worst > tolerance) {
        std::printf("FAILED: worst difference %.3g exceeds %.3g\n",
                    worst, tolerance);
        return 1;
    }
    std::printf("PASSED\n");
    return 0;
}

//==============================================================================
