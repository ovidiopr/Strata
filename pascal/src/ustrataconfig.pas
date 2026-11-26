{==============================================================================
  uStrataConfig.pas: a whole Strata set-up, independent of the user interface.

  TStrataConfig is plain data: geometry, materials, beam, physics, spectra
  and where the output goes.  It knows how to write and read itself as XML,
  and how to write and read the equivalent Geant4 macro.

  Keeping it out of the form has two consequences worth the separation.  The
  window stays what it was (widgets that translate into UI commands and
  hold no state of their own) and the file formats can be tested without a
  display, which is what pascal/tests/StrataConfigCheck does.

  Numbers are written with a '.' whatever the user's locale is, for the same
  reason the UI commands are: Geant4 and XML both expect it, and a locale
  with a decimal comma would otherwise produce files that neither can read.
==============================================================================}

unit uStrataConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, DOM, XMLRead, XMLWrite;

const
  StrataConfigVersion = '1';

type
  // One layer of the target, beam enters at index 0
  TStrataLayerDef = record
    Thickness: Double;
    Units: String;
    Material: String;
    // Optional: overrides the material density
    Density: Double;
    DensityUnit: String;
  end;

  // One constituent of a user-defined material
  TStrataConstituent = record
    Kind: String;        // 'material' or 'element'
    Name: String;
    Amount: Double;      // mass fraction, or a count when ByAtoms is set
  end;

  // A material built from a density and a list of constituents
  TStrataMaterialDef = record
    Name: String;
    Density: Double;
    DensityUnit: String;
    ByAtoms: Boolean;
    Parts: array of TStrataConstituent;
  end;

  // A test volume: a box where the dose is scored
  TStrataVoxelDef = record
    SizeX, SizeY, SizeZ: Double;
    SizeUnit: String;
    PosX, PosY, PosZ: Double;
    PosUnit: String;
  end;

  // A material's displacement constants, as set in this configuration
  TStrataDamageDef = record
    Material: String;
    Ed: Double;                  // eV
    HasArc: Boolean;
    ArcB, ArcC: Double;
  end;

  // Where a block of hand-written commands is sent
  TStrataStage = (
    stGeometry,   // after the geometry, while the kernel can still be changed
    stPreInit,    // last thing before /run/initialize: cuts, EM options
    stBeam,       // after initialisation, before the gun is set up
    stRun         // last thing before /run/beamOn
  );

const
  // What each one is called on the Options tab, and in the saved file
  StrataStageName: array[TStrataStage] of String = (
    'geometry', 'preinit', 'beam', 'run');
  StrataStageCaption: array[TStrataStage] of String = (
    'After the geometry', 'Before initialisation',
    'Before the beam', 'Before the run');

type
  // A spectrum that has been switched on
  TStrataSpectrumDef = record
    Id: Integer;
    Bins: Integer;
    Min, Max: Double;
    Units: String;
    // The binning function Geant4 takes after the unit, normally log10
    Fcn: String;
  end;

  { TStrataConfig }

  TStrataConfig = class
  public
    Threads: Integer;

    SizeYZ: Double;
    SizeUnit: String;
    WorldMaterial: String;
    Layers: array of TStrataLayerDef;

    Materials: array of TStrataMaterialDef;
    Voxels: array of TStrataVoxelDef;

    // Per-step track listings
    SavePrimaries: Boolean;
    SaveCascades: Boolean;
    PrimariesName: String;
    CascadesName: String;

    // Pseudo-random generator
    RandomEngine: String;
    RandomSeed1, RandomSeed2: Int64;
    // A fresh stream for every run
    RandomRandomize: Boolean;

    // Magnetic field, as /strata/BField/ takes it
    FieldOn: Boolean;
    FieldBx, FieldBy, FieldBz: Double;
    FieldUnit: String;
    FieldMinStep: Double;
    FieldMinStepUnit: String;
    FieldStepper: Integer;

    // Electric field, as /strata/EField/ takes it
    EFieldOn: Boolean;
    EFieldEx, EFieldEy, EFieldEz: Double;
    EFieldUnit: String;
    EFieldMinStep: Double;
    EFieldMinStepUnit: String;
    EFieldStepper: Integer;

    // Rutherford backscattering, as /strata/rbs/ takes it
    RBSOn: Boolean;
    RBSAngle: Double;
    RBSSolidAngle: Double;
    RBSSolidAngleUnit: String;
    RBSResolution: Double;
    RBSResolutionUnit: String;
    RBSTilt: Double;
    RBSScreening: Boolean;

    DamageOn: Boolean;
    Damage: array of TStrataDamageDef;

    // Atomic de-excitation, as /process/em/ takes it
    EmFluo: Boolean;
    EmAuger: Boolean;
    EmAugerCascade: Boolean;
    EmPixe: Boolean;
    EmDeexIgnoreCut: Boolean;

    // Production cuts
    CutOn: Boolean;
    Cut: Double;
    CutUnit: String;
    ParticleCut: array[0..3] of Double;
    ParticleCutUnit: array[0..3] of String;

    // Tracking limits
    StepMaxOn: Boolean;
    StepMax: Double;
    StepMaxUnit: String;
    KillSecondaries: Integer;        // 0 none, 1 kill and record, 2 kill only

    Particle: String;
    IonZ, IonA, IonQ: Integer;
    Energy: Double;
    EnergyUnit: String;
    BeamRadius: Double;
    // Of the target, in kelvin.  Materials carry their temperature and the
    // thermal neutron kernel reads it off them, so it is a property of the
    // geometry rather than of the physics list
    Temperature: Double;
    // Signed, in degrees, in the x-y plane.  The geometry is symmetric
    // about x, so one angle says everything a direction can say that
    // matters, and the gun moves with it to keep hitting the face centre
    BeamAngle: Double;
    Events: Int64;

    PhysicsList: String;
    OptionalPhysics: TStringList;

    // Commands the panels do not cover
    Commands: array[TStrataStage] of TStringList;

    Spectra: array of TStrataSpectrumDef;

    OutputFolder: String;
    OutputBase: String;

    // Only used when one process hands over to its successor on "new session"

    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    procedure SetLayerCount(ACount: Integer);
    function AddMaterial: Integer;
    function AddVoxel: Integer;
    function AddSpectrum: Integer;
    function IndexOfMaterial(const AName: String): Integer;

    // The /strata/material commands that rebuild every stored material
    procedure MaterialCommands(ALines: TStrings; ASkip: TStrings = nil);
    // Appends one block of hand-written commands, with a heading, if any
    procedure StageCommands(ALines: TStrings; AStage: TStrataStage);
    // The entry for a material, added if there is none
    function DamageFor(const AMaterial: String): Integer;

    // One of the two is used: a stream when there is one, the file otherwise
    procedure WriteXML(AStream: TStream; const AFileName: String);
    procedure SaveToXML(const AFileName: String);
    function HasParticleCut: Boolean;
    function ToText: String;
    procedure LoadFromXML(const AFileName: String);

    procedure SaveToMacro(const AFileName: String; AWithBeamOn: Boolean = True);
    // Returns the number of command lines that were recognised
    function LoadFromMacro(const AFileName: String; AUnknown: TStrings): Integer;
  end;

// The /analysis/h1/set line for one spectrum
function StrataSpectrumCommand(const ASpectrum: TStrataSpectrumDef): String;

// Locale-proof number conversion
function StrataNumToText(AValue: Double): String;
function StrataTextToNum(const AText: String; ADefault: Double): Double;


// The editors accept almost any unit, but only a few are passed to Geant4
type
  TStrataQuantity = (sqLength, sqEnergy, sqDensity, sqField, sqEField, sqAngle,
                     sqSolidAngle);

const
  // The only four /run/setCutForAGivenParticle accepts
  kCutParticles: array[0..3] of String = ('gamma', 'e-', 'e+', 'proton');

type
  TDoubleArray = array of Double;

// The unit each quantity is measured in internally
function StrataReferenceUnit(AQuantity: TStrataQuantity): String;

// How many reference units one AUnit is
function StrataUnitFactor(AQuantity: TStrataQuantity; const AUnit: String): Double;

// The units offered for AQuantity, separated by single spaces
function StrataUnitsOffered(AQuantity: TStrataQuantity): String;

// The problem's own unit for AQuantity
function StrataProblemUnit(AQuantity: TStrataQuantity; const AValues: array of Double): String;

// The spellings that differ between the two vocabularies
function StrataG4UnitSpelling(const AUnit: String): String;

// The other direction, for text going INTO a value-and-unit box
function StrataSciUnitSpelling(const AText: String): String;

implementation

type
  TStrataUnitRec = record
    Quantity: TStrataQuantity;
    Symbol: String;      // as Geant4 spells it
    Factor: Double;      // in the quantity's reference unit
  end;

const
  // Every symbol here is one Geant4 accepts
  kStrataUnits: array[0..17] of TStrataUnitRec = (
    (Quantity: sqLength;  Symbol: 'nm';    Factor: 1e-6),
    (Quantity: sqLength;  Symbol: 'um';    Factor: 1e-3),
    (Quantity: sqLength;  Symbol: 'mm';    Factor: 1),
    (Quantity: sqLength;  Symbol: 'cm';    Factor: 10),
    (Quantity: sqLength;  Symbol: 'm';     Factor: 1e3),
    (Quantity: sqLength;  Symbol: 'km';    Factor: 1e6),
    (Quantity: sqEnergy;  Symbol: 'eV';    Factor: 1e-6),
    (Quantity: sqEnergy;  Symbol: 'keV';   Factor: 1e-3),
    (Quantity: sqEnergy;  Symbol: 'MeV';   Factor: 1),
    (Quantity: sqEnergy;  Symbol: 'GeV';   Factor: 1e3),
    (Quantity: sqDensity; Symbol: 'g/cm3'; Factor: 1),
    (Quantity: sqField;   Symbol: 'T';     Factor: 1),
    (Quantity: sqEField;  Symbol: 'V/m';   Factor: 1),
    (Quantity: sqEField;  Symbol: 'kV/m';  Factor: 1e3),
    (Quantity: sqEField;  Symbol: 'MV/m';  Factor: 1e6),
    (Quantity: sqAngle;   Symbol: 'deg';   Factor: 1),
    (Quantity: sqSolidAngle; Symbol: 'msr'; Factor: 1),
    (Quantity: sqSolidAngle; Symbol: 'sr';  Factor: 1e3));

var
  CfgFmt: TFormatSettings;

function StrataReferenceUnit(AQuantity: TStrataQuantity): String;
var
  i: Integer;
begin
  Result := '';
  for i := Low(kStrataUnits) to High(kStrataUnits) do
    if (kStrataUnits[i].Quantity = AQuantity) and (kStrataUnits[i].Factor = 1) then
      Exit(kStrataUnits[i].Symbol);
end;

function StrataUnitFactor(AQuantity: TStrataQuantity; const AUnit: String): Double;
var
  i: Integer;
  want: String;
begin
  Result := 0;
  want := StrataG4UnitSpelling(AUnit);
  for i := Low(kStrataUnits) to High(kStrataUnits) do
    if (kStrataUnits[i].Quantity = AQuantity)
       and (kStrataUnits[i].Symbol = want) then
      Exit(kStrataUnits[i].Factor);
end;

function StrataUnitsOffered(AQuantity: TStrataQuantity): String;
var
  i: Integer;
begin
  Result := '';
  for i := Low(kStrataUnits) to High(kStrataUnits) do
    if kStrataUnits[i].Quantity = AQuantity then
    begin
      if Result <> '' then Result := Result + ' ';
      Result := Result + kStrataUnits[i].Symbol;
    end;
end;

function StrataProblemUnit(AQuantity: TStrataQuantity;
  const AValues: array of Double): String;
var
  i, j, n: Integer;
  score, best: Double;
begin
  Result := StrataReferenceUnit(AQuantity);
  best := -1;
  for i := Low(kStrataUnits) to High(kStrataUnits) do
  begin
    if kStrataUnits[i].Quantity <> AQuantity then Continue;
    // How far this unit leaves the whole set from unity
    score := 0;
    n := 0;
    for j := Low(AValues) to High(AValues) do
      if AValues[j] <> 0 then
      begin
        score := score + Abs(Log10(Abs(AValues[j]) / kStrataUnits[i].Factor));
        Inc(n);
      end;
    if n = 0 then Exit;            // nothing to judge by; the reference unit
    if (best < 0) or (score < best) then
    begin
      best := score;
      Result := kStrataUnits[i].Symbol;
    end;
  end;
end;

function StrataNumToText(AValue: Double): String;
begin
  Result := FloatToStrF(AValue, ffGeneral, 7, 0, CfgFmt);
end;

function StrataTextToNum(const AText: String; ADefault: Double): Double;
begin
  Result := StrToFloatDef(Trim(AText), ADefault, CfgFmt);
end;

function StrataG4UnitSpelling(const AUnit: String): String;
begin
  Result := StringReplace(Trim(AUnit), 'µ', 'u', [rfReplaceAll]);
  Result := StringReplace(Result, 'Å', 'Ang', [rfReplaceAll]);
  Result := StringReplace(Result, '^', '', [rfReplaceAll]);
end;

function StrataSciUnitSpelling(const AText: String): String;
var
  i: Integer;
  c: Char;
begin
  // A digit straight after a letter is an exponent (cm3 or m2)
  Result := '';
  for i := 1 to Length(AText) do
  begin
    c := AText[i];
    if (i > 1) and (c in ['0'..'9']) and (AText[i - 1] in ['a'..'z', 'A'..'Z'])
       and not ((AText[i - 1] in ['e', 'E']) and (i > 2)
                and (AText[i - 2] in ['0'..'9', '.'])) then
      Result := Result + '^';
    Result := Result + c;
  end;
  Result := StringReplace(Result, 'Ang', 'Å', [rfReplaceAll]);
end;

// Splits a command line into its words
procedure SplitWords(const ALine: String; AWords: TStrings);
var
  i, start: Integer;
begin
  AWords.Clear;
  i := 1;
  while i <= Length(ALine) do
  begin
    while (i <= Length(ALine)) and (ALine[i] in [' ', #9]) do Inc(i);
    if i > Length(ALine) then Break;
    start := i;
    while (i <= Length(ALine)) and not (ALine[i] in [' ', #9]) do Inc(i);
    AWords.Add(Copy(ALine, start, i - start));
  end;
end;

function WordAt(AWords: TStrings; AIndex: Integer): String;
begin
  if (AIndex >= 0) and (AIndex < AWords.Count) then
    Result := AWords[AIndex]
  else
    Result := '';
end;

{==============================================================================
  TStrataConfig
==============================================================================}

constructor TStrataConfig.Create;
var
  stage: TStrataStage;
begin
  inherited Create;
  OptionalPhysics := TStringList.Create;
  for stage := Low(TStrataStage) to High(TStrataStage) do
    Commands[stage] := TStringList.Create;
  Clear;
end;

destructor TStrataConfig.Destroy;
var
  stage: TStrataStage;
begin
  for stage := Low(TStrataStage) to High(TStrataStage) do
    Commands[stage].Free;
  OptionalPhysics.Free;
  inherited Destroy;
end;

procedure TStrataConfig.Clear;
var
  stage: TStrataStage;
  i: Integer;
begin
  for stage := Low(TStrataStage) to High(TStrataStage) do
    Commands[stage].Clear;

  Threads := 2;

  SizeYZ := 1;
  SizeUnit := 'cm';
  WorldMaterial := 'G4_Galactic';
  SetLength(Layers, 0);

  SetLength(Materials, 0);
  SetLength(Voxels, 0);

  SavePrimaries := False;
  SaveCascades := False;
  PrimariesName := 'primaries.txt';
  CascadesName := 'cascades.txt';

  RandomEngine := 'ranecu';
  RandomSeed1 := 0;
  RandomSeed2 := 0;
  RandomRandomize := True;

  // No field unless one is asked for
  FieldOn := False;
  FieldBx := 0;
  FieldBy := 0;
  FieldBz := 0;
  FieldUnit := 'T';
  FieldMinStep := 1.0;
  FieldMinStepUnit := 'mm';
  FieldStepper := 17;

  EFieldOn := False;
  EFieldEx := 0;
  EFieldEy := 0;
  EFieldEz := 0;
  EFieldUnit := 'kV/m';
  EFieldMinStep := 1.0;
  EFieldMinStepUnit := 'mm';
  EFieldStepper := 4;

  // RBSDetector's defaults
  RBSOn := False;
  RBSAngle := 165;
  RBSSolidAngle := 1;
  RBSSolidAngleUnit := 'msr';
  RBSResolution := 15;
  RBSResolutionUnit := 'keV';
  RBSTilt := 0;
  RBSScreening := True;

  DamageOn := False;
  SetLength(Damage, 0);

  // Geant4's own defaults, measured: every one of these is off
  EmFluo := False;
  EmAuger := False;
  EmAugerCascade := False;
  EmPixe := False;
  EmDeexIgnoreCut := False;

  // PhysicsList sets the default cut to 1 nm
  CutOn := False;
  Cut := 1;
  CutUnit := 'nm';
  for i := 0 to High(ParticleCut) do
  begin
    ParticleCut[i] := 0;
    ParticleCutUnit[i] := '';
  end;

  StepMaxOn := False;
  StepMax := 1;
  StepMaxUnit := 'um';
  KillSecondaries := 0;

  Particle := 'proton';
  IonZ := 14;
  IonA := 28;
  IonQ := -1;
  Energy := 1;
  EnergyUnit := 'MeV';
  BeamRadius := 0;
  BeamAngle := 0;
  Temperature := 293.15;
  Events := 1000;

  PhysicsList := 'standardNR';
  OptionalPhysics.Clear;

  SetLength(Spectra, 0);

  OutputFolder := '';
  OutputBase := 'strata';

end;

procedure TStrataConfig.SetLayerCount(ACount: Integer);
var
  old, i: Integer;
begin
  if ACount < 0 then ACount := 0;
  old := Length(Layers);
  SetLength(Layers, ACount);
  for i := old to ACount - 1 do
  begin
    Layers[i].Thickness := 20;
    Layers[i].Units := 'um';
    Layers[i].Material := 'G4_SILICON_DIOXIDE';
    Layers[i].Density := 0;
    Layers[i].DensityUnit := 'g/cm3';
  end;
end;

function TStrataConfig.AddMaterial: Integer;
begin
  Result := Length(Materials);
  SetLength(Materials, Result + 1);
  Materials[Result].Density := 1;
  Materials[Result].DensityUnit := 'g/cm3';
  Materials[Result].ByAtoms := False;
  SetLength(Materials[Result].Parts, 0);
end;

function TStrataConfig.AddVoxel: Integer;
begin
  Result := Length(Voxels);
  SetLength(Voxels, Result + 1);
  Voxels[Result].SizeUnit := 'um';
  Voxels[Result].PosUnit := 'um';
end;

function TStrataConfig.AddSpectrum: Integer;
begin
  Result := Length(Spectra);
  SetLength(Spectra, Result + 1);
  Spectra[Result].Bins := 100;
  Spectra[Result].Min := 0;
  Spectra[Result].Max := 1;
end;

function TStrataConfig.IndexOfMaterial(const AName: String): Integer;
var
  i: Integer;
begin
  for i := 0 to High(Materials) do
    if SameText(Materials[i].Name, AName) then Exit(i);
  Result := -1;
end;

procedure TStrataConfig.MaterialCommands(ALines: TStrings; ASkip: TStrings);
var
  i, p: Integer;
begin
  for i := 0 to High(Materials) do
  begin
    // Something already defined in the running session must not be defined again
    if (ASkip <> nil) and (ASkip.IndexOf(Materials[i].Name) >= 0) then Continue;
    ALines.Add(Format('/strata/material/create %s %s %s',
                      [Materials[i].Name, StrataNumToText(Materials[i].Density),
                      StrataG4UnitSpelling(Materials[i].DensityUnit)]));
    for p := 0 to High(Materials[i].Parts) do
      if Materials[i].ByAtoms then
        ALines.Add(Format('/strata/material/addElementByAtoms %s %d',
                          [Materials[i].Parts[p].Name, Round(Materials[i].Parts[p].Amount)]))
      else if SameText(Materials[i].Parts[p].Kind, 'element') then
        ALines.Add(Format('/strata/material/addElement %s %s',
                          [Materials[i].Parts[p].Name, StrataNumToText(Materials[i].Parts[p].Amount)]))
      else
        ALines.Add(Format('/strata/material/addMaterial %s %s',
                          [Materials[i].Parts[p].Name, StrataNumToText(Materials[i].Parts[p].Amount)]));
    ALines.Add('/strata/material/build');
  end;
end;

{------------------------------------------------------------------------------
  XML
------------------------------------------------------------------------------}

// A particle name as an XML attribute can use
function TrueWord(const AWord: String): Boolean;
begin
  Result := (AWord = '') or SameText(AWord, 'true') or (AWord = '1');
end;

function IndexOfCutParticle(const AName: String): Integer;
begin
  for Result := Low(kCutParticles) to High(kCutParticles) do
    if SameText(kCutParticles[Result], AName) then Exit;
  Result := -1;
end;

function XmlName(const AParticle: String): String;
begin
  Result := StringReplace(AParticle, '+', 'plus', [rfReplaceAll]);
  Result := StringReplace(Result, '-', 'minus', [rfReplaceAll]);
end;

procedure TStrataConfig.WriteXML(AStream: TStream; const AFileName: String);
var
  doc: TXMLDocument;
  root, node, sub, part: TDOMElement;
  i, p: Integer;
  stage: TStrataStage;

  function Elem(AParent: TDOMElement; const AName: String): TDOMElement;
  begin
    Result := doc.CreateElement(UTF8Decode(AName));
    AParent.AppendChild(Result);
  end;

  procedure Attr(AElem: TDOMElement; const AName, AValue: String);
  begin
    AElem.SetAttribute(UTF8Decode(AName), UTF8Decode(AValue));
  end;

  procedure AttrNum(AElem: TDOMElement; const AName: String; AValue: Double);
  begin
    Attr(AElem, AName, StrataNumToText(AValue));
  end;

  // The file keeps words rather than 0/1, as the composition attribute does
  function BoolWord(AValue: Boolean): String;
  begin
    if AValue then Result := 'yes' else Result := 'no';
  end;

  procedure AttrInt(AElem: TDOMElement; const AName: String; AValue: Int64);
  begin
    Attr(AElem, AName, IntToStr(AValue));
  end;

begin
  doc := TXMLDocument.Create;
  try
    root := doc.CreateElement('strata-configuration');
    Attr(root, 'version', StrataConfigVersion);
    doc.AppendChild(root);

    node := Elem(root, 'engine');
    AttrInt(node, 'threads', Threads);

    node := Elem(root, 'geometry');
    AttrNum(node, 'transverseSize', SizeYZ);
    AttrNum(node, 'temperature', Temperature);
    Attr(node, 'transverseSizeUnit', SizeUnit);
    Attr(node, 'worldMaterial', WorldMaterial);
    for i := 0 to High(Layers) do
    begin
      sub := Elem(node, 'layer');
      AttrInt(sub, 'index', i);
      AttrNum(sub, 'thickness', Layers[i].Thickness);
      Attr(sub, 'unit', Layers[i].Units);
      Attr(sub, 'material', Layers[i].Material);
      if Layers[i].Density > 0 then
      begin
        AttrNum(sub, 'density', Layers[i].Density);
        Attr(sub, 'densityUnit', Layers[i].DensityUnit);
      end;
    end;

    node := Elem(root, 'materials');
    for i := 0 to High(Materials) do
    begin
      sub := Elem(node, 'material');
      Attr(sub, 'name', Materials[i].Name);
      AttrNum(sub, 'density', Materials[i].Density);
      Attr(sub, 'densityUnit', Materials[i].DensityUnit);
      if Materials[i].ByAtoms then
        Attr(sub, 'composition', 'atoms')
      else
        Attr(sub, 'composition', 'massFractions');
      for p := 0 to High(Materials[i].Parts) do
      begin
        part := Elem(sub, 'constituent');
        Attr(part, 'kind', Materials[i].Parts[p].Kind);
        Attr(part, 'name', Materials[i].Parts[p].Name);
        AttrNum(part, 'amount', Materials[i].Parts[p].Amount);
      end;
    end;

    node := Elem(root, 'voxels');
    for i := 0 to High(Voxels) do
    begin
      sub := Elem(node, 'voxel');
      AttrInt(sub, 'index', i);
      AttrNum(sub, 'sizeX', Voxels[i].SizeX);
      AttrNum(sub, 'sizeY', Voxels[i].SizeY);
      AttrNum(sub, 'sizeZ', Voxels[i].SizeZ);
      Attr(sub, 'sizeUnit', Voxels[i].SizeUnit);
      AttrNum(sub, 'posX', Voxels[i].PosX);
      AttrNum(sub, 'posY', Voxels[i].PosY);
      AttrNum(sub, 'posZ', Voxels[i].PosZ);
      Attr(sub, 'posUnit', Voxels[i].PosUnit);
    end;

    node := Elem(root, 'tracks');
    Attr(node, 'primaries', BoolWord(SavePrimaries));
    Attr(node, 'primariesFile', PrimariesName);
    Attr(node, 'cascades', BoolWord(SaveCascades));
    Attr(node, 'cascadesFile', CascadesName);

    node := Elem(root, 'random');
    Attr(node, 'engine', RandomEngine);
    if RandomRandomize then
      Attr(node, 'seeding', 'perRun')
    else
      Attr(node, 'seeding', 'fixed');
    AttrInt(node, 'seed1', RandomSeed1);
    AttrInt(node, 'seed2', RandomSeed2);

    if FieldOn then
    begin
      node := Elem(root, 'field');
      AttrNum(node, 'bx', FieldBx);
      AttrNum(node, 'by', FieldBy);
      AttrNum(node, 'bz', FieldBz);
      Attr(node, 'unit', FieldUnit);
      AttrNum(node, 'minStep', FieldMinStep);
      Attr(node, 'minStepUnit', FieldMinStepUnit);
      AttrInt(node, 'stepper', FieldStepper);
    end;

    if EFieldOn then
    begin
      node := Elem(root, 'efield');
      AttrNum(node, 'ex', EFieldEx);
      AttrNum(node, 'ey', EFieldEy);
      AttrNum(node, 'ez', EFieldEz);
      Attr(node, 'unit', EFieldUnit);
      AttrNum(node, 'minStep', EFieldMinStep);
      Attr(node, 'minStepUnit', EFieldMinStepUnit);
      AttrInt(node, 'stepper', EFieldStepper);
    end;

    if RBSOn then
    begin
      node := Elem(root, 'rbs');
      AttrNum(node, 'angle', RBSAngle);
      AttrNum(node, 'solidAngle', RBSSolidAngle);
      Attr(node, 'solidAngleUnit', RBSSolidAngleUnit);
      AttrNum(node, 'resolution', RBSResolution);
      Attr(node, 'resolutionUnit', RBSResolutionUnit);
      AttrNum(node, 'tilt', RBSTilt);
      Attr(node, 'screening', BoolWord(RBSScreening));
    end;

    if DamageOn or (Length(Damage) > 0) then
    begin
      node := Elem(root, 'damage');
      Attr(node, 'enabled', BoolWord(DamageOn));
      for i := 0 to High(Damage) do
      begin
        sub := Elem(node, 'material');
        Attr(sub, 'name', Damage[i].Material);
        AttrNum(sub, 'ed', Damage[i].Ed);
        if Damage[i].HasArc then
        begin
          AttrNum(sub, 'b', Damage[i].ArcB);
          AttrNum(sub, 'c', Damage[i].ArcC);
        end;
      end;
    end;

    if EmFluo or EmAuger or EmAugerCascade or EmPixe or EmDeexIgnoreCut then
    begin
      node := Elem(root, 'deexcitation');
      Attr(node, 'fluo', BoolWord(EmFluo));
      Attr(node, 'auger', BoolWord(EmAuger));
      Attr(node, 'augerCascade', BoolWord(EmAugerCascade));
      Attr(node, 'pixe', BoolWord(EmPixe));
      Attr(node, 'ignoreCut', BoolWord(EmDeexIgnoreCut));
    end;

    if CutOn or StepMaxOn or (KillSecondaries <> 0) then
    begin
      node := Elem(root, 'tracking');
      if CutOn then
      begin
        AttrNum(node, 'cut', Cut);
        Attr(node, 'cutUnit', CutUnit);
      end;
      for i := 0 to High(ParticleCut) do
        if ParticleCutUnit[i] <> '' then
        begin
          AttrNum(node, 'cut_' + XmlName(kCutParticles[i]), ParticleCut[i]);
          Attr(node, 'cutUnit_' + XmlName(kCutParticles[i]), ParticleCutUnit[i]);
        end;
      if StepMaxOn then
      begin
        AttrNum(node, 'stepMax', StepMax);
        Attr(node, 'stepMaxUnit', StepMaxUnit);
      end;
      AttrInt(node, 'killSecondaries', KillSecondaries);
    end;

    node := Elem(root, 'beam');
    Attr(node, 'particle', Particle);
    AttrNum(node, 'energy', Energy);
    Attr(node, 'energyUnit', EnergyUnit);
    AttrNum(node, 'radius', BeamRadius);
    AttrNum(node, 'angle', BeamAngle);
    AttrInt(node, 'events', Events);
    sub := Elem(node, 'ion');
    AttrInt(sub, 'z', IonZ);
    AttrInt(sub, 'a', IonA);
    AttrInt(sub, 'charge', IonQ);

    node := Elem(root, 'physics');
    Attr(node, 'list', PhysicsList);
    for i := 0 to OptionalPhysics.Count - 1 do
    begin
      sub := Elem(node, 'optional');
      Attr(sub, 'name', OptionalPhysics[i]);
    end;

    node := Elem(root, 'spectra');
    for i := 0 to High(Spectra) do
    begin
      sub := Elem(node, 'spectrum');
      AttrInt(sub, 'id', Spectra[i].Id);
      AttrInt(sub, 'bins', Spectra[i].Bins);
      AttrNum(sub, 'min', Spectra[i].Min);
      AttrNum(sub, 'max', Spectra[i].Max);
      Attr(sub, 'unit', Spectra[i].Units);
      Attr(sub, 'fcn', Spectra[i].Fcn);
    end;

    // Hand-written commands, one element per stage, the text kept verbatim
    for stage := Low(TStrataStage) to High(TStrataStage) do
      if Trim(Commands[stage].Text) <> '' then
      begin
        node := Elem(root, 'commands');
        Attr(node, 'stage', StrataStageName[stage]);
        node.AppendChild(doc.CreateTextNode(UTF8Decode(Commands[stage].Text)));
      end;

    node := Elem(root, 'output');
    Attr(node, 'folder', OutputFolder);
    Attr(node, 'fileName', OutputBase);

    if AStream <> nil then
      WriteXMLFile(doc, AStream)
    else
      WriteXMLFile(doc, AFileName);
  finally
    doc.Free;
  end;
end;

procedure TStrataConfig.SaveToXML(const AFileName: String);
begin
  WriteXML(nil, AFileName);
end;

// The same document as a string
function TStrataConfig.HasParticleCut: Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to High(ParticleCut) do
    if ParticleCutUnit[i] <> '' then Exit;
  Result := False;
end;

function TStrataConfig.ToText: String;
var
  stream: TStringStream;
begin
  stream := TStringStream.Create('');
  try
    WriteXML(stream, '');
    Result := stream.DataString;
  finally
    stream.Free;
  end;
end;

procedure TStrataConfig.LoadFromXML(const AFileName: String);
var
  doc: TXMLDocument;
  root: TDOMElement;
  node, child, part: TDOMNode;
  i, p: Integer;
  stage: TStrataStage;
  name_: String;

  function Get(AElem: TDOMElement; const AName, ADefault: String): String;
  var
    w: WideString;
  begin
    w := AElem.GetAttribute(UTF8Decode(AName));
    if w = '' then Result := ADefault else Result := UTF8Encode(w);
  end;

  function GetNum(AElem: TDOMElement; const AName: String; ADefault: Double): Double;
  begin
    Result := StrataTextToNum(Get(AElem, AName, ''), ADefault);
  end;

  function GetInt(AElem: TDOMElement; const AName: String; ADefault: Int64): Int64;
  begin
    Result := StrToInt64Def(Get(AElem, AName, ''), ADefault);
  end;

  function Section(const AName: String): TDOMElement;
  var
    n: TDOMNode;
  begin
    Result := nil;
    n := root.FirstChild;
    while n <> nil do
    begin
      if (n.NodeType = ELEMENT_NODE) and (n.NodeName = UTF8Decode(AName)) then
        Exit(TDOMElement(n));
      n := n.NextSibling;
    end;
  end;

begin
  doc := nil;
  ReadXMLFile(doc, AFileName);
  try
    root := doc.DocumentElement;
    if (root = nil) or (root.NodeName <> 'strata-configuration') then
      raise Exception.Create(ExtractFileName(AFileName) + ' is not a Strata configuration file');

    Clear;

    node := Section('engine');
    if node <> nil then
      Threads := GetInt(TDOMElement(node), 'threads', Threads);

    node := Section('geometry');
    if node <> nil then
    begin
      SizeYZ := GetNum(TDOMElement(node), 'transverseSize', SizeYZ);
      Temperature := GetNum(TDOMElement(node), 'temperature', Temperature);
      SizeUnit := Get(TDOMElement(node), 'transverseSizeUnit', SizeUnit);
      WorldMaterial := Get(TDOMElement(node), 'worldMaterial', WorldMaterial);
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'layer') then
        begin
          i := Length(Layers);
          SetLength(Layers, i + 1);
          Layers[i].Thickness := GetNum(TDOMElement(child), 'thickness', 0);
          Layers[i].Units := Get(TDOMElement(child), 'unit', 'um');
          Layers[i].Material := Get(TDOMElement(child), 'material', '');
          Layers[i].Density := GetNum(TDOMElement(child), 'density', 0);
          Layers[i].DensityUnit :=
            Get(TDOMElement(child), 'densityUnit', 'g/cm3');
        end;
        child := child.NextSibling;
      end;
    end;

    node := Section('materials');
    if node <> nil then
    begin
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'material') then
        begin
          i := AddMaterial;
          Materials[i].Name := Get(TDOMElement(child), 'name', '');
          Materials[i].Density := GetNum(TDOMElement(child), 'density', 1);
          Materials[i].DensityUnit := Get(TDOMElement(child), 'densityUnit', 'g/cm3');
          Materials[i].ByAtoms :=
            SameText(Get(TDOMElement(child), 'composition', ''), 'atoms');
          part := child.FirstChild;
          while part <> nil do
          begin
            if (part.NodeType = ELEMENT_NODE)
               and (part.NodeName = 'constituent') then
            begin
              p := Length(Materials[i].Parts);
              SetLength(Materials[i].Parts, p + 1);
              Materials[i].Parts[p].Kind :=
                Get(TDOMElement(part), 'kind', 'material');
              Materials[i].Parts[p].Name := Get(TDOMElement(part), 'name', '');
              Materials[i].Parts[p].Amount :=
                GetNum(TDOMElement(part), 'amount', 0);
            end;
            part := part.NextSibling;
          end;
        end;
        child := child.NextSibling;
      end;
    end;

    node := Section('voxels');
    if node <> nil then
    begin
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'voxel') then
        begin
          i := AddVoxel;
          Voxels[i].SizeX := GetNum(TDOMElement(child), 'sizeX', 0);
          Voxels[i].SizeY := GetNum(TDOMElement(child), 'sizeY', 0);
          Voxels[i].SizeZ := GetNum(TDOMElement(child), 'sizeZ', 0);
          Voxels[i].SizeUnit := Get(TDOMElement(child), 'sizeUnit', 'um');
          Voxels[i].PosX := GetNum(TDOMElement(child), 'posX', 0);
          Voxels[i].PosY := GetNum(TDOMElement(child), 'posY', 0);
          Voxels[i].PosZ := GetNum(TDOMElement(child), 'posZ', 0);
          Voxels[i].PosUnit := Get(TDOMElement(child), 'posUnit', 'um');
        end;
        child := child.NextSibling;
      end;
    end;

    node := Section('tracks');
    if node <> nil then
    begin
      SavePrimaries := SameText(Get(TDOMElement(node), 'primaries', 'no'), 'yes');
      SaveCascades := SameText(Get(TDOMElement(node), 'cascades', 'no'), 'yes');
      PrimariesName := Get(TDOMElement(node), 'primariesFile', PrimariesName);
      CascadesName := Get(TDOMElement(node), 'cascadesFile', CascadesName);
    end;

    node := Section('random');
    if node <> nil then
    begin
      RandomEngine := Get(TDOMElement(node), 'engine', RandomEngine);
      RandomRandomize :=
        not SameText(Get(TDOMElement(node), 'seeding', 'perRun'), 'fixed');
      RandomSeed1 := GetInt(TDOMElement(node), 'seed1', RandomSeed1);
      RandomSeed2 := GetInt(TDOMElement(node), 'seed2', RandomSeed2);
    end;

    node := Section('field');
    if node <> nil then
    begin
      FieldOn := True;
      FieldBx := GetNum(TDOMElement(node), 'bx', FieldBx);
      FieldBy := GetNum(TDOMElement(node), 'by', FieldBy);
      FieldBz := GetNum(TDOMElement(node), 'bz', FieldBz);
      FieldUnit := Get(TDOMElement(node), 'unit', FieldUnit);
      FieldMinStep := GetNum(TDOMElement(node), 'minStep', FieldMinStep);
      FieldMinStepUnit := Get(TDOMElement(node), 'minStepUnit', FieldMinStepUnit);
      FieldStepper := GetInt(TDOMElement(node), 'stepper', FieldStepper);
    end;

    node := Section('efield');
    if node <> nil then
    begin
      EFieldOn := True;
      EFieldEx := GetNum(TDOMElement(node), 'ex', EFieldEx);
      EFieldEy := GetNum(TDOMElement(node), 'ey', EFieldEy);
      EFieldEz := GetNum(TDOMElement(node), 'ez', EFieldEz);
      EFieldUnit := Get(TDOMElement(node), 'unit', EFieldUnit);
      EFieldMinStep := GetNum(TDOMElement(node), 'minStep', EFieldMinStep);
      EFieldMinStepUnit := Get(TDOMElement(node), 'minStepUnit', EFieldMinStepUnit);
      EFieldStepper := GetInt(TDOMElement(node), 'stepper', EFieldStepper);
    end;

    node := Section('rbs');
    if node <> nil then
    begin
      RBSOn := True;
      RBSAngle := GetNum(TDOMElement(node), 'angle', RBSAngle);
      RBSSolidAngle := GetNum(TDOMElement(node), 'solidAngle', RBSSolidAngle);
      RBSSolidAngleUnit := Get(TDOMElement(node), 'solidAngleUnit', RBSSolidAngleUnit);
      RBSResolution := GetNum(TDOMElement(node), 'resolution', RBSResolution);
      RBSResolutionUnit := Get(TDOMElement(node), 'resolutionUnit', RBSResolutionUnit);
      RBSTilt := GetNum(TDOMElement(node), 'tilt', RBSTilt);
      RBSScreening := SameText(Get(TDOMElement(node), 'screening', 'yes'), 'yes');
    end;

    node := Section('damage');
    if node <> nil then
    begin
      DamageOn := SameText(Get(TDOMElement(node), 'enabled', 'yes'), 'yes');
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'material') then
        begin
          i := DamageFor(Get(TDOMElement(child), 'name', ''));
          if i >= 0 then
          begin
            Damage[i].Ed := GetNum(TDOMElement(child), 'ed', 0);
            Damage[i].HasArc := TDOMElement(child).hasAttribute('b');
            Damage[i].ArcB := GetNum(TDOMElement(child), 'b', 0);
            Damage[i].ArcC := GetNum(TDOMElement(child), 'c', 1);
          end;
        end;
        child := child.NextSibling;
      end;
    end;

    node := Section('deexcitation');
    if node <> nil then
    begin
      EmFluo := SameText(Get(TDOMElement(node), 'fluo', 'no'), 'yes');
      EmAuger := SameText(Get(TDOMElement(node), 'auger', 'no'), 'yes');
      EmAugerCascade := SameText(Get(TDOMElement(node), 'augerCascade', 'no'), 'yes');
      EmPixe := SameText(Get(TDOMElement(node), 'pixe', 'no'), 'yes');
      EmDeexIgnoreCut := SameText(Get(TDOMElement(node), 'ignoreCut', 'no'), 'yes');
    end;

    node := Section('tracking');
    if node <> nil then
    begin
      CutOn := Get(TDOMElement(node), 'cut', '') <> '';
      if CutOn then
      begin
        Cut := GetNum(TDOMElement(node), 'cut', Cut);
        CutUnit := Get(TDOMElement(node), 'cutUnit', CutUnit);
      end;
      for i := 0 to High(ParticleCut) do
        if Get(TDOMElement(node), 'cut_' + XmlName(kCutParticles[i]), '') <> '' then
        begin
          ParticleCut[i] := GetNum(TDOMElement(node), 'cut_' + XmlName(kCutParticles[i]), 0);
          ParticleCutUnit[i] := Get(TDOMElement(node),
            'cutUnit_' + XmlName(kCutParticles[i]), 'mm');
        end;
      StepMaxOn := Get(TDOMElement(node), 'stepMax', '') <> '';
      if StepMaxOn then
      begin
        StepMax := GetNum(TDOMElement(node), 'stepMax', StepMax);
        StepMaxUnit := Get(TDOMElement(node), 'stepMaxUnit', StepMaxUnit);
      end;
      KillSecondaries := GetInt(TDOMElement(node), 'killSecondaries', 0);
    end;

    node := Section('beam');
    if node <> nil then
    begin
      Particle := Get(TDOMElement(node), 'particle', Particle);
      Energy := GetNum(TDOMElement(node), 'energy', Energy);
      EnergyUnit := Get(TDOMElement(node), 'energyUnit', EnergyUnit);
      BeamRadius := GetNum(TDOMElement(node), 'radius', BeamRadius);
      BeamAngle := GetNum(TDOMElement(node), 'angle', BeamAngle);
      Events := GetInt(TDOMElement(node), 'events', Events);
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'ion') then
        begin
          IonZ := GetInt(TDOMElement(child), 'z', IonZ);
          IonA := GetInt(TDOMElement(child), 'a', IonA);
          IonQ := GetInt(TDOMElement(child), 'charge', IonQ);
        end;
        child := child.NextSibling;
      end;
    end;

    node := Section('physics');
    if node <> nil then
    begin
      PhysicsList := Get(TDOMElement(node), 'list', PhysicsList);
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'optional') then
          OptionalPhysics.Add(Get(TDOMElement(child), 'name', ''));
        child := child.NextSibling;
      end;
    end;

    // There is one element per stage, so they are walked rather than
    // looked up by name
    child := root.FirstChild;
    while child <> nil do
    begin
      if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'commands') then
      begin
        name_ := Get(TDOMElement(child), 'stage', '');
        for stage := Low(TStrataStage) to High(TStrataStage) do
          if name_ = StrataStageName[stage] then
            Commands[stage].Text := UTF8Encode(child.TextContent);
      end;
      child := child.NextSibling;
    end;

    node := Section('spectra');
    if node <> nil then
    begin
      child := node.FirstChild;
      while child <> nil do
      begin
        if (child.NodeType = ELEMENT_NODE) and (child.NodeName = 'spectrum') then
        begin
          i := AddSpectrum;
          Spectra[i].Id := GetInt(TDOMElement(child), 'id', 0);
          Spectra[i].Bins := GetInt(TDOMElement(child), 'bins', 100);
          Spectra[i].Min := GetNum(TDOMElement(child), 'min', 0);
          Spectra[i].Max := GetNum(TDOMElement(child), 'max', 1);
          Spectra[i].Units := Get(TDOMElement(child), 'unit', '');
          Spectra[i].Fcn := Get(TDOMElement(child), 'fcn', '');
        end;
        child := child.NextSibling;
      end;
    end;

    node := Section('output');
    if node <> nil then
    begin
      OutputFolder := Get(TDOMElement(node), 'folder', '');
      OutputBase := Get(TDOMElement(node), 'fileName', 'strata');
    end;
  finally
    doc.Free;
  end;
end;

{------------------------------------------------------------------------------
  Macro
------------------------------------------------------------------------------}

function TStrataConfig.DamageFor(const AMaterial: String): Integer;
begin
  if AMaterial = '' then Exit(-1);
  for Result := 0 to High(Damage) do
    if Damage[Result].Material = AMaterial then Exit;
  Result := Length(Damage);
  SetLength(Damage, Result + 1);
  Damage[Result].Material := AMaterial;
  Damage[Result].Ed := 0;
  Damage[Result].HasArc := False;
  Damage[Result].ArcB := 0;
  Damage[Result].ArcC := 1;
end;

procedure TStrataConfig.StageCommands(ALines: TStrings; AStage: TStrataStage);
var
  i: Integer;
  line: String;
  wrote: Boolean;
begin
  wrote := False;
  for i := 0 to Commands[AStage].Count - 1 do
  begin
    line := Trim(Commands[AStage][i]);
    if line = '' then Continue;
    if not wrote then
    begin
      ALines.Add(Format('# --- %s (typed in the Options tab) ---',
                        [LowerCase(StrataStageCaption[AStage])]));
      wrote := True;
    end;
    ALines.Add(line);
  end;
  if wrote then ALines.Add('');
end;

procedure TStrataConfig.SaveToMacro(const AFileName: String;
  AWithBeamOn: Boolean);
var
  lines: TStringList;
  i: Integer;
begin
  lines := TStringList.Create;
  try
    lines.Add('#==============================================================================');
    lines.Add('# Strata configuration, written by the graphical front end on ' + FormatDateTime('yyyy-mm-dd hh:nn', Now));
    lines.Add('#');
    lines.Add('# Run it with:  Strata ' + ExtractFileName(AFileName));
    lines.Add('#==============================================================================');
    lines.Add('');
    lines.Add('/control/verbose 1');
    lines.Add('/run/verbose 0');
    lines.Add(Format('/run/numberOfThreads %d', [Threads]));
    lines.Add('');

    if Length(Materials) > 0 then
    begin
      lines.Add('# --- materials ---');
      MaterialCommands(lines);
      lines.Add('');
    end;

    lines.Add('# --- geometry ---');
    // Every length is written in the unit it was kept in
    lines.Add(Format('/strata/geometry/setSizeYZ %s %s', [StrataNumToText(SizeYZ), StrataG4UnitSpelling(SizeUnit)]));
    // Only when it is not what Geant4 builds materials at anyway, so that
    // an ordinary configuration does not carry a line that changes nothing
    if Abs(Temperature - 293.15) > 1e-9 then
      lines.Add(Format('/strata/geometry/setTemperature %s kelvin',
                       [StrataNumToText(Temperature)]));
    if WorldMaterial <> '' then
      lines.Add('/strata/geometry/setWorldMat ' + WorldMaterial);
    lines.Add(Format('/strata/geometry/layerNumber %d', [Length(Layers)]));
    for i := 0 to High(Layers) do
    begin
      lines.Add(Format('/strata/geometry/layerThickness %d %s %s',
                       [i, StrataNumToText(Layers[i].Thickness),
                       StrataG4UnitSpelling(Layers[i].Units)]));
      if Layers[i].Material <> '' then
        if Layers[i].Density > 0 then
          lines.Add(Format('/strata/geometry/layerMaterial %d %s %s %s',
                           [i, Layers[i].Material, StrataNumToText(Layers[i].Density),
                           StrataG4UnitSpelling(Layers[i].DensityUnit)]))
        else
          lines.Add(Format('/strata/geometry/layerMaterial %d %s', [i, Layers[i].Material]));
    end;
    lines.Add('');

    if Length(Voxels) > 0 then
    begin
      lines.Add('# --- test volumes where the dose is scored ---');
      lines.Add(Format('/strata/geometry/voxelNumber %d', [Length(Voxels)]));
      for i := 0 to High(Voxels) do
      begin
        lines.Add(Format('/strata/geometry/voxelDefinition %d %s %s %s %s',
                         [i, StrataNumToText(Voxels[i].SizeX), StrataNumToText(Voxels[i].SizeY),
                         StrataNumToText(Voxels[i].SizeZ), StrataG4UnitSpelling(Voxels[i].SizeUnit)]));
        lines.Add(Format('/strata/geometry/voxelPosition %d %s %s %s %s',
                         [i, StrataNumToText(Voxels[i].PosX), StrataNumToText(Voxels[i].PosY),
                         StrataNumToText(Voxels[i].PosZ), StrataG4UnitSpelling(Voxels[i].PosUnit)]));
      end;
      lines.Add('');
    end;

    StageCommands(lines, stGeometry);

    if SavePrimaries or SaveCascades then
    begin
      lines.Add('# --- per-step track listings (one worker thread) ---');
      if PrimariesName <> '' then
        lines.Add('/strata/files/setPrimariesName ' + PrimariesName);
      if CascadesName <> '' then
        lines.Add('/strata/files/setCascadesName ' + CascadesName);
      if SavePrimaries then lines.Add('/strata/files/savePrimaries true');
      if SaveCascades then lines.Add('/strata/files/saveCascades true');
      lines.Add('');
    end;

    lines.Add('# --- random numbers ---');
    lines.Add('/strata/random/engine ' + RandomEngine);
    if RandomRandomize then
      lines.Add('/strata/random/randomize true')
    else
      lines.Add(Format('/strata/random/seeds %d %d',
        [RandomSeed1, RandomSeed2]));
    lines.Add('');

    lines.Add('# --- physics ---');
    if PhysicsList <> '' then
      lines.Add('/strata/physics/addPhysics ' + PhysicsList);
    for i := 0 to OptionalPhysics.Count - 1 do
      lines.Add('/strata/physics/addPhysics ' + OptionalPhysics[i]);
    lines.Add('');

    StageCommands(lines, stPreInit);

    lines.Add('/run/initialize');
    lines.Add('');

    // After initialize: /strata/BField/ is only available in Idle
    if FieldOn then
    begin
      lines.Add('# --- magnetic field ---');
      if FieldStepper <> 17 then
        lines.Add(Format('/strata/BField/setStepperType %d', [FieldStepper]));
      lines.Add(Format('/strata/BField/setMinStep %s %s',
                       [StrataNumToText(FieldMinStep), StrataG4UnitSpelling(FieldMinStepUnit)]));
      lines.Add(Format('/strata/BField/setValue %s %s %s %s',
                       [StrataNumToText(FieldBx), StrataNumToText(FieldBy),
                       StrataNumToText(FieldBz), StrataG4UnitSpelling(FieldUnit)]));
      lines.Add('/strata/BField/update');
      lines.Add('');
    end;

    // Only one of the two
    if EFieldOn and (not FieldOn) then
    begin
      lines.Add('# --- electric field ---');
      if EFieldStepper <> 4 then
        lines.Add(Format('/strata/EField/setStepperType %d', [EFieldStepper]));
      lines.Add(Format('/strata/EField/setMinStep %s %s',
                       [StrataNumToText(EFieldMinStep), StrataG4UnitSpelling(EFieldMinStepUnit)]));
      lines.Add(Format('/strata/EField/setValue %s %s %s %s',
                       [StrataNumToText(EFieldEx), StrataNumToText(EFieldEy),
                       StrataNumToText(EFieldEz), StrataG4UnitSpelling(EFieldUnit)]));
      lines.Add('/strata/EField/update');
      lines.Add('');
    end;

    if EmFluo or EmAuger or EmAugerCascade or EmPixe or EmDeexIgnoreCut then
    begin
      lines.Add('# --- atomic de-excitation ---');
      if EmFluo then lines.Add('/process/em/fluo true');
      if EmAuger then lines.Add('/process/em/auger true');
      if EmAugerCascade then lines.Add('/process/em/augerCascade true');
      if EmPixe then lines.Add('/process/em/pixe true');
      if EmDeexIgnoreCut then lines.Add('/process/em/deexcitationIgnoreCut true');
      lines.Add('');
    end;

    if CutOn or HasParticleCut then
    begin
      lines.Add('# --- production cuts ---');
      if CutOn then
        lines.Add(Format('/run/setCut %s %s',
                         [StrataNumToText(Cut), StrataG4UnitSpelling(CutUnit)]));
      for i := 0 to High(ParticleCut) do
        if ParticleCutUnit[i] <> '' then
          lines.Add(Format('/run/setCutForAGivenParticle %s %s %s',
                           [kCutParticles[i], StrataNumToText(ParticleCut[i]),
                           StrataG4UnitSpelling(ParticleCutUnit[i])]));
      lines.Add('');
    end;

    if RBSOn then
    begin
      lines.Add('# --- Rutherford backscattering ---');
      lines.Add('/strata/rbs/enable true');
      lines.Add(Format('/strata/rbs/angle %s deg', [StrataNumToText(RBSAngle)]));
      lines.Add(Format('/strata/rbs/solidAngle %s %s',
                       [StrataNumToText(RBSSolidAngle), RBSSolidAngleUnit]));
      lines.Add(Format('/strata/rbs/resolution %s %s',
                       [StrataNumToText(RBSResolution), StrataG4UnitSpelling(RBSResolutionUnit)]));
      if RBSTilt <> 0 then
        lines.Add(Format('/strata/rbs/tilt %s deg', [StrataNumToText(RBSTilt)]));
      if not RBSScreening then lines.Add('/strata/rbs/screening false');
      lines.Add('');
    end;

    if DamageOn or (Length(Damage) > 0) then
    begin
      lines.Add('# --- displacement damage ---');
      for i := 0 to High(Damage) do
      begin
        if Damage[i].Ed > 0 then
          lines.Add(Format('/strata/damage/setEd %s %s eV',
                           [Damage[i].Material, StrataNumToText(Damage[i].Ed)]));
        if Damage[i].HasArc then
          lines.Add(Format('/strata/damage/setArc %s %s %s',
                           [Damage[i].Material, StrataNumToText(Damage[i].ArcB),
                            StrataNumToText(Damage[i].ArcC)]));
      end;
      if DamageOn then lines.Add('/strata/damage/enable true');
      lines.Add('');
    end;

    // These two need their messengers, which do not exist until the kernel
    // is built, so they go after /run/initialize rather than before it
    if StepMaxOn or (KillSecondaries <> 0) then
    begin
      lines.Add('# --- tracking ---');
      if StepMaxOn then
        lines.Add(Format('/strata/stepMax %s %s',
                         [StrataNumToText(StepMax), StrataG4UnitSpelling(StepMaxUnit)]));
      if KillSecondaries <> 0 then
        lines.Add(Format('/strata/stack/killSecondaries %d', [KillSecondaries]));
      lines.Add('');
    end;

    StageCommands(lines, stBeam);

    lines.Add('# --- beam ---');
    if SameText(Particle, 'ion') then
    begin
      lines.Add('/gun/particle ion');
      lines.Add(Format('/gun/ion %d %d %d', [IonZ, IonA, IonQ]));
    end
    else if Particle <> '' then
      lines.Add('/gun/particle ' + Particle);
    lines.Add(Format('/gun/energy %s %s', [StrataNumToText(Energy), StrataG4UnitSpelling(EnergyUnit)]));
    // The radius is kept in the reference unit
    if BeamRadius > 0 then
      lines.Add(Format('/strata/gun/rndBeam %s %s', [StrataNumToText(BeamRadius), StrataReferenceUnit(sqLength)]));
    if BeamAngle <> 0 then
      lines.Add(Format('/strata/gun/angle %s deg', [StrataNumToText(BeamAngle)]));
    lines.Add('');

    lines.Add('# --- output ---');
    if OutputFolder <> '' then
      lines.Add('/analysis/setFileName '
        + IncludeTrailingPathDelimiter(OutputFolder) + OutputBase)
    else
      lines.Add('/analysis/setFileName ' + OutputBase);

    if Length(Spectra) > 0 then
    begin
      lines.Add('');
      lines.Add('# --- spectra ---');
      for i := 0 to High(Spectra) do
        lines.Add(StrataSpectrumCommand(Spectra[i]));
    end;

    if (Commands[stRun].Count > 0) or AWithBeamOn then lines.Add('');
    StageCommands(lines, stRun);

    if AWithBeamOn then
      lines.Add(Format('/run/beamOn %d', [Events]));
    lines.SaveToFile(AFileName);
  finally
    lines.Free;
  end;
end;

function StrataSpectrumCommand(const ASpectrum: TStrataSpectrumDef): String;
begin
  Result := Format('/analysis/h1/set %d %d %s %s',
                   [ASpectrum.Id, ASpectrum.Bins,
                    StrataNumToText(ASpectrum.Min), StrataNumToText(ASpectrum.Max)]);
  if ASpectrum.Units <> '' then
    Result := Result + ' ' + StrataG4UnitSpelling(ASpectrum.Units)
  else if ASpectrum.Fcn <> '' then
    Result := Result + ' none';
  if ASpectrum.Fcn <> '' then
    Result := Result + ' ' + ASpectrum.Fcn;
end;

function TStrataConfig.LoadFromMacro(const AFileName: String; AUnknown: TStrings): Integer;
var
  lines, w: TStringList;
  i, idx, p, physicsSeen, matIdx, partIdx: Integer;
  factor: Double;
  line, code, cmd: String;
  openMaterial: Boolean;
  stage, lineStage: TStrataStage;
begin
  Result := 0;
  physicsSeen := 0;
  matIdx := -1;
  openMaterial := False;

  stage := stPreInit;

  lines := TStringList.Create;
  w := TStringList.Create;
  try
    lines.LoadFromFile(AFileName);
    Clear;
    SetLength(Layers, 0);

    for i := 0 to lines.Count - 1 do
    begin
      line := Trim(lines[i]);
      if (line = '') or (line[1] = '#') then Continue;
      code := line;
      p := Pos('#', code);
      if p > 0 then code := TrimRight(Copy(code, 1, p - 1));
      if code = '' then Continue;
      SplitWords(code, w);
      cmd := WordAt(w, 0);

      // Which stage this line belongs to, and which the ones after it do
      lineStage := stage;
      if cmd = '/run/initialize' then
        stage := stBeam
      else if (stage = stBeam) and ((Copy(cmd, 1, 5) = '/gun/')
                                 or (Copy(cmd, 1, 12) = '/strata/gun/')) then
        stage := stRun;

      if cmd = '/run/numberOfThreads' then
        Threads := StrToIntDef(WordAt(w, 1), Threads)

      else if cmd = '/strata/geometry/setSizeYZ' then
      begin
        SizeYZ := StrataTextToNum(WordAt(w, 1), SizeYZ);
        if WordAt(w, 2) <> '' then SizeUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/geometry/setTemperature' then
        Temperature := StrataTextToNum(WordAt(w, 1), Temperature)

      else if cmd = '/strata/geometry/setWorldMat' then
        WorldMaterial := WordAt(w, 1)

      else if cmd = '/strata/geometry/layerNumber' then
        SetLayerCount(StrToIntDef(WordAt(w, 1), 0))

      else if cmd = '/strata/geometry/layerThickness' then
      begin
        idx := StrToIntDef(WordAt(w, 1), -1);
        if (idx >= 0) then
        begin
          if idx > High(Layers) then SetLayerCount(idx + 1);
          Layers[idx].Thickness := StrataTextToNum(WordAt(w, 2), 0);
          if WordAt(w, 3) <> '' then Layers[idx].Units := WordAt(w, 3);
        end;
      end

      else if cmd = '/strata/geometry/layerMaterial' then
      begin
        idx := StrToIntDef(WordAt(w, 1), -1);
        if idx >= 0 then
        begin
          if idx > High(Layers) then SetLayerCount(idx + 1);
          Layers[idx].Material := WordAt(w, 2);
          // The density and its unit are optional, and a density of zero
          // means the material's own
          Layers[idx].Density := StrataTextToNum(WordAt(w, 3), 0);
          if WordAt(w, 4) <> '' then
            Layers[idx].DensityUnit := WordAt(w, 4);
        end;
      end

      else if cmd = '/strata/geometry/voxelNumber' then
      begin
        SetLength(Voxels, 0);
        for idx := 1 to StrToIntDef(WordAt(w, 1), 0) do AddVoxel;
      end

      else if (cmd = '/strata/geometry/voxelDefinition') or (cmd = '/strata/geometry/voxelPosition') then
      begin
        idx := StrToIntDef(WordAt(w, 1), -1);
        if idx >= 0 then
        begin
          while idx > High(Voxels) do AddVoxel;
          if cmd = '/strata/geometry/voxelDefinition' then
          begin
            Voxels[idx].SizeX := StrataTextToNum(WordAt(w, 2), 0);
            Voxels[idx].SizeY := StrataTextToNum(WordAt(w, 3), 0);
            Voxels[idx].SizeZ := StrataTextToNum(WordAt(w, 4), 0);
            if WordAt(w, 5) <> '' then Voxels[idx].SizeUnit := WordAt(w, 5);
          end
          else
          begin
            Voxels[idx].PosX := StrataTextToNum(WordAt(w, 2), 0);
            Voxels[idx].PosY := StrataTextToNum(WordAt(w, 3), 0);
            Voxels[idx].PosZ := StrataTextToNum(WordAt(w, 4), 0);
            if WordAt(w, 5) <> '' then Voxels[idx].PosUnit := WordAt(w, 5);
          end;
        end;
      end

      else if cmd = '/strata/files/savePrimaries' then
        SavePrimaries := (WordAt(w, 1) = '') or SameText(WordAt(w, 1), 'true') or (WordAt(w, 1) = '1')

      else if cmd = '/strata/files/saveCascades' then
        SaveCascades := (WordAt(w, 1) = '') or SameText(WordAt(w, 1), 'true') or (WordAt(w, 1) = '1')

      else if cmd = '/strata/files/setPrimariesName' then
      begin
        if WordAt(w, 1) <> '' then PrimariesName := WordAt(w, 1);
      end

      else if cmd = '/strata/files/setCascadesName' then
      begin
        if WordAt(w, 1) <> '' then CascadesName := WordAt(w, 1);
      end

      else if cmd = '/strata/random/engine' then
      begin
        if WordAt(w, 1) <> '' then RandomEngine := WordAt(w, 1);
      end

      else if cmd = '/strata/random/randomize' then
        RandomRandomize := (WordAt(w, 1) = '') or SameText(WordAt(w, 1), 'true') or (WordAt(w, 1) = '1')

      else if (cmd = '/strata/random/seeds') or (cmd = '/random/setSeeds') then
      begin
        RandomSeed1 := StrToInt64Def(WordAt(w, 1), RandomSeed1);
        RandomSeed2 := StrToInt64Def(WordAt(w, 2), RandomSeed2);
        RandomRandomize := False;
      end

      else if cmd = '/strata/BField/setValue' then
      begin
        FieldOn := True;
        FieldBx := StrataTextToNum(WordAt(w, 1), FieldBx);
        FieldBy := StrataTextToNum(WordAt(w, 2), FieldBy);
        FieldBz := StrataTextToNum(WordAt(w, 3), FieldBz);
        if WordAt(w, 4) <> '' then FieldUnit := WordAt(w, 4);
      end

      else if cmd = '/strata/BField/setMinStep' then
      begin
        FieldMinStep := StrataTextToNum(WordAt(w, 1), FieldMinStep);
        if WordAt(w, 2) <> '' then FieldMinStepUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/BField/setStepperType' then
        FieldStepper := StrToIntDef(WordAt(w, 1), FieldStepper)

      // The field is already described by the three commands above, so the
      // update that applies them carries nothing to read
      else if cmd = '/strata/BField/update' then
        FieldOn := True

      else if cmd = '/strata/EField/setValue' then
      begin
        EFieldOn := True;
        EFieldEx := StrataTextToNum(WordAt(w, 1), EFieldEx);
        EFieldEy := StrataTextToNum(WordAt(w, 2), EFieldEy);
        EFieldEz := StrataTextToNum(WordAt(w, 3), EFieldEz);
        if WordAt(w, 4) <> '' then EFieldUnit := WordAt(w, 4);
      end

      else if cmd = '/strata/EField/setMinStep' then
      begin
        EFieldMinStep := StrataTextToNum(WordAt(w, 1), EFieldMinStep);
        if WordAt(w, 2) <> '' then EFieldMinStepUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/EField/setStepperType' then
        EFieldStepper := StrToIntDef(WordAt(w, 1), EFieldStepper)

      else if cmd = '/strata/EField/update' then
        EFieldOn := True

      else if cmd = '/process/em/fluo' then
        EmFluo := TrueWord(WordAt(w, 1))

      else if cmd = '/process/em/auger' then
        EmAuger := TrueWord(WordAt(w, 1))

      else if cmd = '/process/em/augerCascade' then
        EmAugerCascade := TrueWord(WordAt(w, 1))

      else if cmd = '/process/em/pixe' then
        EmPixe := TrueWord(WordAt(w, 1))

      else if cmd = '/process/em/deexcitationIgnoreCut' then
        EmDeexIgnoreCut := TrueWord(WordAt(w, 1))

      else if cmd = '/run/setCut' then
      begin
        CutOn := True;
        Cut := StrataTextToNum(WordAt(w, 1), Cut);
        if WordAt(w, 2) <> '' then CutUnit := WordAt(w, 2);
      end

      else if cmd = '/run/setCutForAGivenParticle' then
      begin
        p := IndexOfCutParticle(WordAt(w, 1));
        if p >= 0 then
        begin
          ParticleCut[p] := StrataTextToNum(WordAt(w, 2), 0);
          if WordAt(w, 3) <> '' then ParticleCutUnit[p] := WordAt(w, 3)
          else ParticleCutUnit[p] := 'mm';
        end;
      end

      else if cmd = '/strata/stepMax' then
      begin
        StepMaxOn := True;
        StepMax := StrataTextToNum(WordAt(w, 1), StepMax);
        if WordAt(w, 2) <> '' then StepMaxUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/stack/killSecondaries' then
        // The parameter is optional and defaults to 1
        if WordAt(w, 1) = '' then KillSecondaries := 1
        else KillSecondaries := StrToIntDef(WordAt(w, 1), 1)

      else if cmd = '/strata/rbs/enable' then
        RBSOn := (WordAt(w, 1) = '') or SameText(WordAt(w, 1), 'true') or (WordAt(w, 1) = '1')

      else if cmd = '/strata/rbs/angle' then
        RBSAngle := StrataTextToNum(WordAt(w, 1), RBSAngle)

      else if cmd = '/strata/rbs/solidAngle' then
      begin
        RBSSolidAngle := StrataTextToNum(WordAt(w, 1), RBSSolidAngle);
        if WordAt(w, 2) <> '' then RBSSolidAngleUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/rbs/resolution' then
      begin
        RBSResolution := StrataTextToNum(WordAt(w, 1), RBSResolution);
        if WordAt(w, 2) <> '' then RBSResolutionUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/rbs/tilt' then
        RBSTilt := StrataTextToNum(WordAt(w, 1), RBSTilt)

      else if cmd = '/strata/rbs/screening' then
        RBSScreening := (WordAt(w, 1) = '') or SameText(WordAt(w, 1), 'true') or (WordAt(w, 1) = '1')

      else if cmd = '/strata/damage/enable' then
        DamageOn := (WordAt(w, 1) = '') or SameText(WordAt(w, 1), 'true') or (WordAt(w, 1) = '1')

      else if (cmd = '/strata/damage/setEd') and (WordAt(w, 1) <> '') then
      begin
        idx := DamageFor(WordAt(w, 1));
        factor := 1;
        if WordAt(w, 3) <> '' then
          factor := StrataUnitFactor(sqEnergy, WordAt(w, 3))/StrataUnitFactor(sqEnergy, 'eV');
        Damage[idx].Ed := StrataTextToNum(WordAt(w, 2), 0)*factor;
      end

      else if (cmd = '/strata/damage/setArc') and (WordAt(w, 1) <> '') then
      begin
        idx := DamageFor(WordAt(w, 1));
        Damage[idx].HasArc := True;
        Damage[idx].ArcB := StrataTextToNum(WordAt(w, 2), 0);
        Damage[idx].ArcC := StrataTextToNum(WordAt(w, 3), 1);
      end

      else if cmd = '/strata/material/create' then
      begin
        matIdx := AddMaterial;
        openMaterial := True;
        Materials[matIdx].Name := WordAt(w, 1);
        Materials[matIdx].Density := StrataTextToNum(WordAt(w, 2), 1);
        if WordAt(w, 3) <> '' then
          Materials[matIdx].DensityUnit := WordAt(w, 3);
      end

      else if (cmd = '/strata/material/addMaterial')
           or (cmd = '/strata/material/addElement')
           or (cmd = '/strata/material/addElementByAtoms') then
      begin
        if openMaterial and (matIdx >= 0) then
        begin
          partIdx := Length(Materials[matIdx].Parts);
          SetLength(Materials[matIdx].Parts, partIdx + 1);
          if cmd = '/strata/material/addMaterial' then
            Materials[matIdx].Parts[partIdx].Kind := 'material'
          else
            Materials[matIdx].Parts[partIdx].Kind := 'element';
          if cmd = '/strata/material/addElementByAtoms' then
            Materials[matIdx].ByAtoms := True;
          Materials[matIdx].Parts[partIdx].Name := WordAt(w, 1);
          Materials[matIdx].Parts[partIdx].Amount := StrataTextToNum(WordAt(w, 2), 0);
        end;
      end

      else if cmd = '/strata/material/build' then
        openMaterial := False

      else if cmd = '/strata/material/cancel' then
      begin
        if openMaterial and (matIdx = High(Materials)) then
          SetLength(Materials, Length(Materials) - 1);
        openMaterial := False;
      end

      else if cmd = '/strata/physics/addPhysics' then
      begin
        // The window writes the base list first and the optional components
        // after it, so that is how they are read back
        if physicsSeen = 0 then
          PhysicsList := WordAt(w, 1)
        else
          OptionalPhysics.Add(WordAt(w, 1));
        Inc(physicsSeen);
      end

      else if cmd = '/gun/particle' then
        Particle := WordAt(w, 1)

      else if cmd = '/gun/ion' then
      begin
        Particle := 'ion';
        IonZ := StrToIntDef(WordAt(w, 1), IonZ);
        IonA := StrToIntDef(WordAt(w, 2), IonA);
        if WordAt(w, 3) <> '' then IonQ := StrToIntDef(WordAt(w, 3), IonQ);
      end

      else if cmd = '/gun/energy' then
      begin
        Energy := StrataTextToNum(WordAt(w, 1), Energy);
        if WordAt(w, 2) <> '' then EnergyUnit := WordAt(w, 2);
      end

      else if cmd = '/strata/gun/rndBeam' then
        BeamRadius := StrataTextToNum(WordAt(w, 1), BeamRadius)

      else if cmd = '/strata/gun/angle' then
        BeamAngle := StrataTextToNum(WordAt(w, 1), BeamAngle)

      else if cmd = '/analysis/setFileName' then
      begin
        OutputFolder := ExtractFilePath(WordAt(w, 1));
        OutputBase := ExtractFileName(WordAt(w, 1));
        if OutputFolder <> '' then
          OutputFolder := ExcludeTrailingPathDelimiter(OutputFolder);
      end

      else if cmd = '/analysis/h1/set' then
      begin
        idx := AddSpectrum;
        Spectra[idx].Id := StrToIntDef(WordAt(w, 1), 0);
        Spectra[idx].Bins := StrToIntDef(WordAt(w, 2), 100);
        Spectra[idx].Min := StrataTextToNum(WordAt(w, 3), 0);
        Spectra[idx].Max := StrataTextToNum(WordAt(w, 4), 1);
        Spectra[idx].Units := WordAt(w, 5);
        Spectra[idx].Fcn := WordAt(w, 6);
        // Geant4 spells "not given" as none in both places
        if SameText(Spectra[idx].Units, 'none') then Spectra[idx].Units := '';
        if SameText(Spectra[idx].Fcn, 'none') then Spectra[idx].Fcn := '';
      end

      else if cmd = '/run/beamOn' then
        Events := StrToInt64Def(WordAt(w, 1), Events)

      else if (cmd = '/run/initialize') or (cmd = '/control/verbose')
           or (cmd = '/run/verbose') then
        // recognised, nothing to store

      else
      begin
        // Not a panel, so it is kept verbatim rather than thrown away
        Commands[lineStage].Add(line);
        if AUnknown <> nil then AUnknown.Add(line);
        Continue;
      end;

      Inc(Result);
    end;
  finally
    w.Free;
    lines.Free;
  end;
end;

initialization
  CfgFmt := DefaultFormatSettings;
  CfgFmt.DecimalSeparator := '.';
  CfgFmt.ThousandSeparator := #0;

end.
