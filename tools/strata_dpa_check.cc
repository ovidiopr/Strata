//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/tools/strata_dpa_check.cc
// \brief Checks the displacement counting against the paper it comes from.

#include "DamageCalculator.hh"

#include "G4SystemOfUnits.hh"

#include <cmath>
#include <cstdio>
#include <string>

namespace {

int gChecks = 0;
int gFailures = 0;

void Check(bool ok, const std::string& what) {
    ++gChecks;
    if (!ok) ++gFailures;
    std::printf("%-62s %s\n", what.c_str(), ok ? "ok" : "FAILED");
}

void CheckNear(double got, double want, double tol, const std::string& what) {
    const bool ok = std::abs(got - want) <= tol*std::max(1.0, std::abs(want));
    ++gChecks;
    if (!ok) ++gFailures;
    std::printf("%-62s %s", what.c_str(), ok ? "ok" : "FAILED");
    if (!ok) std::printf("  (got %.6g, wanted %.6g)", got, want);
    std::printf("\n");
}

// Nordlund et al., Nature Communications 9 (2018) 1084, Table 1
const DamageConstants kIron{40.*eV, -0.568, 0.286};
const DamageConstants kTungsten{70.*eV, -0.56, 0.12};

}  // namespace

int main() {
    // Equation 6: nothing below the threshold, one Frenkel pair up to the
    // point where NRT itself reaches one
    Check(DamageCalculator::NrtDisplacements(39.*eV, kIron.ed) == 0.,
          "iron: a recoil below Ed displaces nothing");
    Check(DamageCalculator::ArcDisplacements(39.*eV, kIron) == 0.,
          "and arc-dpa agrees");
    CheckNear(DamageCalculator::NrtDisplacements(40.*eV, kIron.ed), 1., 1e-12,
              "at Ed exactly one displacement");
    CheckNear(DamageCalculator::NrtDisplacements(99.*eV, kIron.ed), 1., 1e-12,
              "and still one just below 2Ed/0.8");

    // Continuous where the two branches meet, because xi is one there
    const double threshold = 2.*kIron.ed/0.8;
    CheckNear(DamageCalculator::NrtDisplacements(threshold, kIron.ed), 1., 1e-12,
              "NRT is one at 2Ed/0.8, where the linear branch starts");
    CheckNear(DamageCalculator::ArcDisplacements(threshold, kIron), 1., 1e-12,
              "and arc-dpa meets it there without a step");

    // The linear branch is NRT's own 0.8 Tdam / 2 Ed
    CheckNear(DamageCalculator::NrtDisplacements(10.*keV, kIron.ed), 100., 1e-12,
              "10 keV in iron is 100 NRT displacements");
    CheckNear(DamageCalculator::NrtDisplacements(10.*keV, kTungsten.ed),
              0.8*10000./(2.*70.), 1e-12,
              "and 57.1 in tungsten, which needs more to displace an atom");

    // Equation 7: the correction tends to c_arc, the paper's central result
    // that an energetic cascade leaves about a third of what NRT counts
    const double ratioHigh = DamageCalculator::ArcDisplacements(10.*MeV, kIron)
                             /DamageCalculator::NrtDisplacements(10.*MeV, kIron.ed);
    CheckNear(ratioHigh, kIron.cArc, 0.02,
              "iron: the arc-dpa ratio tends to c_arc = 0.286");
    const double ratioW = DamageCalculator::ArcDisplacements(10.*MeV, kTungsten)
                          /DamageCalculator::NrtDisplacements(10.*MeV, kTungsten.ed);
    CheckNear(ratioW, kTungsten.cArc, 0.02,
              "tungsten: to c_arc = 0.12");

    // Monotonic in between, and never above NRT
    double previous = 0.;
    bool rising = true, bounded = true;
    for (double t = 100.; t <= 1.e7; t *= 1.3) {
        const double arc = DamageCalculator::ArcDisplacements(t*eV, kIron);
        const double nrt = DamageCalculator::NrtDisplacements(t*eV, kIron.ed);
        if (arc < previous) rising = false;
        if (arc > nrt*1.000001) bounded = false;
        previous = arc;
    }
    Check(rising, "arc-dpa never falls as the damage energy rises");
    Check(bounded, "and never counts more displacements than NRT");

    std::printf("\n%d checks, %d failures\n", gChecks, gFailures);
    std::printf("%s\n", gFailures == 0 ? "PASSED" : "FAILED");
    return gFailures == 0 ? 0 : 1;
}
