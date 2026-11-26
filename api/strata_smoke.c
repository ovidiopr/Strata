/*============================================================================
 * Strata/api/strata_smoke.c
 *
 * Exercises the C ABI the same way the Pascal binding does: create a
 * session, configure the target through UI commands, run a beam
 * asynchronously while draining the log and watching the progress counter,
 * then read the statistics and a histogram back.
 *
 * Deliberately written in plain C with no Geant4 headers in sight: if this
 * compiles and runs, the boundary is clean.
 *==========================================================================*/

#include "strata_api.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#  include <windows.h>
#  define sleep_ms(ms) Sleep(ms)
#else
#  include <unistd.h>
#  define sleep_ms(ms) usleep((ms) * 1000)
#endif

static int failures = 0;

static void check(int condition, const char* what) {
    printf("%-55s %s\n", what, condition ? "ok" : "FAILED");
    if (!condition) failures++;
}

static void drain_log(StrataSession* s, int echo) {
    char line[4096];
    int isError = 0;
    while (strata_log_pop(s, line, (int)sizeof(line), &isError)) {
        if (echo) printf("  %s%s\n", isError ? "[err] " : "", line);
    }
}

int main(int argc, char** argv) {
    const long nEvents = (argc > 1) ? atol(argv[1]) : 200;
    const int  nThreads = (argc > 2) ? atoi(argv[2]) : 2;

    printf("strata %s, built against %s\n",
           strata_version(), strata_geant4_version());

    StrataSession* s = strata_create(nThreads);
    check(s != NULL, "strata_create");
    if (s == NULL) return 1;

    check(strata_create(1) == NULL, "second strata_create refused");

    /* --- configure ----------------------------------------------------- */
    check(strata_apply(s, "/control/verbose 0") == STRATA_OK, "/control/verbose");
    check(strata_apply(s, "/run/verbose 0") == STRATA_OK, "/run/verbose");
    check(strata_apply(s, "/strata/geometry/setSizeYZ 10 cm") == STRATA_OK,
          "/strata/geometry/setSizeYZ");
    check(strata_apply(s, "/strata/geometry/layerNumber 2") == STRATA_OK,
          "/strata/geometry/layerNumber");
    check(strata_apply(s, "/strata/geometry/layerThickness 0 2 cm") == STRATA_OK,
          "/strata/geometry/layerThickness 0");
    check(strata_apply(s, "/strata/geometry/layerMaterial 0 G4_WATER") == STRATA_OK,
          "/strata/geometry/layerMaterial 0");
    check(strata_apply(s, "/strata/geometry/layerThickness 1 1 cm") == STRATA_OK,
          "/strata/geometry/layerThickness 1");
    check(strata_apply(s, "/strata/geometry/layerMaterial 1 G4_Al") == STRATA_OK,
          "/strata/geometry/layerMaterial 1");
    check(strata_apply(s, "/strata/physics/addPhysics local") == STRATA_OK,
          "/strata/physics/addPhysics local");

    /* a command that does not exist must be reported, not swallowed */
    check(strata_apply(s, "/strata/not/a/command 1") == STRATA_ERR_COMMAND,
          "unknown command rejected");
    printf("  last error: %s\n", strata_last_error(s));

    /* running before initialising is a state error, not a crash */
    check(strata_beam_on(s, 10) == STRATA_ERR_STATE, "beam_on before initialize");

    check(strata_initialize(s) == STRATA_OK, "strata_initialize");
    check(strata_state(s) == STRATA_STATE_INITIALISED, "state == INITIALISED");

    /* --- introspection -------------------------------------------------- */
    check(strata_layer_count(s) == 2, "strata_layer_count == 2");
    for (int i = 0; i < strata_layer_count(s); ++i) {
        StrataLayerInfoC layer;
        memset(&layer, 0, sizeof(layer));
        if (strata_get_layer(s, i, &layer) == STRATA_OK) {
            printf("  layer %d: %-12s %8.3f mm  rho=%8.4f  x=[%8.3f,%8.3f] mm\n",
                   i, layer.material, layer.thickness,
                   layer.density, layer.xMin, layer.xMax);
        }
    }
    check(strata_get_layer(s, 99, NULL) == STRATA_ERR_RANGE,
          "strata_get_layer out of range");

    const int nMat = strata_material_count(s);
    check(nMat > 100, "NIST material catalogue populated");
    check(strata_physics_count() > 20, "physics list catalogue populated");
    check(strata_particle_count(s) > 0, "particle table populated");

    {
        /* The command tree: asked for its size first, then read whole */
        const int need = strata_get_command_tree(s, NULL, 0);
        check(need > 1000, "command tree reports its size");
        if (need > 1000) {
            char* tree = (char*)malloc((size_t)need);
            const int again = tree ? strata_get_command_tree(s, tree, need) : 0;
            check(again == need && strlen(tree) == (size_t)(need - 1),
                  "command tree read whole");
            check(tree && strstr(tree, "\nC\t/run/beamOn\t") != NULL,
                  "command tree holds /run/beamOn");
            free(tree);
        }
    }

    /* --- beam ------------------------------------------------------------ */
    check(strata_apply(s, "/gun/particle proton") == STRATA_OK, "/gun/particle");
    check(strata_apply(s, "/gun/energy 100 MeV") == STRATA_OK, "/gun/energy");
    check(strata_apply(s, "/analysis/h1/set 1 100 0 30 mm") == STRATA_OK,
          "/analysis/h1/set 1");

    drain_log(s, 0);

    check(strata_beam_on(s, nEvents) == STRATA_OK, "strata_beam_on");
    check(strata_state(s) == STRATA_STATE_RUNNING ||
          strata_state(s) == STRATA_STATE_INITIALISED, "state during run");

    int polls = 0;
    while (strata_state(s) == STRATA_STATE_RUNNING ||
           strata_state(s) == STRATA_STATE_ABORTING) {
        drain_log(s, 0);
        if ((polls++ % 10) == 0) {
            printf("  progress %5.1f %%  (%ld / %ld events)\n",
                   100.0 * strata_progress(s),
                   strata_events_done(s), strata_events_requested(s));
        }
        sleep_ms(50);
    }
    check(strata_wait(s, 5000) == STRATA_OK, "strata_wait after completion");
    check(strata_run_status(s) == STRATA_OK, "strata_run_status");
    drain_log(s, 0);

    check(strata_events_done(s) == nEvents, "all events accounted for");

    /* --- results --------------------------------------------------------- */
    StrataRunStatsC stats;
    memset(&stats, 0, sizeof(stats));
    check(strata_get_stats(s, &stats) == STRATA_OK, "strata_get_stats");
    check(stats.valid == 1, "stats.valid");
    check(stats.events == nEvents, "stats.events matches request");
    check(strcmp(stats.particle, "proton") == 0, "stats.particle == proton");

    printf("\n  particle            : %s at %.3f MeV\n", stats.particle, stats.beamEnergy);
    printf("  events              : %ld\n", stats.events);
    printf("  projected range     : %.4f +- %.4f mm\n",
           stats.projRange, stats.projRangeRms);
    printf("  energy deposited    : %.4f +- %.4f MeV\n", stats.edep, stats.edepRms);
    printf("  NIEL                : %.6f MeV\n", stats.niel);
    printf("  energy balance      : %.4f MeV\n", stats.energyBalance);
    printf("  track length (q!=0) : %.4f mm\n", stats.trakLenCharged);
    printf("  secondaries / event : %.3f e-, %.3f gamma\n",
           stats.electronPerEvent, stats.gammaPerEvent);
    printf("  Highland theta0     : %.4f mrad\n", stats.mscHighland * 1000.0);

    check(stats.edep > 0.0, "edep > 0");
    check(stats.projRange > 0.0, "projRange > 0");

    /* --- histogram ------------------------------------------------------- */
    StrataH1InfoC info;
    memset(&info, 0, sizeof(info));
    check(strata_get_h1_info(s, 1, &info) == STRATA_OK, "strata_get_h1_info(1)");
    printf("\n  h1[1] '%s' active=%d nbins=%d range=[%g,%g]\n",
           info.title, info.active, info.nbins, info.xMin, info.xMax);
    check(info.active == 1, "h1[1] active");
    check(info.nbins == 100, "h1[1] has 100 bins");

    double* centres = (double*)malloc(sizeof(double) * (size_t)info.nbins);
    double* heights = (double*)malloc(sizeof(double) * (size_t)info.nbins);
    const int n = strata_get_h1_data(s, 1, centres, heights, NULL, info.nbins);
    check(n == info.nbins, "strata_get_h1_data returned every bin");

    double integral = 0.0, peak = 0.0, peakAt = 0.0;
    for (int i = 0; i < n; ++i) {
        integral += heights[i];
        if (heights[i] > peak) { peak = heights[i]; peakAt = centres[i]; }
    }
    printf("  h1[1] integral=%.4g, peak=%.4g at x=%.3f mm\n",
           integral, peak, peakAt);
    check(integral > 0.0, "h1[1] has content");
    free(centres);
    free(heights);

    /* --- teardown -------------------------------------------------------- */
    printf("\n  log lines dropped   : %ld\n", strata_log_dropped(s));
    strata_destroy(s);
    printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "PASSED",
           failures, failures == 1 ? "" : "s");

    /* See the comment on strata_exit_process() in strata_api.h: returning
     * normally would run Geant4's static destructors on the wrong thread. */
    strata_exit_process(failures ? 1 : 0);
    return failures ? 1 : 0;
}
