/*
 * ********************************************************************
 * * Strata: a Geant4 application for ion irradiation of layered       *
 * * targets.                                                          *
 * ********************************************************************
 *
 * \file Strata/api/strata_restart_check.c
 * \brief What the engine process can do that the library cannot.
 *
 * strata_smoke already runs the whole ABI over the pipe.  This checks the
 * two things the pipe exists for: starting an engine more than once in one
 * front end, and surviving one that is not there.
 *
 * STRATA_ENGINE names the engine; STRATA_DATA names the Geant4 datasets.
 */

#include "strata_api.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int gChecks = 0;
static int gFailures = 0;

static void check(int ok, const char* what) {
    ++gChecks;
    if (!ok) ++gFailures;
    printf("%-58s %s\n", what, ok ? "ok" : "FAILED");
}

static const char* DataDir(void) {
    const char* d = getenv("STRATA_DATA");
    return (d != NULL && *d != '\0') ? d : "";
}

/* One whole session, from an engine of its own, into edep */
static int Session(const char* material, double* edep) {
    StrataSession* s;
    StrataRunStatsC stats;
    char mat[160];
    int i;
    const char* setup[8];

    *edep = 0.;
    if (strata_set_data_dir(DataDir()) != STRATA_OK) return 0;
    s = strata_create(2);
    if (s == NULL) return 0;

    snprintf(mat, sizeof mat, "/strata/geometry/layerMaterial 0 %s", material);
    setup[0] = "/strata/geometry/setSizeYZ 1 mm";
    setup[1] = "/strata/geometry/layerNumber 1";
    setup[2] = "/strata/geometry/layerThickness 0 10 um";
    setup[3] = mat;
    setup[4] = "/strata/physics/addPhysics standardNR";
    setup[5] = "/strata/random/randomize false";
    setup[6] = "/strata/random/seeds 12345 67890";
    setup[7] = NULL;
    for (i = 0; setup[i] != NULL; i++) strata_apply(s, setup[i]);

    if (strata_initialize(s) != STRATA_OK) return 0;
    strata_apply(s, "/gun/particle proton");
    strata_apply(s, "/gun/energy 2 MeV");
    if (strata_beam_on(s, 200) != STRATA_OK) return 0;
    if (strata_wait(s, 600000) != STRATA_OK) return 0;
    if (strata_get_stats(s, &stats) != STRATA_OK) return 0;

    *edep = stats.edep;
    strata_destroy(s);
    return 1;
}

int main(void) {
    double first = 0., other = 0., again = 0.;

    /* An engine that is not there is an error, not a crash */
    if (getenv("STRATA_ENGINE_MISSING") != NULL) {
        check(strata_set_data_dir(DataDir()) == STRATA_ERR_STATE,
              "a missing engine answers with an error");
        check(strata_create(2) == NULL, "and refuses to open a session");
        check(strlen(strata_last_error(NULL)) > 0,
              "and says what went wrong");
        printf("\n%d checks, %d failures\n", gChecks, gFailures);
        printf("%s\n", gFailures == 0 ? "PASSED" : "FAILED");
        return gFailures == 0 ? 0 : 1;
    }

    check(Session("G4_Si", &first), "a first engine runs");
    check(Session("G4_Au", &other), "a second one starts in the same front end");
    check(Session("G4_Si", &again), "and a third");

    printf("  edep: %.6g, %.6g, %.6g MeV\n", first, other, again);

    /* The seeds are fixed, so the same geometry has to give the same number
       however many engines have been started and stopped in between.  Only to
       the last bits: the threads' sums are merged in the order they finish */
    check(first > 0. && fabs(first - again) <= 1e-12*first,
          "a restarted engine repeats the first one");
    check(other != first, "and a different geometry gives a different answer");

    printf("\n%d checks, %d failures\n", gChecks, gFailures);
    printf("%s\n", gFailures == 0 ? "PASSED" : "FAILED");
    return gFailures == 0 ? 0 : 1;
}
