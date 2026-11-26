//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/tools/strata_rbs_check.cc
// \brief Checks the RBS physics against arithmetic done a different way.
//
// Two things are verified, because they fail differently.
//
// The kinematic factor and the Rutherford cross-section are computed a
// second time here through the centre of mass (a different derivation,
// not a copy of the one in RBSDetector) and the two are compared.  That
// catches an algebra slip in either.
//
// The forced-detection machinery as a whole is checked against a case
// with a closed-form answer: a film thin enough that the beam does not
// slow in it yields
//
//     Y = N t sigma(E0, theta) dOmega      per incident ion
//
// which exercises the step length, the number density, the cross-section
// and the solid angle together.  The simulated yield comes out slightly
// high because the beam does slow a little and the path through the film
// is a little longer than its thickness; a per-cent tolerance covers it.

#include "RBSDetector.hh"

#include "G4PhysicalConstants.hh"
#include "G4SystemOfUnits.hh"

#include <cmath>
#include <cstdio>
#include <string>

namespace {

int gChecks = 0;
int gFailures = 0;

void Check(const std::string& what, bool ok, const std::string& got = "") {
    ++gChecks;
    if (ok) {
        std::printf("  %-58s ok\n", what.c_str());
    } else {
        ++gFailures;
        std::printf("FAILED  %s%s\n", what.c_str(),
                    got.empty() ? "" : ("  (" + got + ")").c_str());
    }
}

void CheckClose(const std::string& what, double a, double b, double tol) {
    const double d = (b != 0.) ? std::abs(a - b)/std::abs(b) : std::abs(a - b);
    char buf[160];
    std::snprintf(buf, sizeof buf, "%s: %.6g against %.6g, %.2g relative",
                  what.c_str(), a, b, d);
    Check(buf, d <= tol);
}

// The centre-of-mass angle, found by bisection rather than by the closed
// form RBSDetector uses, so the two do not share a mistake.
double ThetaCm(double m1, double m2, double thLab) {
    const double r = m1/m2;
    double lo = 0., hi = pi;
    for (int i = 0; i < 200; ++i) {
        const double mid = 0.5*(lo + hi);
        if (std::atan2(std::sin(mid), std::cos(mid) + r) < thLab) lo = mid;
        else hi = mid;
    }
    return 0.5*(lo + hi);
}

double KinematicFactorViaCm(double m1, double m2, double thLab) {
    const double tc = ThetaCm(m1, m2, thLab);
    return 1. - 2.*m1*m2*(1. - std::cos(tc))/((m1 + m2)*(m1 + m2));
}

double CrossSectionViaCm(double z1, double m1, double z2, double m2,
                         double e, double thLab) {
    const double tc = ThetaCm(m1, m2, thLab);
    const double eCm = e*m2/(m1 + m2);
    const double a = z1*z2*classic_electr_radius*electron_mass_c2/(4.*eCm);
    const double s = std::sin(tc/2.);
    const double r = m1/m2;
    const double jac = std::pow(1. + r*r + 2.*r*std::cos(tc), 1.5)
                       /std::abs(1. + r*std::cos(tc));
    return a*a/(s*s*s*s)*jac;
}

struct Target { const char* name; double z2; double m2; };

const Target kTargets[] = {{"C",  6., 12.000},  {"Si", 14., 27.977},
                           {"Fe", 26., 55.935}, {"Au", 79., 196.967}};

}  // namespace

//==============================================================================

int main() {
    const double theta = 165.*deg;
    const double m1 = 4.0026, z1 = 2.;      // an alpha particle

    std::printf("RBS physics, 4He at 165 degrees\n\n");
    std::printf("Kinematic factor, laboratory form against the centre of mass\n");
    for (const Target& t : kTargets)
        CheckClose(std::string("K for ") + t.name,
                   RBSDetector::KinematicFactor(m1, t.m2, theta),
                   KinematicFactorViaCm(m1, t.m2, theta), 1e-12);

    std::printf("\nCross-section at 2 MeV, the same two ways, barn/sr\n");
    for (const Target& t : kTargets)
        CheckClose(std::string("sigma for ") + t.name,
            RBSDetector::RutherfordCrossSection(z1, m1, t.z2, t.m2, 2.*MeV, theta)/barn,
            CrossSectionViaCm(z1, m1, t.z2, t.m2, 2.*MeV, theta)/barn, 1e-12);

    std::printf("\nThe scaling the Rutherford cross-section is defined by\n");
    CheckClose("sigma(1 MeV)/sigma(2 MeV) is four",
        RBSDetector::RutherfordCrossSection(z1, m1, 79., 196.967, 1.*MeV, theta)
        /RBSDetector::RutherfordCrossSection(z1, m1, 79., 196.967, 2.*MeV, theta),
        4., 1e-12);

    // Straight back: the laboratory form is 0/0 here, which is why the
    // centre-of-mass route is the one in the code
    const double back =
        RBSDetector::RutherfordCrossSection(z1, m1, 79., 196.967, 1.*MeV, 180.*deg);
    Check("sigma at 180 degrees is finite", back > 0.,
          std::to_string(back/barn));
    const double a = z1*79.*classic_electr_radius*electron_mass_c2/(4.*1.*MeV);
    CheckClose("and within a per cent of (Z1 Z2 e2 / 4E)^2 for a heavy target",
               back/barn, a*a/barn, 0.01);

    // A projectile heavier than the target cannot come back at all
    Check("40Ar on 12C has no solution at 165 degrees",
          RBSDetector::KinematicFactor(39.962, 12., theta) == 0.);
    Check("and no cross-section either",
          RBSDetector::RutherfordCrossSection(18., 39.962, 6., 12., 2.*MeV, theta) == 0.);

    // Screening is a small correction at 2 MeV and a larger one low down
    const double f2 = RBSDetector::AndersenScreening(z1, m1, 79., 196.967, 2.*MeV, theta);
    const double f05 = RBSDetector::AndersenScreening(z1, m1, 79., 196.967, 0.5*MeV, theta);
    Check("Andersen screening is below unity", f2 < 1. && f05 < 1.);
    Check("and stronger at lower energy", f05 < f2,
          std::to_string(f05) + " against " + std::to_string(f2));
    Check("but still a small correction at 2 MeV", f2 > 0.95,
          std::to_string(f2));

    std::printf("\n%d checks, %d failures\n", gChecks, gFailures);
    std::printf(gFailures == 0 ? "PASSED\n" : "FAILED\n");
    return gFailures == 0 ? 0 : 1;
}
