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
/// \file Strata/src/Run.cc
/// \brief Implementation of the Run class
//
// 
//==============================================================================
//==============================================================================

#include "Run.hh"
#include "DetectorConstruction.hh"
#include "PrimaryGeneratorAction.hh"
#include "HistoManager.hh"
#include "StrataResults.hh"

#include <cstring>
#include <vector>

#include "G4EmCalculator.hh"
#include "G4SystemOfUnits.hh"
#include "G4UnitsTable.hh"

//==============================================================================

Run::Run(DetectorConstruction* det)
        : G4Run(),
          fDetector(det),
          fParticle(nullptr), fEkin(0.),
          fVoxelEdep(new G4double[nMaxVoxel]) {
    fEnergyDeposit = fEnergyDeposit2 = 0.;
    fNIELEnergy = fNIELEnergy2 = 0.;
    fProjRange = fProjRange2 = 0.;
    fTrakLenCharged = fTrakLenCharged2 = 0.;
    fTrakLenNeutral = fTrakLenNeutral2 = 0.;
    fNbStepsCharged = fNbStepsCharged2 = 0.;
    fNbStepsNeutral = fNbStepsNeutral2 = 0.;
    fMscProjecTheta = fMscProjecTheta2 = 0.;
    fMscThetaCentral = 0.;

    fNbGamma = fNbElect = fNbPosit = 0;

    fNbPrimarySteps = fRange = 0;

    fTransmit[0] = fTransmit[1] = fReflect[0] = fReflect[1] = 0;

    fMscEntryCentral = 0;

    fEnergyLeak[0] = fEnergyLeak[1] = fEnergyLeak2[0] = fEnergyLeak2[1] = 0.;

    G4int voxelNumber = fDetector->GetVoxelNumber();
    if (voxelNumber > 0) {
        for (G4int j = 0; j < voxelNumber; j++) {
            fVoxelEdep[j] = 0.;
        }
    }
}

//==============================================================================

Run::~Run() {
    delete[] fVoxelEdep;
}

//==============================================================================

void Run::SetPrimary(G4ParticleDefinition* particle, G4double energy) {
    fParticle = particle;
    fEkin = energy;

    // Compute theta0
    fMscThetaCentral = 3*ComputeMscHighland();
}

//==============================================================================

void Run::Merge(const G4Run* run) {
    const Run* localRun = static_cast<const Run*>(run);

    // Pass information about primary particle
    fParticle = localRun->fParticle;
    fEkin = localRun->fEkin;

    fMscThetaCentral = localRun->fMscThetaCentral;

    // Accumulate sums
    fEnergyDeposit += localRun->fEnergyDeposit;
    fEnergyDeposit2 += localRun->fEnergyDeposit2;
    fNIELEnergy += localRun->fNIELEnergy;
    fNIELEnergy2 += localRun->fNIELEnergy2;
    fProjRange += localRun->fProjRange;
    fProjRange2 += localRun->fProjRange2;
    fTrakLenCharged += localRun->fTrakLenCharged;
    fTrakLenCharged2 += localRun->fTrakLenCharged2;
    fTrakLenNeutral += localRun->fTrakLenNeutral;
    fTrakLenNeutral2 += localRun->fTrakLenNeutral2;
    fNbStepsCharged += localRun->fNbStepsCharged;
    fNbStepsCharged2 += localRun->fNbStepsCharged2;
    fNbStepsNeutral += localRun->fNbStepsNeutral;
    fNbStepsNeutral2 += localRun->fNbStepsNeutral2;
    fMscProjecTheta += localRun->fMscProjecTheta;
    fMscProjecTheta2 += localRun->fMscProjecTheta2;


    fNbGamma += localRun->fNbGamma;
    fNbElect += localRun->fNbElect;
    fNbPosit += localRun->fNbPosit;

    fNbPrimarySteps += localRun->fNbPrimarySteps;
    fRange += localRun->fRange;

    fTransmit[0] += localRun->fTransmit[0];
    fTransmit[1] += localRun->fTransmit[1];
    fReflect[0] += localRun->fReflect[0];
    fReflect[1] += localRun->fReflect[1];

    fMscEntryCentral += localRun->fMscEntryCentral;

    fEnergyLeak[0] += localRun->fEnergyLeak[0];
    fEnergyLeak[1] += localRun->fEnergyLeak[1];
    fEnergyLeak2[0] += localRun->fEnergyLeak2[0];
    fEnergyLeak2[1] += localRun->fEnergyLeak2[1];

    G4int voxelNumber = fDetector->GetVoxelNumber();
    if (voxelNumber > 0) {
        for (G4int j = 0; j < voxelNumber; j++) {
            fVoxelEdep[j] += localRun->fVoxelEdep[j];
        }
    }

    G4Run::Merge(run);
}

//==============================================================================

void Run::EndOfRun() {
    // Compute mean and rms
    G4int TotNbofEvents = numberOfEvent;
    if (TotNbofEvents == 0) return;

    G4double EnergyBalance = fEnergyDeposit + fEnergyLeak[0] + fEnergyLeak[1];
    EnergyBalance /= TotNbofEvents;

    // Compute energy deposition and niel
    fEnergyDeposit /= TotNbofEvents;
    fEnergyDeposit2 /= TotNbofEvents;
    G4double rmsEdep = fEnergyDeposit2 - fEnergyDeposit*fEnergyDeposit;
    if (rmsEdep > 0.) rmsEdep = std::sqrt(rmsEdep/TotNbofEvents);
    else rmsEdep = 0.;

    fNIELEnergy /= TotNbofEvents;
    fNIELEnergy2 /= TotNbofEvents;
    G4double rmsEniel = fNIELEnergy2 - fNIELEnergy*fNIELEnergy;
    if (rmsEniel > 0.) rmsEniel = std::sqrt(rmsEniel/TotNbofEvents);
    else rmsEniel = 0.;

    // Compute projected range and straggling
    G4double nstep = G4double(fNbPrimarySteps)/G4double(TotNbofEvents);

    if (fRange > 0) {
        fProjRange /= fRange;
        fProjRange2 /= fRange;
    }
    G4double rmsProjRng = fProjRange2 - fProjRange*fProjRange;
    if (rmsProjRng > 0.) rmsProjRng = std::sqrt(rmsProjRng);
    else rmsProjRng = 0.;

    fTrakLenCharged /= TotNbofEvents;
    fTrakLenCharged2 /= TotNbofEvents;
    G4double rmsTLCh = fTrakLenCharged2 - fTrakLenCharged*fTrakLenCharged;
    if (rmsTLCh > 0.) rmsTLCh = std::sqrt(rmsTLCh/TotNbofEvents);
    else rmsTLCh = 0.;

    fTrakLenNeutral /= TotNbofEvents;
    fTrakLenNeutral2 /= TotNbofEvents;
    G4double rmsTLNe = fTrakLenNeutral2 - fTrakLenNeutral*fTrakLenNeutral;
    if (rmsTLNe > 0.) rmsTLNe = std::sqrt(rmsTLNe/TotNbofEvents);
    else rmsTLNe = 0.;

    fNbStepsCharged /= TotNbofEvents;
    fNbStepsCharged2 /= TotNbofEvents;
    G4double rmsStCh = fNbStepsCharged2 - fNbStepsCharged*fNbStepsCharged;
    if (rmsStCh > 0.) rmsStCh = std::sqrt(rmsStCh/TotNbofEvents);
    else rmsStCh = 0.;

    fNbStepsNeutral /= TotNbofEvents;
    fNbStepsNeutral2 /= TotNbofEvents;
    G4double rmsStNe = fNbStepsNeutral2 - fNbStepsNeutral*fNbStepsNeutral;
    if (rmsStNe > 0.) rmsStNe = std::sqrt(rmsStNe/TotNbofEvents);
    else rmsStNe = 0.;

    G4double Gamma = (G4double) fNbGamma/TotNbofEvents;
    G4double Elect = (G4double) fNbElect/TotNbofEvents;
    G4double Posit = (G4double) fNbPosit/TotNbofEvents;

    G4double transmit[2];
    transmit[0] = 100.*fTransmit[0]/TotNbofEvents;
    transmit[1] = 100.*fTransmit[1]/TotNbofEvents;

    G4double reflect[2];
    reflect[0] = 100.*fReflect[0]/TotNbofEvents;
    reflect[1] = 100.*fReflect[1]/TotNbofEvents;

    G4double rmsMsc = 0., tailMsc = 0.;
    if (fMscEntryCentral > 0) {
        fMscProjecTheta /= fMscEntryCentral;
        fMscProjecTheta2 /= fMscEntryCentral;
        rmsMsc = fMscProjecTheta2 - fMscProjecTheta*fMscProjecTheta;
        if (rmsMsc > 0.) { rmsMsc = std::sqrt(rmsMsc); }
        if (fTransmit[1] > 0.0) {
            tailMsc = 100. - (100.*fMscEntryCentral)/(2*fTransmit[1]);
        }
    }

    fEnergyLeak[0] /= TotNbofEvents;
    fEnergyLeak2[0] /= TotNbofEvents;
    G4double rmsEl0 = fEnergyLeak2[0] - fEnergyLeak[0]*fEnergyLeak[0];
    if (rmsEl0 > 0.) rmsEl0 = std::sqrt(rmsEl0/TotNbofEvents);
    else rmsEl0 = 0.;

    fEnergyLeak[1] /= TotNbofEvents;
    fEnergyLeak2[1] /= TotNbofEvents;
    G4double rmsEl1 = fEnergyLeak2[1] - fEnergyLeak[1]*fEnergyLeak[1];
    if (rmsEl1 > 0.) rmsEl1 = std::sqrt(rmsEl1/TotNbofEvents);
    else rmsEl1 = 0.;

    //Stopping Power from input Table.
    const G4Material* material;
    G4double length = fDetector->GetMultiLayerSizeX();
    G4double density, mean_density = 0.;
    G4String partName = fParticle->GetParticleName();
    G4EmCalculator emCalculator;
    G4double dEdxTable = 0., dEdxFull = 0.;
    G4double stopTable, stopFull;
    G4double meandEdx, stopPower;

    G4cout << "\n ======================== run summary ======================\n";

    G4int prec = G4cout.precision(3);

    G4cout << "\n The run consists of " << TotNbofEvents << " " << partName << " of "
           << G4BestUnit(fEkin, "Energy") << " through "
           << G4BestUnit(length, "Length") << " of "
           << fDetector->GetLayerNumber() << " layer(s) : " << G4endl;

    for (G4int i = 0; i < fDetector->GetLayerNumber(); i++) {
        material = fDetector->GetLayerMaterial(i);
        density = material->GetDensity();
        mean_density += density;

        if (fParticle->GetPDGCharge() != 0.) {
            dEdxTable += emCalculator.GetDEDX(fEkin, fParticle, material);
            dEdxFull += emCalculator.ComputeTotalDEDX(fEkin, fParticle, material);
        }

        G4cout << "---> Layer " << i + 1 << " is "
               << G4BestUnit(fDetector->GetLayerThickness(i), "Length")
               << " of " << material->GetName() << " (density: "
               << G4BestUnit(density, "Volumic Mass") << ")" << G4endl;
    }

    stopTable = dEdxTable/mean_density;
    stopFull = dEdxFull/mean_density;

    // Stopping Power from simulation
    meandEdx = fEnergyDeposit/length;
    stopPower = meandEdx*fDetector->GetLayerNumber()/mean_density;

    G4cout.precision(4);

    G4cout << "\n Projected Range = "
           << G4BestUnit(fProjRange, "Length") << " +- "
           << G4BestUnit(rmsProjRng, "Length") << G4endl;
    G4cout << " Mean number of primary steps = " << nstep << G4endl;

    G4cout << "\n Total energy deposited per event = "
           << G4BestUnit(fEnergyDeposit, "Energy") << " +- "
           << G4BestUnit(rmsEdep, "Energy") << G4endl;

    G4cout << "\n NIEL energy deposited per event = "
           << G4BestUnit(fNIELEnergy, "Energy") << " +- "
           << G4BestUnit(rmsEniel, "Energy") << G4endl;

    G4cout << "\n -----> Mean dE/dx = " << meandEdx/(MeV/cm) << " MeV/cm"
           << "\t(" << stopPower/(MeV*cm2/g) << " MeV*cm2/g)" << G4endl;

    G4cout << "\n From formulas :" << G4endl;
    G4cout << "   restricted dEdx = " << dEdxTable/(MeV/cm) << " MeV/cm"
           << "\t(" << stopTable/(MeV*cm2/g) << " MeV*cm2/g)" << G4endl;

    G4cout << "   full dEdx       = " << dEdxFull/(MeV/cm) << " MeV/cm"
           << "\t(" << stopFull/(MeV*cm2/g) << " MeV*cm2/g)" << G4endl;

    G4cout << "\n Leakage :  primary = "
           << G4BestUnit(fEnergyLeak[0], "Energy") << " +- "
           << G4BestUnit(rmsEl0, "Energy")
           << "   secondaries = "
           << G4BestUnit(fEnergyLeak[1], "Energy") << " +- "
           << G4BestUnit(rmsEl1, "Energy") << G4endl;

    G4cout << " Energy balance :  edep + eleak = "
           << G4BestUnit(EnergyBalance, "Energy") << G4endl;

    G4cout << "\n Total track length (charged) per event = "
           << G4BestUnit(fTrakLenCharged, "Length") << " +- "
           << G4BestUnit(rmsTLCh, "Length") << G4endl;

    G4cout << " Total track length (neutral) per event = "
           << G4BestUnit(fTrakLenNeutral, "Length") << " +- "
           << G4BestUnit(rmsTLNe, "Length") << G4endl;

    G4cout << "\n Number of steps (charged) per event = "
           << fNbStepsCharged << " +- " << rmsStCh << G4endl;

    G4cout << " Number of steps (neutral) per event = "
           << fNbStepsNeutral << " +- " << rmsStNe << G4endl;

    G4cout << "\n Number of secondaries per event : Gammas = " << Gamma
           << ";   electrons = " << Elect
           << ";   positrons = " << Posit << G4endl;

    G4cout << "\n Number of events with the primary particle transmitted = "
           << transmit[1] << " %" << G4endl;

    G4cout << " Number of events with at least  1 particle transmitted "
           << "(same charge as primary) = " << transmit[0] << " %" << G4endl;

    G4cout << "\n Number of events with the primary particle reflected = "
           << reflect[1] << " %" << G4endl;

    G4cout << " Number of events with at least  1 particle reflected "
           << "(same charge as primary) = " << reflect[0] << " %" << G4endl;

    // compute width of the Gaussian central part of the MultipleScattering
    //
    G4cout << "\n MultipleScattering:"
           << "\n  rms projected angle of transmit primary particle = "
           << rmsMsc/mrad << " mrad (central part only)" << G4endl;

    G4cout << "  computed theta0 (Highland formula)          = "
           << ComputeMscHighland()/mrad << " mrad" << G4endl;

    G4cout << "  central part defined as +- "
           << fMscThetaCentral/mrad << " mrad; "
           << "  Tail ratio = " << tailMsc << " %" << G4endl;

    // Print dose in voxels
    G4int voxelNumber = fDetector->GetVoxelNumber();
    std::vector<StrataVoxelResult> voxelResults;
    if (voxelNumber > 0) voxelResults.reserve(voxelNumber);
    if (voxelNumber > 0) {
        G4cout << "\n----------------------------------------------------------------------\n";
        G4cout << " Cumulated Doses : \tEdep      \tEdep/Ebeam \tDose" << G4endl;
        for (G4int j = 0; j < voxelNumber; j++) {
            G4double Edep = fVoxelEdep[j], ratio = 100*Edep/fEnergyDeposit/TotNbofEvents;
            G4double voxelMass = fDetector->GetVoxelMass(j);
            G4double Dose = Edep/voxelMass;

            voxelResults.push_back(StrataVoxelResult{Edep, ratio, Dose/gray, voxelMass/gram});

            G4cout << " voxel " << j << ": \t \t"
                   << G4BestUnit(Edep, "Energy") << "\t"
                   << ratio << " % \t"
                   << G4BestUnit(Dose, "Dose") << G4endl;
        }
        G4cout << "\n----------------------------------------------------------------------\n";
        G4cout << G4endl;
    }

    // Normalize histograms
    G4AnalysisManager* analysisManager = G4AnalysisManager::Instance();

    for (G4int ih = 0; ih < kStrataH1Count; ih++) {
        switch (StrataH1NormOf(ih)) {
            case kH1PerEvent:
                analysisManager->ScaleH1(ih, 1./TotNbofEvents);
                break;
            case kH1PerEventPerWidth:
                analysisManager->ScaleH1(
                    ih, 1./(TotNbofEvents*analysisManager->GetH1Width(ih)));
                break;
            case kH1Raw:
                break;
        }
    }

    // Publish the same numbers in machine-readable form, so that a GUI can read them back
    StrataRunStats stats{};
    stats.valid = 1;
    stats.events = TotNbofEvents;
    std::strncpy(stats.particle, partName.c_str(), sizeof(stats.particle) - 1);
    stats.beamEnergy = fEkin;
    stats.targetThickness = length;
    stats.layers = fDetector->GetLayerNumber();
    stats.meanDensity = mean_density/(g/cm3);

    stats.edep = fEnergyDeposit;          stats.edepRms = rmsEdep;
    stats.niel = fNIELEnergy;             stats.nielRms = rmsEniel;
    stats.energyBalance = EnergyBalance;

    stats.projRange = fProjRange;         stats.projRangeRms = rmsProjRng;
    stats.meanPrimarySteps = nstep;

    stats.trakLenCharged = fTrakLenCharged;  stats.trakLenChargedRms = rmsTLCh;
    stats.trakLenNeutral = fTrakLenNeutral;  stats.trakLenNeutralRms = rmsTLNe;
    stats.stepsCharged = fNbStepsCharged;    stats.stepsChargedRms = rmsStCh;
    stats.stepsNeutral = fNbStepsNeutral;    stats.stepsNeutralRms = rmsStNe;

    stats.gammaPerEvent = Gamma;
    stats.electronPerEvent = Elect;
    stats.positronPerEvent = Posit;

    stats.transmitPrimary = transmit[1];  stats.transmitAny = transmit[0];
    stats.reflectPrimary = reflect[1];    stats.reflectAny = reflect[0];

    stats.leakPrimary = fEnergyLeak[0];   stats.leakPrimaryRms = rmsEl0;
    stats.leakSecondary = fEnergyLeak[1]; stats.leakSecondaryRms = rmsEl1;

    stats.meanDEdx = meandEdx;
    stats.stoppingPower = stopPower/(MeV*cm2/g);
    stats.dedxRestricted = dEdxTable;
    stats.dedxFull = dEdxFull;
    stats.stopPowerRestricted = stopTable/(MeV*cm2/g);
    stats.stopPowerFull = stopFull/(MeV*cm2/g);

    stats.mscRms = rmsMsc;
    stats.mscHighland = ComputeMscHighland();
    stats.mscThetaCentral = fMscThetaCentral;
    stats.mscTailRatio = tailMsc;

    StrataResultStore::Instance().Publish(stats, voxelResults);

    // Reset default precision
    G4cout.precision(prec);
}

//==============================================================================

G4double Run::ComputeMscHighland() {
    //compute the width of the Gaussian central part of the MultipleScattering
    //projected angular distribution.
    //Eur. Phys. Jour. C15 (2000) page 166, formule 23.9

    G4double t = (fDetector->GetMultiLayerSizeX())
                 /(fDetector->GetLayerMaterial(0)->GetRadlen());
    if (t < DBL_MIN) return 0.;

    G4double T = fEkin;
    G4double M = fParticle->GetPDGMass();
    G4double z = std::abs(fParticle->GetPDGCharge()/eplus);

    G4double bpc = T*(T + 2*M)/(T + M);
    G4double teta0 = 13.6*MeV*z*std::sqrt(t)*(1. + 0.038*std::log(t))/bpc;
    return teta0;
}

//==============================================================================
