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
/// \file Strata/src/PhysicsList.cc
/// \brief Implementation of the PhysicsList class
//
//
//==============================================================================
//==============================================================================

#include "PhysicsList.hh"
#include "PhysicsListMessenger.hh"
#include "SRIMMessenger.hh"

#include "PhysListEmStandard.hh"
#include "PhysListEmStandardNR.hh"
#include "PhysListEmStandardSRIM.hh"
#include "G4EmStandardPhysics.hh"
#include "PhysListEm5DStandard.hh"
#include "PhysListEm19DStandard.hh"

#include "G4EmStandardPhysics_option1.hh"
#include "G4EmStandardPhysics_option2.hh"
#include "G4EmStandardPhysics_option3.hh"
#include "G4EmStandardPhysics_option4.hh"
#include "G4EmStandardPhysicsWVI.hh"
#include "G4EmStandardPhysicsGS.hh"
#include "G4EmStandardPhysicsSS.hh"

#include "G4EmLivermorePhysics.hh"
#include "G4EmPenelopePhysics.hh"
#include "G4EmLowEPPhysics.hh"

#include "G4EmDNAPhysics.hh"
#include "G4EmDNAPhysics_option2.hh"
#include "G4EmDNAPhysics_option4.hh"
#include "G4EmDNAPhysics_option6.hh"

#include "G4DecayPhysics.hh"

#include "G4HadronElasticPhysics.hh"
#include "G4HadronElasticPhysicsHP.hh"
#include "G4HadronElasticPhysicsHPT.hh"
#include "G4EnvironmentUtils.hh"

#include <filesystem>
#include "G4HadronDElasticPhysics.hh"
#include "G4HadronHElasticPhysics.hh"
#include "G4HadronInelasticQBBC.hh"
#include "G4IonPhysics.hh"
#include "G4EmExtraPhysics.hh"
#include "G4StoppingPhysics.hh"

#include "G4RadioactiveDecayPhysics.hh"
#include "G4IonBinaryCascadePhysics.hh"
#include "G4HadronPhysicsQGSP_BIC.hh"
#include "G4HadronPhysicsQGSP_BIC_HP.hh"
#include "G4NeutronTrackingCut.hh"

#include "G4LossTableManager.hh"
#include "G4EmConfigurator.hh"
#include "G4UnitsTable.hh"

#include "G4ProcessManager.hh"

#include "StepMax.hh"

#include "G4IonFluctuations.hh"
#include "G4IonParametrisedLossModel.hh"
#include "G4UniversalFluctuation.hh"

#include "G4BraggIonGasModel.hh"
#include "G4BetheBlochIonGasModel.hh"

#include "G4PhysicalConstants.hh"
#include "G4SystemOfUnits.hh"

//==============================================================================

PhysicsList::PhysicsList() :
        G4VModularPhysicsList(),
        fStepMaxProcess(nullptr),
        fDefaultCutValue(1.0*nm) // set default cut value
{
    // Set cut value
    SetDefaultCutValue(fDefaultCutValue);

    fRadDecIsRegistered = false;
    fIBCIsRegistered = false;
    fExPhyIsRegistered = false;
    fHelIsRegistered = false;
    fBicIsRegistered = false;
    fBiciIsRegistered = false;
    fGnucIsRegistered = false;
    fStopIsRegistered = false;
    fQGSIsRegistered = false;
    fNTCIsRegistered = false;

    // protected member of the base class
    verboseLevel = 1;

    fMessenger = new PhysicsListMessenger(this);
    fSRIMMessenger = new SRIMMessenger();

    // EM physics
    fEmName = G4String("standard_opt0");
    fEmPhysicsList = new G4EmStandardPhysics(verboseLevel);

    // Decay physics and all particles
    fDecPhysicsList = new G4DecayPhysics(verboseLevel);
}

//==============================================================================

PhysicsList::~PhysicsList() {
    delete fMessenger;
    delete fSRIMMessenger;
    delete fEmPhysicsList;
    delete fDecPhysicsList;
    for (auto& fHadronPhy : fHadronPhys) { delete fHadronPhy; }
}

//==============================================================================

void PhysicsList::ConstructParticle() {
    fDecPhysicsList->ConstructParticle();
}

//==============================================================================

void PhysicsList::ConstructProcess() {
    // Transportation
    AddTransportation();

    // Electromagnetic physics list
    fEmPhysicsList->ConstructProcess();

    // Decay physics list
    fDecPhysicsList->ConstructProcess();

    // Hadronic physics lists
    for (auto& fHadronPhy : fHadronPhys) {
        fHadronPhy->ConstructProcess();
    }

    // Step limitation (as a full process)
    AddStepMax();
}

//==============================================================================

namespace {

// The _hp lists read evaluated neutron data as they run.  Without it Geant4
// stops in the middle of building the tables, naming a file it could not
// open and nothing else, which tells a user neither which dataset is
// missing nor where to get it.  G4NDL is 1.1 GB and so is not one of the
// seven the installers select by default, which makes this the ordinary way
// to meet an _hp list rather than a rare one.
//
// ASub is a subdirectory that has to be there as well, empty for none
G4bool NeutronDataPresent(const G4String& list, const G4String& sub = "") {
    // G4FindDataDir, not getenv: Strata points Geant4 at one directory with
    // GEANT4_DATA_DIR and leaves the per-dataset variables unset, so the
    // environment is empty even when the data is there.  This is the
    // resolver Geant4 itself uses
    const char* dir = G4FindDataDir("G4NEUTRONHPDATA");
    if (dir != nullptr && *dir != '\0') {
        std::string path = dir;
        if (!sub.empty()) path += "/" + sub;
        if (std::filesystem::is_directory(path)) return true;
    }

    // G4cerr, so that a front end reading the log can tell this apart from
    // the running commentary and show it as the error it is
    G4cerr << "PhysicsList::AddPhysicsList: <" << list << "> needs the "
           << "evaluated neutron data" << (sub.empty() ? "" : " and its " + sub
                                           + " tables")
           << ", which G4NEUTRONHPDATA does not point at. The list has not "
           << "been added. Install G4NDL (<geant4-prefix>/share/Geant4/"
           << "fetch-datasets.sh --one G4NDL) and start again."
           << G4endl;
    return false;
}

}  // namespace

void PhysicsList::AddPhysicsList(const G4String& name) {
    if (verboseLevel > 1) {
        G4cout << "PhysicsList::AddPhysicsList: <" << name << ">" << G4endl;
    }

    if (name == fEmName) return;

    if (name == "local") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new PhysListEmStandard(name);

    } else if (name == "standardSS") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysicsSS(verboseLevel);

    } else if (name == "standardNR") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new PhysListEmStandardNR(name);

    } else if (name == "srim") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new PhysListEmStandardSRIM(name);

    } else if (name == "standard_opt0") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysics(verboseLevel);

    } else if (name == "standard_opt1") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysics_option1(verboseLevel);

    } else if (name == "standard_opt2") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysics_option2(verboseLevel);

    } else if (name == "standard_opt3") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysics_option3(verboseLevel);

    } else if (name == "standard_opt4") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysics_option4(verboseLevel);

    } else if (name == "standardATIMA") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new PhysListEm19DStandard();

    } else if (name == "ionGasModels") {

        AddPhysicsList("standard_opt0");
        fEmName = name;
        AddIonGasModels();

    } else if (name == "standardWVI") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysicsWVI(verboseLevel);

    } else if (name == "standardGS") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmStandardPhysicsGS(verboseLevel);

    } else if (name == "standard5D") {

        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new PhysListEm5DStandard();

    } else if (name == "livermore") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmLivermorePhysics(verboseLevel);

    } else if (name == "penelope") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmPenelopePhysics(verboseLevel);

    } else if (name == "lowenergy") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmLowEPPhysics(verboseLevel);

    } else if (name == "dna") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmDNAPhysics();

    } else if (name == "dna_opt2") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmDNAPhysics_option2();

    } else if (name == "dna_opt4") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmDNAPhysics_option4();

    } else if (name == "dna_opt6") {
        fEmName = name;
        delete fEmPhysicsList;
        fEmPhysicsList = new G4EmDNAPhysics_option6();

        ////////////////////////////////////////
        //   ELECTROMAGNETIC + HADRONIC MODELS
        ////////////////////////////////////////

    } else if (name == "hadron_therapy") {
        // HP models are switched off
        AddPhysicsList("standard_opt4");
        AddPhysicsList("rad_decay");
        AddPhysicsList("binary_cascade");
        AddPhysicsList("extra_physics");
        AddPhysicsList("elastic");
        AddPhysicsList("stopping");
        AddPhysicsList("qgsp_bic");
        AddPhysicsList("neutron_tracking");

        G4cout << "Hadron therapy physics list has been activated" << G4endl;

    }  else if (name == "hadron_therapy_hp") {

        AddPhysicsList("standard_opt4");
        AddPhysicsList("rad_decay");
        AddPhysicsList("binary_cascade");
        AddPhysicsList("extra_physics");
        AddPhysicsList("elastic_hp");
        AddPhysicsList("stopping");
        AddPhysicsList("qgsp_bic_hp");
        AddPhysicsList("neutron_tracking");

        G4cout << "Hadron therapy (HP) physics list has been activated" << G4endl;

    // Everything a neutron needs, in one name.  An EM list for the charged
    // secondaries, elastic scattering with the bound-nucleus kernel so that
    // thermalisation is right, HP inelastic and capture, and the decay of
    // whatever the captures activate.
    //
    // neutron_tracking is deliberately not here.  It is a cut that stops
    // following neutrons below an energy and after a time, which is what
    // hadron therapy wants and the opposite of what a moderator study
    // wants: the thermal neutrons it discards are the answer
    } else if (name == "neutron_hp") {

        AddPhysicsList("standard_opt4");
        AddPhysicsList("elastic_hpt");
        AddPhysicsList("qgsp_bic_hp");
        AddPhysicsList("stopping");
        AddPhysicsList("rad_decay");

        G4cout << "Neutron (HP, with thermal scattering) physics list has been "
               << "activated" << G4endl;

    } else if (name == "rad_decay" && !fRadDecIsRegistered) {
        fHadronPhys.push_back(new G4RadioactiveDecayPhysics(verboseLevel));
        fRadDecIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add hadron radioactive decay physics" << G4endl;

    } else if (name == "binary_cascade" && !fIBCIsRegistered) {
        fHadronPhys.push_back(new G4IonBinaryCascadePhysics(verboseLevel));
        fIBCIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add ion binary cascade physics" << G4endl;

    } else if (name == "extra_physics" && (fExPhyIsRegistered || fGnucIsRegistered)) {
        G4cout << "PhysicsList::AddPhysicsList: G4EmExtraPhysics is already "
               << "registered, <extra_physics> is ignored" << G4endl;

    } else if (name == "extra_physics") {
        fHadronPhys.push_back(new G4EmExtraPhysics(verboseLevel));
        fExPhyIsRegistered = true;
        fGnucIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add EM extra physics" << G4endl;

    // Geant4 takes one hadron-elastic constructor, so the four variants
    // below share a flag
    } else if ((name == "elastic" || name == "elastic_hp"
             || name == "DElastic" || name == "HElastic") && fHelIsRegistered) {
        G4cout << "PhysicsList::AddPhysicsList: hadron elastic physics is "
               << "already registered, <" << name << "> is ignored; only one "
               << "elastic constructor can be used at a time" << G4endl;

    } else if (name == "elastic" && !fHelIsRegistered) {
        fHadronPhys.push_back(new G4HadronElasticPhysics(verboseLevel));
        fHelIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add hadron elastic physics (Chips Elastic Model)" << G4endl;

    } else if (name == "elastic_hp" && !fHelIsRegistered) {
        if (NeutronDataPresent(name)) {
            fHadronPhys.push_back(new G4HadronElasticPhysicsHP(verboseLevel));
            fHelIsRegistered = true;
            if (verboseLevel > 0)
                G4cout << "PhysicsList::Add hadron elastic physics (High Precision)" << G4endl;
        }

    // Elastic scattering off nuclei that are bound in a lattice or a
    // molecule rather than standing still and free.  Below a few eV that is
    // the whole of the physics: the neutron has less energy than the
    // chemical bonds, so it scatters off the solid and can gain energy from
    // it as easily as lose it, and a free-gas kernel is simply the wrong
    // calculation.  Anything that thermalises neutrons -- a moderator, a
    // shield, a room -- needs this list and not elastic_hp
    } else if (name == "elastic_hpt" && !fHelIsRegistered) {
        if (NeutronDataPresent(name, "ThermalScattering")) {
            fHadronPhys.push_back(new G4HadronElasticPhysicsHPT(verboseLevel));
            fHelIsRegistered = true;
            if (verboseLevel > 0)
                G4cout << "PhysicsList::Add hadron elastic physics "
                       << "(High Precision, with thermal scattering)" << G4endl;
        }

    } else if (name == "DElastic" && !fHelIsRegistered) {
        fHadronPhys.push_back(new G4HadronDElasticPhysics(verboseLevel));
        fHelIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add hadron elastic physics (Hadron Elastic Diffuse Model)" << G4endl;

    } else if (name == "HElastic" && !fHelIsRegistered) {
        fHadronPhys.push_back(new G4HadronHElasticPhysics(verboseLevel));
        fHelIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add hadron elastic physics (Glauber Hadron Elastic Model)" << G4endl;

    } else if (name == "binary" && !fBicIsRegistered) {
        fHadronPhys.push_back(new G4HadronInelasticQBBC(verboseLevel));
        fBicIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add hadron inelastic physics from <QBBC>"
                   << G4endl;

    } else if (name == "binary_ion" && !fBiciIsRegistered) {
        fHadronPhys.push_back(new G4IonPhysics(verboseLevel));
        fBiciIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add binary ion inelastic physics model"
                   << G4endl;

    // G4EmExtraPhysics is what gamma- and electro-nuclear physics lives in,
    // so this is the same constructor extra_physics registers
    } else if (name == "gamma_nuc" && (fGnucIsRegistered || fExPhyIsRegistered)) {
        G4cout << "PhysicsList::AddPhysicsList: <gamma_nuc> is part of "
               << "G4EmExtraPhysics, which is already registered" << G4endl;

    } else if (name == "gamma_nuc") {
        fHadronPhys.push_back(new G4EmExtraPhysics());
        fGnucIsRegistered = true;
        fExPhyIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add gamma- and electro-nuclear physics"
                   << G4endl;

    } else if (name == "stopping" && !fStopIsRegistered) {
        fHadronPhys.push_back(new G4StoppingPhysics());
        fStopIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add stopping physics" << G4endl;

    } else if (name == "qgsp_bic" && !fQGSIsRegistered) {
        fHadronPhys.push_back(new G4HadronPhysicsQGSP_BIC());
        fQGSIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add Quark-Gluon-String model + Binary" << G4endl;

    } else if (name == "qgsp_bic_hp" && !fQGSIsRegistered) {
        if (NeutronDataPresent(name)) {
            fHadronPhys.push_back(new G4HadronPhysicsQGSP_BIC_HP());
            fQGSIsRegistered = true;
            if (verboseLevel > 0)
                G4cout << "PhysicsList::Add Quark-Gluon-String model + Binary (High Precision)" << G4endl;
        }

    } else if (name == "neutron_tracking" && !fQGSIsRegistered) {
        fHadronPhys.push_back(new G4NeutronTrackingCut());
        fQGSIsRegistered = true;
        if (verboseLevel > 0)
            G4cout << "PhysicsList::Add Neutron tracking physics" << G4endl;

    } else {

        G4cout << "PhysicsList::AddPhysicsList: <" << name << ">"
               << " is not defined"
               << G4endl;
    }
}

//==============================================================================

void PhysicsList::AddStepMax() {
    // Step limitation seen as a process
    fStepMaxProcess = new StepMax();

    auto particleIterator = GetParticleIterator();
    particleIterator->reset();
    while ((*particleIterator)()) {
        G4ParticleDefinition* particle = particleIterator->value();
        G4ProcessManager* pmanager = particle->GetProcessManager();

        if (fStepMaxProcess->IsApplicable(*particle) && pmanager) {
            pmanager->AddDiscreteProcess(fStepMaxProcess);
        }
    }
}

//==============================================================================

void PhysicsList::AddIonGasModels() {
    G4EmConfigurator* em_config = G4LossTableManager::Instance()->EmConfigurator();
    auto particleIterator = GetParticleIterator();
    particleIterator->reset();
    while ((*particleIterator)()) {
        G4ParticleDefinition* particle = particleIterator->value();
        G4String partname = particle->GetParticleName();
        if (partname == "alpha" || partname == "He3" || partname == "GenericIon") {
            auto* mod1 = new G4BraggIonGasModel();
            auto* mod2 = new G4BetheBlochIonGasModel();
            G4double eth = 2.*MeV*particle->GetPDGMass()/proton_mass_c2;
            em_config->SetExtraEmModel(partname, "ionIoni", mod1, "", 0.0, eth,
                                       new G4IonFluctuations());
            em_config->SetExtraEmModel(partname, "ionIoni", mod2, "", eth, 100*TeV,
                                       new G4UniversalFluctuation());

        }
    }
}

//==============================================================================

