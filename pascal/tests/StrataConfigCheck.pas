{==============================================================================
  StrataConfigCheck.pas: round-trips a configuration through both file formats.

  Writes a fully populated set-up as XML and as a Geant4 macro, reads each
  back, and compares the result field by field.  Needs neither a backend nor
  a display: TStrataConfig is plain data, which is the reason it lives
  outside the form.

      build/StrataConfigCheck [directory for the scratch files]
==============================================================================}

program StrataConfigCheck;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Math, uStrataConfig, uStrataDatasets, uStrataFetch;

var
  Failures: Integer = 0;
  Checks: Integer = 0;

// The dataset probe tree, removed before it is built as well as after: a
// leftover file from an earlier run would make the directory look like an
// installed dataset and the test would pass for the wrong reason
procedure ScrubDatasetProbe(const ABase, ADir: string);
begin
  DeleteFile(ABase + PathDelim + ADir + PathDelim + 'data.txt');
  RemoveDir(ABase + PathDelim + ADir + PathDelim + 'sub');
  RemoveDir(ABase + PathDelim + ADir);
  RemoveDir(ABase);
end;

procedure Check(const AWhat: string; ACondition: Boolean; const AGot: string = '');
begin
  Inc(Checks);
  if ACondition then Exit;
  Inc(Failures);
  if AGot <> '' then
    WriteLn('FAILED  ', AWhat, '  (got ', AGot, ')')
  else
    WriteLn('FAILED  ', AWhat);
end;

procedure CheckStr(const AWhat, AExpected, AGot: string);
begin
  Check(AWhat + ' = ' + AExpected, AExpected = AGot, AGot);
end;

procedure CheckInt(const AWhat: string; AExpected, AGot: Int64);
begin
  Check(Format('%s = %d', [AWhat, AExpected]), AExpected = AGot,
    IntToStr(AGot));
end;

procedure CheckNum(const AWhat: string; AExpected, AGot: Double);
begin
  Check(Format('%s = %.6g', [AWhat, AExpected]), Abs(AExpected - AGot) < 1e-9,
    StrataNumToText(AGot));
end;

{ The set-up every round trip starts from. }
function MakeReference: TStrataConfig;
var
  c: TStrataConfig;
  i: Integer;
begin
  c := TStrataConfig.Create;
  c.Threads := 4;

  c.SizeYZ := 2.5;
  c.SizeUnit := 'cm';
  c.WorldMaterial := 'G4_Galactic';
  c.SetLayerCount(3);
  c.Layers[0].Thickness := 500; c.Layers[0].Units := 'nm';
  c.Layers[0].Material := 'SiliconNitride';
  c.Layers[1].Thickness := 20.5; c.Layers[1].Units := 'um';
  c.Layers[1].Material := 'Borosilicate';
  c.Layers[2].Thickness := 1;    c.Layers[2].Units := 'mm';
  c.Layers[2].Material := 'G4_Si';
  // One layer with its density overridden and one without, so both branches of
  // the optional density are exercised
  c.Layers[1].Density := 2.32; c.Layers[1].DensityUnit := 'g/cm3';

  i := c.AddMaterial;
  c.Materials[i].Name := 'Borosilicate';
  c.Materials[i].Density := 2.23;
  c.Materials[i].DensityUnit := 'g/cm3';
  c.Materials[i].ByAtoms := False;
  SetLength(c.Materials[i].Parts, 2);
  c.Materials[i].Parts[0].Kind := 'material';
  c.Materials[i].Parts[0].Name := 'G4_SILICON_DIOXIDE';
  c.Materials[i].Parts[0].Amount := 0.81;
  c.Materials[i].Parts[1].Kind := 'element';
  c.Materials[i].Parts[1].Name := 'B';
  c.Materials[i].Parts[1].Amount := 0.19;

  i := c.AddMaterial;
  c.Materials[i].Name := 'SiliconNitride';
  c.Materials[i].Density := 3.17;
  c.Materials[i].DensityUnit := 'g/cm3';
  c.Materials[i].ByAtoms := True;
  SetLength(c.Materials[i].Parts, 2);
  c.Materials[i].Parts[0].Kind := 'element';
  c.Materials[i].Parts[0].Name := 'Si';
  c.Materials[i].Parts[0].Amount := 3;
  c.Materials[i].Parts[1].Kind := 'element';
  c.Materials[i].Parts[1].Name := 'N';
  c.Materials[i].Parts[1].Amount := 4;

  i := c.AddVoxel;
  c.Voxels[i].SizeX := 0.5;  c.Voxels[i].SizeY := 200;
  c.Voxels[i].SizeZ := 200;  c.Voxels[i].SizeUnit := 'um';
  c.Voxels[i].PosX := -9.75; c.Voxels[i].PosY := 0;
  c.Voxels[i].PosZ := 0;     c.Voxels[i].PosUnit := 'um';
  i := c.AddVoxel;
  c.Voxels[i].SizeX := 2;    c.Voxels[i].SizeY := 0.2;
  c.Voxels[i].SizeZ := 0.2;  c.Voxels[i].SizeUnit := 'mm';
  c.Voxels[i].PosX := 0.125; c.Voxels[i].PosY := -0.05;
  c.Voxels[i].PosZ := 0.05;  c.Voxels[i].PosUnit := 'mm';

  c.SavePrimaries := True;
  c.SaveCascades := True;
  c.PrimariesName := 'run42-primaries.txt';
  c.CascadesName := 'run42-cascades.txt';

  c.RandomEngine := 'mixmax';
  c.RandomRandomize := False;
  c.RandomSeed1 := 987654321;
  c.RandomSeed2 := 123456789;

  // A field in every component, with a unit that is not the default, so a
  // round trip that dropped the unit or a component would show
  c.FieldOn := True;
  c.FieldBx := 0.25;
  c.FieldBy := -1.5;
  c.FieldBz := 5;
  c.FieldUnit := 'T';
  c.FieldMinStep := 0.5;
  c.FieldMinStepUnit := 'um';
  c.FieldStepper := 4;

  c.Particle := 'ion';
  c.IonZ := 18; c.IonA := 40; c.IonQ := -1;
  c.Energy := 1.75;
  c.EnergyUnit := 'MeV';
  c.BeamRadius := 0.25;
  c.Events := 50000;

  c.PhysicsList := 'standardNR';
  c.OptionalPhysics.Add('elastic');
  c.OptionalPhysics.Add('stopping');

  i := c.AddSpectrum;
  c.Spectra[i].Id := 1; c.Spectra[i].Bins := 50;
  c.Spectra[i].Min := 0; c.Spectra[i].Max := 20.5; c.Spectra[i].Units := 'um';
  i := c.AddSpectrum;
  c.Spectra[i].Id := 2; c.Spectra[i].Bins := 100;
  c.Spectra[i].Min := 0; c.Spectra[i].Max := 20.5; c.Spectra[i].Units := 'um';

  c.OutputBase := 'case-ion';
  // Persisted in both the .scf and the macro but, until this line, compared
  // by nothing: the one field of the record the suite never looked at
  c.OutputFolder := 'results';
  c.BeamAngle := -7.5;
  c.Temperature := 77;
  Result := c;
end;

{ A length survives a round trip as a PHYSICAL quantity, not as a spelling:
  the macro writes every length in the problem's own unit, so a configuration
  mixing nm, um and cm comes back in one of them.  500 nm and 0.0005 mm are
  the same length and both are correct. }
procedure CheckLength(const AWhat: String; ARefValue: Double;
  const ARefUnit: String; AGotValue: Double; const AGotUnit: String);
var
  a, b: Double;
begin
  a := ARefValue * StrataUnitFactor(sqLength, ARefUnit);
  b := AGotValue * StrataUnitFactor(sqLength, AGotUnit);
  Check(Format('%s = %s %s', [AWhat, StrataNumToText(AGotValue), AGotUnit]),
    Abs(a - b) <= 1e-9 * Max(1, Abs(a)));
end;

{ Everything both formats are expected to carry. }
{ AAll compares the groups that are normally only looked at when their
  flag is set.  Reset needs that: a fresh configuration has every flag off,
  so the guards would skip exactly the fields a forgotten line in Clear
  leaves behind -- which is how a deliberately broken Clear first passed
  this suite. }
procedure Compare(const AVia: string; ARef, AGot: TStrataConfig;
                  AAll: Boolean = False);
var
  i, p, q: Integer;
  stage: TStrataStage;
begin
  for stage := Low(TStrataStage) to High(TStrataStage) do
    CheckStr(AVia + ': commands for ' + StrataStageName[stage],
      Trim(ARef.Commands[stage].Text), Trim(AGot.Commands[stage].Text));

  CheckInt(AVia + ': threads', ARef.Threads, AGot.Threads);
  CheckLength(AVia + ': transverse size', ARef.SizeYZ, ARef.SizeUnit,
    AGot.SizeYZ, AGot.SizeUnit);
  CheckStr(AVia + ': world material', ARef.WorldMaterial, AGot.WorldMaterial);

  CheckInt(AVia + ': layer count', Length(ARef.Layers), Length(AGot.Layers));
  if Length(ARef.Layers) = Length(AGot.Layers) then
    for i := 0 to High(ARef.Layers) do
    begin
      CheckLength(Format('%s: layer %d thickness', [AVia, i]),
        ARef.Layers[i].Thickness, ARef.Layers[i].Units,
        AGot.Layers[i].Thickness, AGot.Layers[i].Units);
      CheckStr(Format('%s: layer %d material', [AVia, i]),
        ARef.Layers[i].Material, AGot.Layers[i].Material);
      CheckNum(Format('%s: layer %d density', [AVia, i]),
        ARef.Layers[i].Density, AGot.Layers[i].Density);
      if ARef.Layers[i].Density > 0 then
        CheckStr(Format('%s: layer %d density unit', [AVia, i]),
          ARef.Layers[i].DensityUnit, AGot.Layers[i].DensityUnit);
    end;

  CheckInt(AVia + ': material count', Length(ARef.Materials),
    Length(AGot.Materials));
  if Length(ARef.Materials) = Length(AGot.Materials) then
    for i := 0 to High(ARef.Materials) do
    begin
      CheckStr(Format('%s: material %d name', [AVia, i]),
        ARef.Materials[i].Name, AGot.Materials[i].Name);
      CheckNum(Format('%s: material %d density', [AVia, i]),
        ARef.Materials[i].Density, AGot.Materials[i].Density);
      CheckStr(Format('%s: material %d density unit', [AVia, i]),
        ARef.Materials[i].DensityUnit, AGot.Materials[i].DensityUnit);
      Check(Format('%s: material %d composition mode', [AVia, i]),
        ARef.Materials[i].ByAtoms = AGot.Materials[i].ByAtoms);
      CheckInt(Format('%s: material %d constituents', [AVia, i]),
        Length(ARef.Materials[i].Parts), Length(AGot.Materials[i].Parts));
      if Length(ARef.Materials[i].Parts) = Length(AGot.Materials[i].Parts) then
        for p := 0 to High(ARef.Materials[i].Parts) do
        begin
          CheckStr(Format('%s: material %d part %d kind', [AVia, i, p]),
            ARef.Materials[i].Parts[p].Kind, AGot.Materials[i].Parts[p].Kind);
          CheckStr(Format('%s: material %d part %d name', [AVia, i, p]),
            ARef.Materials[i].Parts[p].Name, AGot.Materials[i].Parts[p].Name);
          CheckNum(Format('%s: material %d part %d amount', [AVia, i, p]),
            ARef.Materials[i].Parts[p].Amount,
            AGot.Materials[i].Parts[p].Amount);
        end;
    end;

  CheckInt(AVia + ': voxel count', Length(ARef.Voxels), Length(AGot.Voxels));
  if Length(ARef.Voxels) = Length(AGot.Voxels) then
    for i := 0 to High(ARef.Voxels) do
    begin
      CheckLength(Format('%s: voxel %d sizeX', [AVia, i]),
        ARef.Voxels[i].SizeX, ARef.Voxels[i].SizeUnit,
        AGot.Voxels[i].SizeX, AGot.Voxels[i].SizeUnit);
      CheckLength(Format('%s: voxel %d sizeY', [AVia, i]),
        ARef.Voxels[i].SizeY, ARef.Voxels[i].SizeUnit,
        AGot.Voxels[i].SizeY, AGot.Voxels[i].SizeUnit);
      CheckLength(Format('%s: voxel %d sizeZ', [AVia, i]),
        ARef.Voxels[i].SizeZ, ARef.Voxels[i].SizeUnit,
        AGot.Voxels[i].SizeZ, AGot.Voxels[i].SizeUnit);
      CheckLength(Format('%s: voxel %d posX', [AVia, i]),
        ARef.Voxels[i].PosX, ARef.Voxels[i].PosUnit,
        AGot.Voxels[i].PosX, AGot.Voxels[i].PosUnit);
      CheckLength(Format('%s: voxel %d posY', [AVia, i]),
        ARef.Voxels[i].PosY, ARef.Voxels[i].PosUnit,
        AGot.Voxels[i].PosY, AGot.Voxels[i].PosUnit);
      CheckLength(Format('%s: voxel %d posZ', [AVia, i]),
        ARef.Voxels[i].PosZ, ARef.Voxels[i].PosUnit,
        AGot.Voxels[i].PosZ, AGot.Voxels[i].PosUnit);
    end;

  Check(AVia + ': save primaries', ARef.SavePrimaries = AGot.SavePrimaries);
  Check(AVia + ': save cascades', ARef.SaveCascades = AGot.SaveCascades);
  CheckStr(AVia + ': primaries file', ARef.PrimariesName, AGot.PrimariesName);
  CheckStr(AVia + ': cascades file', ARef.CascadesName, AGot.CascadesName);

  CheckStr(AVia + ': random engine', ARef.RandomEngine, AGot.RandomEngine);
  Check(AVia + ': seeding mode',
    ARef.RandomRandomize = AGot.RandomRandomize);
  CheckInt(AVia + ': seed 1', ARef.RandomSeed1, AGot.RandomSeed1);
  { A field that is off is not written, so only its flag survives }
  Check(AVia + ': field on', ARef.FieldOn = AGot.FieldOn);
  if ARef.FieldOn or AAll then
  begin
    CheckNum(AVia + ': field Bx', ARef.FieldBx, AGot.FieldBx);
    CheckNum(AVia + ': field By', ARef.FieldBy, AGot.FieldBy);
    CheckNum(AVia + ': field Bz', ARef.FieldBz, AGot.FieldBz);
    CheckStr(AVia + ': field unit', ARef.FieldUnit, AGot.FieldUnit);
    CheckNum(AVia + ': field minimum step', ARef.FieldMinStep, AGot.FieldMinStep);
    CheckStr(AVia + ': field step unit', ARef.FieldMinStepUnit, AGot.FieldMinStepUnit);
    CheckInt(AVia + ': field stepper', ARef.FieldStepper, AGot.FieldStepper);
  end;
  CheckInt(AVia + ': seed 2', ARef.RandomSeed2, AGot.RandomSeed2);

  CheckStr(AVia + ': particle', ARef.Particle, AGot.Particle);
  CheckInt(AVia + ': ion Z', ARef.IonZ, AGot.IonZ);
  CheckInt(AVia + ': ion A', ARef.IonA, AGot.IonA);
  CheckInt(AVia + ': ion charge', ARef.IonQ, AGot.IonQ);
  CheckNum(AVia + ': energy', ARef.Energy, AGot.Energy);
  CheckStr(AVia + ': energy unit', ARef.EnergyUnit, AGot.EnergyUnit);
  CheckNum(AVia + ': beam radius', ARef.BeamRadius, AGot.BeamRadius);
  CheckInt(AVia + ': events', ARef.Events, AGot.Events);

  CheckStr(AVia + ': physics list', ARef.PhysicsList, AGot.PhysicsList);
  CheckStr(AVia + ': optional physics', ARef.OptionalPhysics.CommaText,
    AGot.OptionalPhysics.CommaText);

  CheckInt(AVia + ': spectrum count', Length(ARef.Spectra),
    Length(AGot.Spectra));
  if Length(ARef.Spectra) = Length(AGot.Spectra) then
    for i := 0 to High(ARef.Spectra) do
    begin
      CheckInt(Format('%s: spectrum %d id', [AVia, i]),
        ARef.Spectra[i].Id, AGot.Spectra[i].Id);
      CheckInt(Format('%s: spectrum %d bins', [AVia, i]),
        ARef.Spectra[i].Bins, AGot.Spectra[i].Bins);
      CheckNum(Format('%s: spectrum %d min', [AVia, i]),
        ARef.Spectra[i].Min, AGot.Spectra[i].Min);
      CheckNum(Format('%s: spectrum %d max', [AVia, i]),
        ARef.Spectra[i].Max, AGot.Spectra[i].Max);
      CheckStr(Format('%s: spectrum %d unit', [AVia, i]),
        ARef.Spectra[i].Units, AGot.Spectra[i].Units);
      CheckStr(Format('%s: spectrum %d binning function', [AVia, i]),
        ARef.Spectra[i].Fcn, AGot.Spectra[i].Fcn);
    end;

  Check(AVia + ': electric field flag', ARef.EFieldOn = AGot.EFieldOn);
  if ARef.EFieldOn or AAll then
  begin
    CheckNum(AVia + ': Ex', ARef.EFieldEx, AGot.EFieldEx);
    CheckNum(AVia + ': Ey', ARef.EFieldEy, AGot.EFieldEy);
    CheckNum(AVia + ': Ez', ARef.EFieldEz, AGot.EFieldEz);
    CheckStr(AVia + ': electric field unit', ARef.EFieldUnit, AGot.EFieldUnit);
    CheckNum(AVia + ': electric minimum step', ARef.EFieldMinStep, AGot.EFieldMinStep);
    CheckStr(AVia + ': electric step unit', ARef.EFieldMinStepUnit,
      AGot.EFieldMinStepUnit);
    CheckInt(AVia + ': electric stepper', ARef.EFieldStepper, AGot.EFieldStepper);
  end;

  Check(AVia + ': RBS flag', ARef.RBSOn = AGot.RBSOn);
  if ARef.RBSOn or AAll then
  begin
    CheckNum(AVia + ': RBS angle', ARef.RBSAngle, AGot.RBSAngle);
    CheckNum(AVia + ': RBS solid angle', ARef.RBSSolidAngle, AGot.RBSSolidAngle);
    CheckStr(AVia + ': RBS solid angle unit', ARef.RBSSolidAngleUnit,
      AGot.RBSSolidAngleUnit);
    CheckNum(AVia + ': RBS resolution', ARef.RBSResolution, AGot.RBSResolution);
    CheckStr(AVia + ': RBS resolution unit', ARef.RBSResolutionUnit,
      AGot.RBSResolutionUnit);
    CheckNum(AVia + ': RBS tilt', ARef.RBSTilt, AGot.RBSTilt);
    Check(AVia + ': RBS screening', ARef.RBSScreening = AGot.RBSScreening);
  end;

  Check(AVia + ': damage flag', ARef.DamageOn = AGot.DamageOn);
  Check(AVia + ': damage materials', Length(ARef.Damage) = Length(AGot.Damage));
  if Length(ARef.Damage) = Length(AGot.Damage) then
    for i := 0 to High(ARef.Damage) do
    begin
      CheckStr(AVia + ': damage material', ARef.Damage[i].Material, AGot.Damage[i].Material);
      CheckNum(AVia + ': damage Ed', ARef.Damage[i].Ed, AGot.Damage[i].Ed);
      CheckStr(AVia + ': damage Ed unit', StrataEdUnit(ARef.Damage[i].EdUnit), StrataEdUnit(AGot.Damage[i].EdUnit));
      Check(AVia + ': damage has arc', ARef.Damage[i].HasArc = AGot.Damage[i].HasArc);
      if ARef.Damage[i].HasArc or AAll then
      begin
        CheckNum(AVia + ': damage b', ARef.Damage[i].ArcB, AGot.Damage[i].ArcB);
        CheckNum(AVia + ': damage c', ARef.Damage[i].ArcC, AGot.Damage[i].ArcC);
      end;
    end;

  Check(AVia + ': fluorescence', ARef.EmFluo = AGot.EmFluo);
  Check(AVia + ': Auger', ARef.EmAuger = AGot.EmAuger);
  Check(AVia + ': Auger cascade', ARef.EmAugerCascade = AGot.EmAugerCascade);
  Check(AVia + ': PIXE', ARef.EmPixe = AGot.EmPixe);
  Check(AVia + ': de-excitation ignores the cut',
    ARef.EmDeexIgnoreCut = AGot.EmDeexIgnoreCut);

  Check(AVia + ': cut flag', ARef.CutOn = AGot.CutOn);
  if ARef.CutOn or AAll then
  begin
    CheckNum(AVia + ': cut', ARef.Cut, AGot.Cut);
    CheckStr(AVia + ': cut unit', ARef.CutUnit, AGot.CutUnit);
  end;
  for q := 0 to High(ARef.ParticleCut) do
  begin
    CheckStr(AVia + ': ' + kCutParticles[q] + ' cut unit',
      ARef.ParticleCutUnit[q], AGot.ParticleCutUnit[q]);
    if (ARef.ParticleCutUnit[q] <> '') or AAll then
      CheckNum(AVia + ': ' + kCutParticles[q] + ' cut',
        ARef.ParticleCut[q], AGot.ParticleCut[q]);
  end;

  Check(AVia + ': step limit flag', ARef.StepMaxOn = AGot.StepMaxOn);
  if ARef.StepMaxOn or AAll then
  begin
    CheckNum(AVia + ': step limit', ARef.StepMax, AGot.StepMax);
    CheckStr(AVia + ': step limit unit', ARef.StepMaxUnit, AGot.StepMaxUnit);
  end;
  CheckInt(AVia + ': killSecondaries', ARef.KillSecondaries, AGot.KillSecondaries);
  if True then
  begin
  end;

  CheckStr(AVia + ': output file name', ARef.OutputBase, AGot.OutputBase);
  CheckStr(AVia + ': output folder', ARef.OutputFolder, AGot.OutputFolder);
  CheckNum(AVia + ': beam angle', ARef.BeamAngle, AGot.BeamAngle);
  CheckNum(AVia + ': target temperature', ARef.Temperature, AGot.Temperature);
end;

var
  dir, xmlFile, macFile: string;
  ref, back, first, fresh: TStrataConfig;
  unknown, macro: TStringList;
  recognised: Integer;
  i, nRequired, j, nMacros, kept: Integer;
  hex: Boolean;
  probe, macroDir: String;
  stage: TStrataStage;
  sr: TSearchRec;
begin
  dir := ParamStr(1);
  if dir = '' then dir := GetTempDir;
  dir := IncludeTrailingPathDelimiter(dir);
  xmlFile := dir + 'strata-config-check.xml';
  macFile := dir + 'strata-config-check.mac';

  ref := MakeReference;
  unknown := TStringList.Create;
  macro := TStringList.Create;
  try
    { --- XML --------------------------------------------------------- }
    ref.SaveToXML(xmlFile);
    Check('the XML file was written', FileExists(xmlFile));
    back := TStrataConfig.Create;
    try
      back.LoadFromXML(xmlFile);
      Compare('xml', ref, back);
    finally
      back.Free;
    end;

    { --- macro ------------------------------------------------------- }
    ref.SaveToMacro(macFile);
    Check('the macro was written', FileExists(macFile));
    macro.LoadFromFile(macFile);
    Check('the macro initialises before the beam is set',
      macro.IndexOf('/run/initialize') > 0);

    back := TStrataConfig.Create;
    try
      recognised := back.LoadFromMacro(macFile, unknown);
      Check(Format('every command in the macro was understood (%d read, '
        + '%d not)', [recognised, unknown.Count]), unknown.Count = 0);
      if unknown.Count > 0 then
        WriteLn('        first unrecognised: ', unknown[0]);
      Compare('macro', ref, back);
    finally
      back.Free;
    end;

    { --- the macro has to be reproducible ---------------------------- }
    back := TStrataConfig.Create;
    try
      back.LoadFromMacro(macFile, nil);
      back.SaveToMacro(macFile + '.2');
      macro.LoadFromFile(macFile);
      unknown.LoadFromFile(macFile + '.2');
      { the header carries a timestamp, so compare everything below it }
      while (macro.Count > 0) and (Pos('/', macro[0]) <> 1) do macro.Delete(0);
      while (unknown.Count > 0) and (Pos('/', unknown[0]) <> 1) do unknown.Delete(0);
      Check('writing the macro again gives the same commands',
        macro.Text = unknown.Text);
      DeleteFile(macFile + '.2');
    finally
      back.Free;
    end;

    { --- the electric field, which excludes the magnetic one ----------

      Both setups install themselves on the one global field manager, so a
      configuration may carry one or the other.  The reference carries a
      magnetic field, so the electric one is round-tripped on its own. }
    ref.FieldOn := False;
    ref.EFieldOn := True;
    ref.EFieldEx := 12.5;
    ref.EFieldEy := -3;
    ref.EFieldEz := 400;
    ref.EFieldUnit := 'kV/m';
    ref.EFieldMinStep := 2.5;
    ref.EFieldMinStepUnit := 'um';
    ref.EFieldStepper := 5;
    ref.SaveToXML(xmlFile);
    back := TStrataConfig.Create;
    try
      back.LoadFromXML(xmlFile);
      Compare('xml efield', ref, back);
    finally
      back.Free;
    end;
    ref.SaveToMacro(macFile);
    macro.LoadFromFile(macFile);
    Check('the macro sets the electric field',
      macro.IndexOf('/strata/EField/update') > 0);
    Check('and not the magnetic one as well',
      macro.IndexOf('/strata/BField/update') < 0);
    back := TStrataConfig.Create;
    try
      recognised := back.LoadFromMacro(macFile, unknown);
      Compare('macro efield', ref, back);
    finally
      back.Free;
    end;
    ref.EFieldOn := False;
    ref.FieldOn := True;

    { --- the backscattering detector --- }
    ref.RBSOn := True;
    ref.RBSAngle := 170;
    ref.RBSSolidAngle := 2.4;
    ref.RBSSolidAngleUnit := 'msr';
    ref.RBSResolution := 18;
    ref.RBSResolutionUnit := 'keV';
    ref.RBSTilt := 7;
    ref.RBSScreening := False;
    ref.SaveToXML(xmlFile);
    back := TStrataConfig.Create;
    try
      back.LoadFromXML(xmlFile);
      Compare('xml rbs', ref, back);
    finally
      back.Free;
    end;
    ref.SaveToMacro(macFile);
    macro.LoadFromFile(macFile);
    Check('the macro turns the detector on',
      macro.IndexOf('/strata/rbs/enable true') > 0);
    Check('and says so when screening is off',
      macro.IndexOf('/strata/rbs/screening false') > 0);
    back := TStrataConfig.Create;
    try
      recognised := back.LoadFromMacro(macFile, unknown);
      Compare('macro rbs', ref, back);
    finally
      back.Free;
    end;
    ref.RBSOn := False;

    { --- displacement damage: one material with arc constants, one without,
      the second given in keV to check the conversion on the way in --- }
    ref.DamageOn := True;
    i := ref.DamageFor('Alloy');
    ref.Damage[i].Ed := 44.3;
    ref.Damage[i].HasArc := True;
    ref.Damage[i].ArcB := -0.56;
    ref.Damage[i].ArcC := 0.12;
    i := ref.DamageFor('G4_Si');
    ref.Damage[i].Ed := 15;
    // Shown and written in keV, still kept in eV
    ref.Damage[i].EdUnit := 'keV';
    ref.SaveToXML(xmlFile);
    back := TStrataConfig.Create;
    try
      back.LoadFromXML(xmlFile);
      Compare('xml damage', ref, back);
    finally
      back.Free;
    end;
    ref.SaveToMacro(macFile);
    back := TStrataConfig.Create;
    try
      recognised := back.LoadFromMacro(macFile, unknown);
      Compare('macro damage', ref, back);
    finally
      back.Free;
    end;
    macro.Clear;
    macro.Add('/strata/damage/setEd G4_Si 0.015 keV');
    macro.SaveToFile(macFile);
    back := TStrataConfig.Create;
    try
      back.LoadFromMacro(macFile, unknown);
      Check('Ed given in keV is kept in eV',
            (Length(back.Damage) = 1) and (Abs(back.Damage[0].Ed - 15) < 1e-9));
      Check('Ed keeps the unit it was given in',
            (Length(back.Damage) = 1) and (back.Damage[0].EdUnit = 'keV'));
    finally
      back.Free;
    end;
    { A disabled table is still a table: it survives without the flag }
    ref.DamageOn := False;
    ref.SaveToXML(xmlFile);
    back := TStrataConfig.Create;
    try
      back.LoadFromXML(xmlFile);
      Compare('xml damage off', ref, back);
    finally
      back.Free;
    end;
    { Left set, so that the reset below has a table to clear }
    ref.DamageOn := True;

    { --- de-excitation, cuts and the tracking limits ---

      These are the commands pixe.mac carried and the panels had nowhere to
      put, so they were kept as free text.  Now they have fields, and the
      point of this block is that the fields survive both files. }
    ref.EmFluo := True;
    ref.EmAuger := True;
    ref.EmAugerCascade := True;
    ref.EmPixe := True;
    ref.EmDeexIgnoreCut := True;
    ref.CutOn := True;
    ref.Cut := 1.5;
    ref.CutUnit := 'um';
    ref.ParticleCut[0] := 2.25;      // gamma, the one the macros override
    ref.ParticleCutUnit[0] := 'mm';
    ref.ParticleCut[2] := 13;        // e+, to prove the name survives XML
    ref.ParticleCutUnit[2] := 'um';
    ref.StepMaxOn := True;
    ref.StepMax := 10;
    ref.StepMaxUnit := 'nm';
    ref.KillSecondaries := 2;
    ref.SaveToXML(xmlFile);
    back := TStrataConfig.Create;
    try
      back.LoadFromXML(xmlFile);
      Compare('xml options', ref, back);
    finally
      back.Free;
    end;
    ref.SaveToMacro(macFile);
    macro.LoadFromFile(macFile);
    Check('the macro asks for PIXE',
      macro.IndexOf('/process/em/pixe true') > 0);
    Check('and sets the gamma cut by name',
      macro.IndexOf('/run/setCutForAGivenParticle gamma 2.25 mm') > 0);
    Check('and kills secondaries with its number',
      macro.IndexOf('/strata/stack/killSecondaries 2') > 0);
    Check('and puts the step limit after /run/initialize',
      macro.IndexOf('/strata/stepMax 10 nm') > macro.IndexOf('/run/initialize'));
    back := TStrataConfig.Create;
    try
      recognised := back.LoadFromMacro(macFile, unknown);
      Compare('macro options', ref, back);
    finally
      back.Free;
    end;
    { --- Clear has to leave nothing behind ---

      ref is carrying every field the round trips above set, so clearing it
      and comparing against a configuration that was never touched is an
      exhaustive check on reset: a field Clear forgets shows up as a
      difference.  The written form is compared as well, because it covers
      the whole record without anyone having to keep a list of fields, and
      the list is exactly the thing that goes stale when a field is added. }
    ref.Clear;
    fresh := TStrataConfig.Create;
    try
      Compare('reset', fresh, ref, True);
      CheckStr('reset leaves the written form of a new configuration',
               fresh.ToText, ref.ToText);
    finally
      fresh.Free;
    end;

    { --- every macro in the tree survives being imported and written ---

      This is the check that would have caught the complaint it was written
      for: pixe.mac lost /run/setCut and the three /process/em switches on
      import, so the spectra it exists to produce came out empty.  Nothing
      the panels do not cover may be dropped, and writing the file again has
      to give a configuration that reads back the same. }
    { Run from the repository root, or from pascal/tests, or from a build
      directory beside either: look up from both places rather than
      assuming one }
    macroDir := '';
    for j := 0 to 1 do
    begin
      if j = 0 then probe := IncludeTrailingPathDelimiter(GetCurrentDir)
      else probe := ExtractFilePath(ExpandFileName(ParamStr(0)));
      for i := 0 to 4 do
      begin
        if DirectoryExists(probe + 'macros') then
        begin
          macroDir := IncludeTrailingPathDelimiter(probe + 'macros');
          Break;
        end;
        probe := probe + '..' + PathDelim;
      end;
      if macroDir <> '' then Break;
    end;
    if macroDir = '' then
      WriteLn('  NOTE: no macros directory beside the test, skipping the sweep')
    else
    begin
      nMacros := 0;
      if FindFirst(macroDir + '*.mac', faAnyFile, sr) = 0 then
      begin
        repeat
          Inc(nMacros);
          first := TStrataConfig.Create;
          back := TStrataConfig.Create;
          try
            unknown.Clear;
            first.LoadFromMacro(macroDir + sr.Name, unknown);
            kept := 0;
            for stage := Low(TStrataStage) to High(TStrataStage) do
              Inc(kept, first.Commands[stage].Count);
            Check(sr.Name + ': every line a panel does not cover is kept',
                  kept = unknown.Count,
                  Format('%d of %d', [kept, unknown.Count]));
            first.SaveToMacro(macFile + '.rt');
            back.LoadFromMacro(macFile + '.rt', nil);
            { A macro that fires several beams collapses to its last one, and
              the ion triple of an earlier beam is then inert: /gun/ion is
              only written when the particle is an ion, and Geant4 refuses it
              otherwise.  Compare what the configuration actually uses. }
            if not SameText(first.Particle, 'ion') then
            begin
              first.IonZ := 0; first.IonA := 0; first.IonQ := 0;
              back.IonZ := 0; back.IonA := 0; back.IonQ := 0;
            end;
            Check(sr.Name + ': reads back the same after being written',
                  first.ToText = back.ToText);
            DeleteFile(macFile + '.rt');
          finally
            first.Free;
            back.Free;
          end;
        until FindNext(sr) <> 0;
        FindClose(sr);
      end;
      Check('the macros directory was found', nMacros > 0, IntToStr(nMacros));
      WriteLn(Format('  %d macros imported and written back', [nMacros]));
    end;

    { --- the spellings that differ between the two vocabularies ------ }
    CheckStr('micro sign becomes u', 'um', StrataG4UnitSpelling('µm'));
    CheckStr('angstrom becomes Ang', 'Ang', StrataG4UnitSpelling('Å'));
    CheckStr('the caret goes', 'g/cm3', StrataG4UnitSpelling('g/cm^3'));
    CheckStr('an ASCII unit is left alone', 'MeV', StrataG4UnitSpelling('MeV'));
    CheckStr('surrounding space is trimmed', 'cm', StrataG4UnitSpelling('  cm '));

    { --- the units offered, and the problem's own unit among them ----- }
    CheckStr('the lengths offered', 'nm um mm cm m km',
      StrataUnitsOffered(sqLength));
    CheckStr('the energies offered', 'eV keV MeV GeV',
      StrataUnitsOffered(sqEnergy));
    CheckStr('one density unit is enough', 'g/cm3',
      StrataUnitsOffered(sqDensity));
    CheckStr('and one for a flux density', 'T', StrataUnitsOffered(sqField));
    CheckNum('cm is ten mm', 10, StrataUnitFactor(sqLength, 'cm'));
    CheckNum('the caret spelling is accepted too', 1,
      StrataUnitFactor(sqDensity, 'g/cm^3'));
    CheckNum('a unit not offered gives zero', 0,
      StrataUnitFactor(sqLength, 'Ang'));
    CheckNum('and so does one from another quantity', 0,
      StrataUnitFactor(sqEnergy, 'cm'));

    { A problem is written in one unit, and it is read off the problem.  The
      values here are in millimetres, the reference unit for a length. }
    CheckStr('a 5/20/100 nm multilayer is a problem in nm', 'nm',
      StrataProblemUnit(sqLength, [5e-6, 2e-5, 1e-4]));
    CheckStr('a 0.5/2/10 um stack is a problem in um', 'um',
      StrataProblemUnit(sqLength, [5e-4, 2e-3, 1e-2]));
    CheckStr('a 2/5 cm beam stop is a problem in cm', 'cm',
      StrataProblemUnit(sqLength, [20, 50]));
    CheckStr('a 2/3 m block is a problem in m', 'm',
      StrataProblemUnit(sqLength, [2e3, 3e3]));
    CheckStr('zeroes carry no scale and are ignored', 'nm',
      StrataProblemUnit(sqLength, [0, 5e-6, 0]));
    CheckStr('an all-zero set falls back to the reference unit', 'mm',
      StrataProblemUnit(sqLength, [0, 0]));
    CheckStr('and so does an empty one', 'mm', StrataProblemUnit(sqLength, []));
    CheckStr('a 10 keV beam is a problem in keV', 'keV',
      StrataProblemUnit(sqEnergy, [1e-2]));
    CheckStr('a 3 MeV beam is a problem in MeV', 'MeV',
      StrataProblemUnit(sqEnergy, [3]));
    { Nothing has to come out at 1e25 or 1e-25, which is the whole point }
    CheckStr('a density needs no choosing', 'g/cm3',
      StrataProblemUnit(sqDensity, [2.32]));
    CheckStr('nor does a field', 'T', StrataProblemUnit(sqField, [5e-5]));

    { --- the Geant4 dataset table and what reads it ------------------- }
    Check('twelve datasets are listed', kStrataDatasetCount = 12,
          IntToStr(kStrataDatasetCount));
    nRequired := 0;
    for i := 0 to kStrataDatasetCount - 1 do
    begin
      if kStrataDatasets[i].Required then Inc(nRequired);
      Check('dataset ' + IntToStr(i) + ' has a directory',
            kStrataDatasets[i].Directory <> '');
      Check('dataset ' + kStrataDatasets[i].Directory + ' has a variable',
            Copy(kStrataDatasets[i].Variable, 1, 2) = 'G4');
      Check('dataset ' + kStrataDatasets[i].Directory + ' has a .tar.gz',
            Copy(kStrataDatasets[i].Archive, Length(kStrataDatasets[i].Archive) - 6, 7)
            = '.tar.gz', kStrataDatasets[i].Archive);
      Check('dataset ' + kStrataDatasets[i].Directory + ' has a 32-digit checksum',
            Length(kStrataDatasets[i].MD5) = 32, kStrataDatasets[i].MD5);
      hex := True;
      for j := 1 to Length(kStrataDatasets[i].MD5) do
        if not (kStrataDatasets[i].MD5[j] in ['0'..'9', 'a'..'f', 'A'..'F']) then
          hex := False;
      Check('and it is hexadecimal', hex, kStrataDatasets[i].MD5);
    end;
    { The same seven the backend's own table marks, and the installers select }
    Check('seven of them are required', nRequired = 7, IntToStr(nRequired));

    { A directory holding nothing but subdirectories is the shared parent of
      all twelve, not a dataset.  Reporting that as installed would tell the
      user everything is there and then let Geant4 abort, which is the same
      trap the backend's HoldsDataset() avoids. }
    probe := IncludeTrailingPathDelimiter(GetTempDir) + 'strata-dataset-check';
    ScrubDatasetProbe(probe, kStrataDatasets[0].Directory);
    ForceDirectories(probe + PathDelim + kStrataDatasets[0].Directory);
    Check('a dataset directory that is not there is not present',
          not StrataDatasetPresent(probe + 'nowhere', kStrataDatasets[0]));
    Check('a directory holding only subdirectories is not a dataset',
          not StrataDatasetPresent(probe, kStrataDatasets[0]));
    ForceDirectories(probe + PathDelim + kStrataDatasets[0].Directory
                     + PathDelim + 'sub');
    Check('nor is one holding only a subdirectory of its own',
          not StrataDatasetPresent(probe, kStrataDatasets[0]));
    with TStringList.Create do
      try
        Add('x');
        SaveToFile(probe + PathDelim + kStrataDatasets[0].Directory
                   + PathDelim + 'data.txt');
      finally
        Free;
      end;
    Check('one holding a file of its own is',
          StrataDatasetPresent(probe, kStrataDatasets[0]));
    Check('an empty base directory is not', not StrataDatasetPresent('', kStrataDatasets[0]));

    ScrubDatasetProbe(probe, kStrataDatasets[0].Directory);

    CheckStr('sizes read the way a person would', '350 MB',
             StrataBytesText(350393595));
    CheckStr('and a large one in GB', '1.1 GB', StrataBytesText(1113113881));

    if StrataDownloader = '' then
      WriteLn('  NOTE: neither curl nor wget is on the PATH, so the window '
              + 'cannot download datasets here')
    else
      WriteLn('  downloads would use ', StrataDownloader);

    WriteLn;
    WriteLn(Format('%d checks, %d failures', [Checks, Failures]));
    if Failures = 0 then WriteLn('PASSED') else WriteLn('FAILED');
  finally
    macro.Free;
    unknown.Free;
    ref.Free;
  end;
  if Failures > 0 then Halt(1);
end.
