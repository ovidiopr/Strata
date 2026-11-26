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
/// \file Strata/include/HistoManager.hh
/// \brief Definition of the HistoManager class
//
//
// 
//==============================================================================
//==============================================================================

#ifndef HistoManager_h
#define HistoManager_h 1

#include "globals.hh"

#include "G4AnalysisManager.hh"

//==============================================================================

// What the x axis of one histogram measures.  A front end needs this to put
// a sensible range on an axis and to refuse a value in the wrong dimension;
// guessing it from the title, or keeping a second list keyed by histogram
// number, is how the two drift apart.
enum StrataH1Axis {
    kH1None = 0,      // dimensionless, or a slot that is never shown
    kH1Length,        // a depth or a position in the target
    kH1Energy,
    kH1FwdAngle,      // leaves through the far face:  0 to 90 degrees
    kH1BackAngle      // comes back out the way it came: 90 to 180
    // There is deliberately no "logarithmic" kind.  log10 in
    // /analysis/h1/set is a binning scheme, not a dimension: the spectra
    // titled "log scale" are filled with the same energy as their linear
    // twins, so their axis is an energy and a unit belongs on it.
};

// What end of run divides one histogram by.  Six of them are turned into
// per-event spectra when the run finishes, and a front end that draws one
// while the run is still going has to divide by the same thing or the curve
// changes scale by a factor of thousands the moment the run ends.  Keeping
// it here, beside the titles and the axes, is what stops the list of six
// from drifting away from the table it belongs to.
enum StrataH1Norm {
    kH1Raw = 0,            // counts, left as they are
    kH1PerEvent,           // divided by the events in the run
    kH1PerEventPerWidth    // and by the bin width as well, giving dN/dx
};

// Ids past TestEm7's own.  These start at a round number, with 72 to 79
// left empty, so that the block of TestEm7 spectra and the block of
// Strata's own stay apart as more of ours are added.  A macro that sets a
// histogram names it by number, so an id that moves breaks every macro
// written against it -- which is why the room is left now.

// Displacement damage, from the recoils of a cascade
const G4int kStrataH1DpaNrt = 4;
const G4int kStrataH1DpaArc = 5;
const G4int kStrataH1Pka    = 6;

// Neutrons.  They used to be counted among the neutrals, together with the
// gammas, which made the neutral spectra of anything hydrogenous largely a
// capture line: 2 MeV neutrons into 20 cm of polyethylene put 35% of h1[30]
// and 26% of h1[50] in the 2.223 MeV peak of H(n,gamma)D.  Each neutron
// block sits in the same decade as the neutral one it was split out of,
// in the holes that were already there, and the order inside an exit block
// repeats the neutral one: energy, energy fluence, space angle, projected
// angle.  "Neutral" now means every neutral that is not a neutron.
const G4int kStrataH1NeutronBorn        = 17;   // beside h1[12], the gammas
const G4int kStrataH1NeutronBornLog     = 18;   // beside h1[14]
const G4int kStrataH1NeutronTransmitted = 34;   // beside h1[30] to h1[33]
const G4int kStrataH1NeutronReflected   = 54;   // beside h1[50] to h1[53]

/// The RBS spectrum, which is not one of TestEm7's
const G4int kStrataH1RBS = 80;

const G4int kStrataH1Count = 81;

const char* StrataH1TitleOf(G4int id);
G4bool StrataH1IsReal(G4int id);      // false for a slot that is never shown
StrataH1Axis StrataH1AxisOf(G4int id);
const char* StrataH1YLabelOf(G4int id);
StrataH1Norm StrataH1NormOf(G4int id);

/// The y-axis label with the x unit filled in.
///
/// A histogram normalised per unit width is divided by a bin width that
/// Geant4 reports in whatever unit the histogram was declared with, not in
/// its internal units, so the y unit follows the x unit: the same spectrum
/// booked in um and in mm carries y values a thousand apart.  The label
/// therefore cannot be a constant.  Needs the analysis manager, so it is
/// only meaningful once the histogram exists.
G4String StrataH1YLabel(G4int id);

/// Whether the x axis of one histogram is binned logarithmically.  Geant4
/// has no accessor for the binning function, but it puts it in front of the
/// axis annotation, which is its own record of what /analysis/h1/set asked
/// for.  Only meaningful once the histogram exists.
G4bool StrataH1IsLogX(G4int id);

/// What Geant4 calls the x unit of one histogram, e.g. "um".  Empty for a
/// dimensionless axis; a histogram booked without a unit reads as Geant4's
/// internal one, "mm" or "MeV".
G4String StrataH1XUnitSymbol(G4int id);

/// Leaves a copy of this thread's active spectra where a front end can read
/// them while the run goes on, no more often than every few hundred
/// milliseconds.  Called from the thread that fills them, between events;
/// aForce publishes whatever the interval, which is what the end of a run
/// wants.  See StrataResultStore::PublishH1 for why this is necessary at all
void StrataPublishLiveH1(G4bool aForce);

class HistoManager
{
public:
    HistoManager();
    ~HistoManager();

private:
    void Book();
    G4String fFileName;
};

//==============================================================================

#endif

