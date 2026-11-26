//==============================================================================
/// \file Strata/src/PhysListEmStandardSRIM.cc
/// \brief Implementation of the PhysListEmStandardSRIM class
//==============================================================================

#include "PhysListEmStandardSRIM.hh"

#include "SRIMIonisationModel.hh"
#include "SRIMStoppingData.hh"

#include "G4ScreenedNuclearRecoil.hh"

#include "G4ComptonScattering.hh"
#include "G4CoulombScattering.hh"
#include "G4GammaConversion.hh"
#include "G4PhotoElectricEffect.hh"
#include "G4RayleighScattering.hh"

#include "G4KleinNishinaModel.hh"
#include "G4LivermorePhotoElectricModel.hh"
#include "G4PenelopeGammaConversionModel.hh"

#include "G4eBremsstrahlung.hh"
#include "G4eIonisation.hh"
#include "G4eMultipleScattering.hh"
#include "G4eplusAnnihilation.hh"

#include "G4MuBremsstrahlung.hh"
#include "G4MuIonisation.hh"
#include "G4MuMultipleScattering.hh"
#include "G4MuPairProduction.hh"

#include "G4eCoulombScatteringModel.hh"
#include "G4hIonisation.hh"
#include "G4hMultipleScattering.hh"
#include "G4ionIonisation.hh"
#include "G4UrbanMscModel.hh"

#include "G4BuilderType.hh"
#include "G4EmParameters.hh"
#include "G4PhysicsListHelper.hh"
#include "G4SystemOfUnits.hh"
#include "G4Threading.hh"

//==============================================================================

G4double PhysListEmStandardSRIM::fScatteringLimit = 100.*MeV;

//==============================================================================

PhysListEmStandardSRIM::PhysListEmStandardSRIM(const G4String& name)
        : G4VPhysicsConstructor(name) {
    G4EmParameters* param = G4EmParameters::Instance();
    param->SetDefaults();

    // The same step functions standardNR uses
    param->SetStepFunction(0.2, 100*um);
    param->SetStepFunctionMuHad(0.2, 50*um);
    param->SetStepFunctionLightIons(0.1, 10*um);
    param->SetStepFunctionIons(0.1, 1*um);
    param->SetFluo(true);

    SetPhysicsType(bElectromagnetic);
}

//==============================================================================

PhysListEmStandardSRIM::~PhysListEmStandardSRIM() = default;

//==============================================================================

void PhysListEmStandardSRIM::ConstructParticle() {}

//==============================================================================

void PhysListEmStandardSRIM::ConstructProcess() {
    G4PhysicsListHelper* ph = G4PhysicsListHelper::GetPhysicsListHelper();

    G4MuBremsstrahlung* mub = new G4MuBremsstrahlung();
    G4MuPairProduction* mup = new G4MuPairProduction();

    // Screened Coulomb scattering off nuclei, with the ZBL universal
    // screening function stated explicitly
    G4ScreenedNuclearRecoil* nucr =
        new G4ScreenedNuclearRecoil("ScreenedElastic", "zbl");
    nucr->SetMaxEnergyForScattering(fScatteringLimit);

    G4eCoulombScatteringModel* csm = new G4eCoulombScatteringModel();
    csm->SetActivationLowEnergyLimit(fScatteringLimit);

    auto particleIterator = GetParticleIterator();
    particleIterator->reset();
    while ((*particleIterator)()) {
        G4ParticleDefinition* particle = particleIterator->value();
        const G4String particleName = particle->GetParticleName();

        if (particleName == "gamma") {

            G4ComptonScattering* cs = new G4ComptonScattering();
            cs->SetEmModel(new G4KleinNishinaModel());
            ph->RegisterProcess(cs, particle);

            G4PhotoElectricEffect* pe = new G4PhotoElectricEffect();
            G4VEmModel* peModel = new G4LivermorePhotoElectricModel();
            peModel->SetHighEnergyLimit(10*GeV);
            pe->SetEmModel(peModel);
            ph->RegisterProcess(pe, particle);

            G4GammaConversion* gc = new G4GammaConversion();
            G4VEmModel* gcModel = new G4PenelopeGammaConversionModel();
            gcModel->SetHighEnergyLimit(1*GeV);
            gc->SetEmModel(gcModel);
            ph->RegisterProcess(gc, particle);

            ph->RegisterProcess(new G4RayleighScattering(), particle);

        } else if (particleName == "e-" || particleName == "e+") {

            ph->RegisterProcess(new G4eMultipleScattering(), particle);
            ph->RegisterProcess(new G4eIonisation(), particle);
            ph->RegisterProcess(new G4eBremsstrahlung(), particle);
            if (particleName == "e+")
                ph->RegisterProcess(new G4eplusAnnihilation(), particle);

        } else if (particleName == "mu+" || particleName == "mu-") {

            ph->RegisterProcess(new G4MuIonisation(), particle);
            ph->RegisterProcess(mub, particle);
            ph->RegisterProcess(mup, particle);
            ph->RegisterProcess(new G4CoulombScattering(), particle);

        } else if (particleName == "alpha" || particleName == "He3"
                   || particleName == "GenericIon") {

            G4hMultipleScattering* msc = new G4hMultipleScattering();
            G4UrbanMscModel* model = new G4UrbanMscModel();
            model->SetActivationLowEnergyLimit(fScatteringLimit);
            msc->SetEmModel(model);
            ph->RegisterProcess(msc, particle);

            // Two models, low energy first
            G4ionIonisation* ionIoni = new G4ionIonisation();
            ionIoni->SetEmModel(new SRIMBraggIonModel());
            ionIoni->SetEmModel(new SRIMBetheBlochModel());
            ph->RegisterProcess(ionIoni, particle);

            ph->RegisterProcess(nucr, particle);

        } else if (particleName == "proton" || particleName == "deuteron"
                   || particleName == "triton") {

            G4hMultipleScattering* msc = new G4hMultipleScattering();
            G4UrbanMscModel* model = new G4UrbanMscModel();
            model->SetActivationLowEnergyLimit(fScatteringLimit);
            msc->SetEmModel(model);
            ph->RegisterProcess(msc, particle);

            G4hIonisation* hIoni = new G4hIonisation();
            hIoni->SetEmModel(new SRIMBraggModel());
            hIoni->SetEmModel(new SRIMBetheBlochModel());
            ph->RegisterProcess(hIoni, particle);

            ph->RegisterProcess(nucr, particle);

        } else if ((!particle->IsShortLived())
                   && (particle->GetPDGCharge() != 0.0)
                   && (particleName != "chargedgeantino")) {

            ph->RegisterProcess(new G4hMultipleScattering(), particle);
            ph->RegisterProcess(new G4hIonisation(), particle);
        }
    }

    if (G4Threading::IsMasterThread()) {
        G4cout << "\nStrata: 'srim' physics list constructed."
               << "\n  nuclear stopping : G4ScreenedNuclearRecoil, ZBL screening, "
               << "explicit recoils below "
               << fScatteringLimit/MeV << " MeV"
               << "\n  electronic stopping : external table where loaded, "
               << "Geant4 ICRU/ASTAR otherwise" << G4endl;
        SRIMStoppingData::Instance().Print();
    }
}

//==============================================================================
