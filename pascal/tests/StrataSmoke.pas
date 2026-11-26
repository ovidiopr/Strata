{==============================================================================
  StrataSmoke.pas: console exercise of the Free Pascal binding.

  The Pascal counterpart of api/strata_smoke.c: loads the backend, configures
  a two-layer target, runs a beam while polling progress and log output the
  way the GUI timer does, then reads the statistics and a histogram back.

  Usage: StrataSmoke [library-path-or-directory] [events] [threads]
==============================================================================}

program StrataSmoke;

{$mode objfpc}{$H+}

uses
  Math, SysUtils, Classes, uStrataApi, uStrataEngine, uStrataCommands;

var
  Failures: Integer = 0;
  LogLines: Integer = 0;
  LastProgressLine: string = '';
  Finished: Boolean = False;
  FinishStatus: Integer = -999;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  WriteLn(Format('%-52s %s', [AWhat, BoolToStr(ACondition, 'ok', 'FAILED')]));
  if not ACondition then Inc(Failures);
end;

type
  TCollector = class
    procedure LogLine(Sender: TObject; const ALine: string; AIsError: Boolean);
    procedure Progress(Sender: TObject; ADone, ATotal: Int64);
    procedure RunFinished(Sender: TObject; AStatus: Integer);
  end;

procedure TCollector.LogLine(Sender: TObject; const ALine: string; AIsError: Boolean);
begin
  Inc(LogLines);
  if AIsError then WriteLn('  [G4cerr] ', ALine);
end;

procedure TCollector.Progress(Sender: TObject; ADone, ATotal: Int64);
begin
  if ATotal > 0 then
    LastProgressLine := Format('%d / %d events (%.1f %%)',
      [ADone, ATotal, 100.0 * ADone / ATotal]);
end;

procedure TCollector.RunFinished(Sender: TObject; AStatus: Integer);
begin
  Finished := True;
  FinishStatus := AStatus;
end;

const
  { not 'strata', so that a stray file from another test cannot pass this }
  OutputName = 'strata-smoke-output';

var
  LibPath, Err: string;
  Engine: TStrataEngine;
  Collector: TCollector;
  NEvents, NThreads: Integer;
  TrackName: String;
  Stats: TStrataRunStatsC;
  Vox: TStrataVoxelDoseArray;
  Expected: Double;
  Reals, Dummies, Untitled: Integer;
  Layers: TStrataLayerArray;
  Commands: TStrataCommandTree;
  Entry: TStrataCommandInfo;
  TreeText: String;
  H: TStrataHistogram;
  Mats, Base, Optional: TStringList;
  i, Guard: Integer;
  Integral, Peak, PeakAt, SizeX, SizeYZ: Double;
  Datasets: TStrataDatasets;
  DataDir: String;
  Cat: TStrataMaterialArray;
  ByGroup: array[TStrataMaterialGroup] of Integer;
  Seen, Defined: TStringList;
  Both: Integer;
  Density: Double;
  Live: TStrataHistogram;
  LogH: TStrataHistogram;
  LiveSeen: Integer;
  Worst: Double;
  Missing: TStringArray;
  NRequired: Integer;

{ Every event in the file, in order, and every line the full width.

  This is what multithreading used to break: with four workers the same
  run gave a third of the lines and the occasional torn one, because each
  worker opened the same path with ios::out. }
// What a material is made of, as the picker shows it
procedure CheckComposition(AEngine: TStrataEngine);
var
  e: TStrataElementArray;
  mass, atom, atoms: Double;
  i: Integer;
begin
  { Water is written by atom count, so the atom fractions are exactly two
    thirds and one third and there is nothing to round }
  e := AEngine.MaterialComposition('G4_WATER');
  Check(Length(e) = 2, Format('water has %d elements', [Length(e)]));
  if Length(e) = 2 then
  begin
    Check((e[0].Symbol = 'H') and (e[0].Z = 1), 'hydrogen first, Z = 1');
    Check((e[1].Symbol = 'O') and (e[1].Z = 8), 'then oxygen, Z = 8');
    Check(Abs(e[0].AtomFraction - 2/3) < 1e-12, 'two atoms in three are hydrogen');
    Check(Abs(e[1].AtomFraction - 1/3) < 1e-12, 'and one in three is oxygen');
    Check(Abs(e[0].MassFraction - 0.111898) < 1e-5,
      Format('hydrogen is %.6f of the mass', [e[0].MassFraction]));
    Check(Abs(e[0].A - 1.00794) < 1e-4, Format('H is %.5f g/mole', [e[0].A]));
  end;

  { Air is written by mass fraction, where Geant4's own atoms-per-molecule
    vector holds rounded rubbish (0, 1, 0, 0).  The atom fractions are read
    from the number densities instead, so they come out as air really is }
  e := AEngine.MaterialComposition('G4_AIR');
  Check(Length(e) = 4, Format('air has %d elements', [Length(e)]));
  mass := 0; atom := 0; atoms := 0;
  for i := 0 to High(e) do
  begin
    mass := mass + e[i].MassFraction;
    atom := atom + e[i].AtomFraction;
    atoms := atoms + e[i].AtomDensity;
  end;
  Check(Abs(mass - 1) < 1e-9, Format('its mass fractions sum to %.9f', [mass]));
  Check(Abs(atom - 1) < 1e-9, Format('and its atom fractions to %.9f', [atom]));
  if Length(e) = 4 then
  begin
    Check((e[1].Symbol = 'N') and (Abs(e[1].AtomFraction - 0.7844) < 1e-3),
      Format('%.2f%% of its atoms are nitrogen', [100*e[1].AtomFraction]));
    Check(Abs(atoms - 4.98737e19)/4.98737e19 < 1e-4,
      Format('%.5g atoms per cm3', [atoms]));
  end;

  { A material Strata defines itself, which is not in the catalogue and so
    can only be read from the material table }
  e := AEngine.MaterialComposition('Silica');
  Check(Length(e) = 2, Format('silica has %d elements', [Length(e)]));
  if Length(e) = 2 then
  begin
    Check((e[0].Symbol = 'Si') and (e[0].Name = 'Silicon'),
      'named in full, not just by symbol');
    Check(Abs(e[0].AtomFraction - 1/3) < 1e-9, 'one atom in three is silicon');
    Check(Abs(e[1].AtomFraction - 2/3) < 1e-9, 'and two in three are oxygen');
  end;

  { Gold, whose atom density is what an RBS yield is proportional to }
  e := AEngine.MaterialComposition('G4_Au');
  Check((Length(e) = 1) and (e[0].Z = 79), 'gold is one element, Z = 79');
  if Length(e) = 1 then
    Check(Abs(e[0].AtomDensity - 5.90697e22)/5.90697e22 < 1e-4,
      Format('at %.6g atoms per cm3', [e[0].AtomDensity]));

  Check(Length(AEngine.MaterialComposition('Unobtainium')) = 0,
    'and a material that does not exist has no elements');
end;

// The built-in damage table the window fills its grid from
procedure CheckDamageDefaults(AEngine: TStrataEngine);
var
  ed, b, c: Double;
  found: Boolean;
begin
  Check(AEngine.DamageDefaults('G4_Fe', ed, b, c), 'iron has built-in damage constants');
  Check(SameValue(ed, 40) and SameValue(b, -0.568) and SameValue(c, 0.286),
    Format('iron: Ed %g eV, b %g, c %g', [ed, b, c]));
  // Asked first: the message is built before the call in the same statement
  found := AEngine.DamageDefaults('G4_W', ed, b, c);
  Check(found and SameValue(ed, 70), Format('tungsten: Ed %g eV', [ed]));
  Check(not AEngine.DamageDefaults('G4_Si', ed, b, c),
    'silicon is not in the table');
end;

{ An empty spectrum that has a reason says it

  h1[17] and h1[18] count neutrons made during the run, which a neutron beam
  in a scattering medium never makes: the beam is not counted there and an
  elastic scatter continues the same track.  neutron_moderator.mac looked
  broken for exactly this reason, so the window explains it rather than
  reporting nothing. }
procedure CheckEmptyReasons;
var
  none: array[0..0] of Double;
begin
  none[0] := 0;
  Check(Pos('created during the run',
            StrataEmptySpectrumReason(17, 0, none, 'neutron_hp')) > 0,
    'an empty neutron creation spectrum explains itself');
  Check(Pos('created during the run',
            StrataEmptySpectrumReason(18, 0, none, 'neutron_hp')) > 0,
    'and so does its log-binned twin');
  Check(Pos('nuclear recoils',
            StrataEmptySpectrumReason(2, 0, none, 'standard_opt4')) > 0,
    'the nuclear stopping power still names the lists that fill it');
  Check(Pos('no step of this run',
            StrataEmptySpectrumReason(34, 0, none, 'neutron_hp')) > 0,
    'and a spectrum with no special reason falls back to the general one');
end;

procedure CheckTrackFile(const AName: String; AEvents, AThreads: Integer);
var
  f: TextFile;
  s: String;
  parts: TStringArray;
  seen: array of Boolean;
  i, ev, lines, torn, missing, outOfOrder, prev: Integer;
begin
  if not FileExists(AName) then
  begin
    Check(False, Format('the track file %s was written', [AName]));
    Exit;
  end;
  SetLength(seen, AEvents);
  for i := 0 to AEvents - 1 do seen[i] := False;
  lines := 0; torn := 0; outOfOrder := 0; prev := -1;
  AssignFile(f, AName);
  Reset(f);
  try
    while not Eof(f) do
    begin
      ReadLn(f, s);
      s := Trim(s);
      if (s = '') or (s[1] = '#') then Continue;
      Inc(lines);
      // event, step, id, parent, name, time, x, y, z, px, py, pz, Ek, process
      parts := s.Split([' '], TStringSplitOptions.ExcludeEmpty);
      if Length(parts) <> 14 then Inc(torn);
      ev := StrToIntDef(parts[0], -1);
      if (ev >= 0) and (ev < AEvents) then seen[ev] := True;
      if ev < prev then Inc(outOfOrder);
      prev := ev;
    end;
  finally
    CloseFile(f);
  end;
  missing := 0;
  for i := 0 to AEvents - 1 do if not seen[i] then Inc(missing);
  Check(lines > 0, Format('the track file has %d lines from %d threads',
                          [lines, AThreads]));
  Check(torn = 0, Format('every line is a whole record (%d torn)', [torn]));
  Check(missing = 0, Format('every one of the %d events is in it (%d missing)',
                            [AEvents, missing]));
  Check(outOfOrder = 0,
    Format('and they are in event order (%d steps backwards)', [outOfOrder]));
  DeleteFile(AName);
end;

begin
  LibPath := '';
  if ParamCount >= 1 then LibPath := ParamStr(1);
  TrackName := 'strata-smoke-primaries.txt';
  NEvents := 300;
  if ParamCount >= 2 then NEvents := StrToIntDef(ParamStr(2), 300);
  NThreads := 2;
  if ParamCount >= 3 then NThreads := StrToIntDef(ParamStr(3), 2);

  if not LoadStrataLibrary(LibPath, Err) then
  begin
    WriteLn('cannot load the backend: ', Err);
    Halt(2);
  end;
  Check(True, 'LoadStrataLibrary (record layouts agree)');
  WriteLn(Format('  library %s, built against %s',
    [StrataVersion, StrataGeant4Version]));
  WriteLn('  loaded from ', StrataLibraryPath);
  WriteLn;

  { The datasets, asked of Geant4 rather than of the environment.  This runs
    before the engine is opened, which is the whole point: it is the check the
    front end makes to avoid Geant4 aborting the process. }
  Datasets := StrataDatasets;
  Check(Length(Datasets) = 12, Format('%d datasets reported', [Length(Datasets)]));
  NRequired := 0;
  for i := 0 to High(Datasets) do
    if Datasets[i].Required then Inc(NRequired);
  Check(NRequired = 7, Format('%d of them are required', [NRequired]));
  Missing := StrataMissingDatasets;
  if Length(Missing) = 0 then
    Check(True, 'every required dataset is present')
  else
    for i := 0 to High(Missing) do
      WriteLn('  NOTE: ', Missing[i], ' is not where Geant4 looks for it');
  for i := 0 to High(Datasets) do
    WriteLn(Format('    %-18s req=%d present=%d  %s',
      [Datasets[i].Variable, Ord(Datasets[i].Required),
       Ord(Datasets[i].Present), Datasets[i].Path]));
  WriteLn;

  { Where the datasets are told to be.  The directory the paths above already
    resolve to is the one handed over, so this exercises the call without
    moving anything: G4FindDataDir has cached its answers by now and a real
    move would need a process that has not asked yet. }
  Check(StrataSetDataDir('/no/such/dir') = STRATA_ERR_RANGE,
        'a dataset directory that does not exist is refused');
  DataDir := '';
  for i := 0 to High(Datasets) do
    if Datasets[i].Present then
    begin
      DataDir := ExcludeTrailingPathDelimiter(ExtractFilePath(
                   ExcludeTrailingPathDelimiter(Datasets[i].Path)));
      Break;
    end;
  if DataDir <> '' then
    Check(StrataSetDataDir(DataDir) = STRATA_OK,
          'the directory the datasets are in is accepted: ' + DataDir);

  Engine := TStrataEngine.Create;
  Collector := TCollector.Create;
  try
    Engine.OnLogLine := @Collector.LogLine;
    Engine.OnProgress := @Collector.Progress;
    Engine.OnRunFinished := @Collector.RunFinished;

    Engine.Open(NThreads);
    Check(Engine.IsOpen, 'Open');
    Check(Engine.State = STRATA_STATE_IDLE, 'state is IDLE before initialize');
    { Geant4 has resolved what it needed, and a resolved path cannot be moved
      for the rest of the process, so the call has to refuse rather than
      report a success that would be a lie }
    Check(StrataSetDataDir(DataDir) = STRATA_ERR_STATE,
          'a session already open refuses to move the datasets');

    Engine.Apply('/control/verbose 0');
    Engine.Apply('/run/verbose 0');
    Engine.Apply('/strata/geometry/setSizeYZ 10 cm');
    Engine.Apply('/strata/geometry/layerNumber 2');
    Engine.Apply('/strata/geometry/layerThickness 0 2 cm');
    Engine.Apply('/strata/geometry/layerMaterial 0 G4_WATER');
    Engine.Apply('/strata/geometry/layerThickness 1 1 cm');
    Engine.Apply('/strata/geometry/layerMaterial 1 G4_Al');
    Engine.Apply('/strata/physics/addPhysics local');
    // A test volume to score a dose in. 1 mm cube of water, so the mass is
    // known in advance: 1 mm3 x 1 g/cm3 = 1 mg
    Engine.Apply('/strata/geometry/voxelNumber 1');
    Engine.Apply('/strata/geometry/voxelDefinition 0 1 1 1 mm');
    Engine.Apply('/strata/geometry/voxelPosition 0 -5 0 0 mm');
    Check(True, 'configuration commands accepted');

    Check(not Engine.TryApply('/strata/not/a/command 1', Err),
      'unknown command reported as failure');

    Engine.Initialize;
    Check(Engine.State = STRATA_STATE_INITIALISED, 'state is INITIALISED');

    { The command tree the macro editor completes from }
    Commands := TStrataCommandTree.Create;
    try
      TreeText := Engine.CommandTree;
      Commands.LoadFromText(TreeText);
      Check(Commands.Count > 400,
            Format('command tree reads (%d entries, %d bytes)', [Commands.Count, Length(TreeText)]));
      Check(Commands.IsCommand('/run/beamOn') and Commands.IsCommand('/run/initialize'),
            'Geant4''s run commands are in it');
      Entry := Commands.Find('/strata/geometry/layerMaterial');
      Check((Entry <> nil) and (Length(Entry.Params) = 4)
            and (Entry.Params[1].Name = 'material') and Entry.Params[2].Omittable
            and Entry.Params[3].Omittable,
            'Strata''s layerMaterial: index, material, optional density');
      Entry := Commands.Find('/gun/particle');
      Check((Entry <> nil) and (Length(Entry.Params) = 1)
            and (Pos(' proton ', ' ' + Entry.Params[0].Candidates + ' ') > 0),
            'the particle candidates are the particle table');
      Entry := Commands.Find('/strata/damage/setEd');
      Check(Entry <> nil, 'the damage commands are in it');
      Check((Commands.Find('/strata/') <> nil) and Commands.Find('/strata/').IsDirectory,
            '/strata/ is a directory');
    finally
      Commands.Free;
    end;

    Layers := Engine.Layers;
    Check(Length(Layers) = 2, 'two layers read back');
    for i := 0 to High(Layers) do
      WriteLn(Format('  layer %d: %-10s %8.3f mm  x = [%8.3f, %8.3f] mm',
        [i, Layers[i].Material, Layers[i].Thickness, Layers[i].XMin, Layers[i].XMax]));
    Check(Abs(Layers[0].Thickness - 20.0) < 1e-9, 'layer 0 is 20 mm');
    Check(Layers[0].Material = 'G4_WATER', 'layer 0 is water');
    Check(Layers[1].Material = 'G4_Al', 'layer 1 is aluminium');

    Engine.WorldSize(SizeX, SizeYZ);
    Check(SizeX > 30.0, 'world is larger than the target');
    Check(Engine.WorldMaterial <> '', 'world material readable');

    Mats := TStringList.Create;
    Base := TStringList.Create;
    Optional := TStringList.Create;
    try
      Engine.FillMaterialNames(Mats);
      Check(Mats.Count > 100, Format('NIST catalogue (%d materials)', [Mats.Count]));
      Check(Mats.IndexOf('G4_WATER') >= 0, 'G4_WATER present in the catalogue');

      { The catalogue with Geant4's own grouping, which the material picker
        shows instead of guessing from the names.  Every material has to land
        in exactly one group: an ungrouped one means Geant4 no longer builds
        them in the order the backend locates the boundaries from, and the
        backend is supposed to report nothing rather than guess. }
      Cat := Engine.Materials;
      Check(Length(Cat) = Mats.Count,
        Format('the grouped catalogue has the same %d materials', [Length(Cat)]));
      FillChar(ByGroup, SizeOf(ByGroup), 0);
      Seen := TStringList.Create;
      try
        Seen.Sorted := True;
        Seen.Duplicates := dupIgnore;
        for i := 0 to High(Cat) do
        begin
          Inc(ByGroup[Cat[i].Group]);
          Seen.Add(Cat[i].Name);
          if Cat[i].Name = 'G4_Si' then Density := Cat[i].Density;
        end;
        Check(Seen.Count = Length(Cat), 'and no name twice in it');
      finally
        Seen.Free;
      end;
      Check(ByGroup[mgUnknown] = 0,
        Format('%d materials are ungrouped', [ByGroup[mgUnknown]]));
      Check(ByGroup[mgElement] = 98,
        Format('%d elements', [ByGroup[mgElement]]));
      Check(ByGroup[mgHep] > 0, 'the HEP and nuclear group is not empty');
      Check(ByGroup[mgSpace] > 0, 'the space group is not empty');
      Check(ByGroup[mgBio] > 0, 'the bio-chemical group is not empty');
      Check(Abs(Density - 2.33) < 1e-9,
        Format('G4_Si is offered at %.6g g/cm3', [Density]));
      WriteLn(Format('  materials: %d elements, %d NIST, %d HEP, %d space, %d bio',
        [ByGroup[mgElement], ByGroup[mgNist], ByGroup[mgHep], ByGroup[mgSpace],
         ByGroup[mgBio]]));

      { The two lists the picker shows are disjoint.  A catalogue material
        joins Geant4's material table the moment anything builds it -- using
        it in a geometry, or asking what it is made of -- and it is not one
        of this session's own for having been read, so the backend leaves it
        out.  The picker always dropped those names itself; this is the same
        rule, kept where the catalogue is known }
      Defined := TStringList.Create;
      try
        Engine.FillDefinedMaterialNames(Defined);
        Both := 0;
        for i := 0 to Defined.Count - 1 do
          if Mats.IndexOf(Defined[i]) >= 0 then Inc(Both);
        Check(Both = 0,
          Format('%d of the %d defined materials are in the catalogue',
                 [Both, Defined.Count]));
        Check(Defined.IndexOf('Silica') >= 0, 'and Strata''s own are there');
        Check(Defined.IndexOf('StripperGas') >= 0,
          'including the ones only a macro uses');
        WriteLn(Format('  the picker shows %d + %d = %d entries',
          [Length(Cat), Defined.Count, Length(Cat) + Defined.Count]));
      finally
        Defined.Free;
      end;

      CheckComposition(Engine);

      CheckDamageDefaults(Engine);
      CheckEmptyReasons;

      Engine.FillPhysicsNames(Base, Optional);
      Check(Base.Count > 15, Format('%d base physics lists', [Base.Count]));
      Check(Optional.Count > 5, Format('%d optional components', [Optional.Count]));
      Check(Base.IndexOf('standardNR') >= 0, 'standardNR offered');
      Check(Base.IndexOf('neutron_hp') >= 0, 'and neutron_hp, which is a base list');
      Check(Optional.IndexOf('elastic_hpt') >= 0,
        'elastic_hpt is offered as an add-on');
      { A name the catalogue does not carry.  Three macros used to name
        "standard", which is not one of these, and silently ran on the
        standard_opt0 default instead }
      Check(Base.IndexOf('standard') < 0,
        'and plain standard is not a list, despite the look of the others');
    finally
      Mats.Free; Base.Free; Optional.Free;
    end;

    Engine.Apply('/gun/particle proton');
    Engine.Apply('/gun/energy 100 MeV');
    Engine.Apply('/analysis/h1/set 1 100 0 30 mm');
    // Switched on before the run so that the worker threads publish a live
    // copy of it, which is what the logarithmic check further down compares
    Engine.Apply('/analysis/h1/set 13 500 0.01 50 keV log10');

    { A run driven through the library keeps its histograms in memory and
      writes nothing.  The file name is set so that anything written would
      have to land here. }
    Engine.Apply('/analysis/setFileName ' + OutputName);
    DeleteFile(OutputName + '.root');

    { The per-step primaries file, written by RunAction, one object per
      worker thread.  They used to share one path and truncate each other;
      now each writes its own part and the master joins them in event
      order, so a run on NThreads workers has to produce a file with every
      event in it, in order, and no torn lines. }
    DeleteFile(TrackName);
    Engine.Apply('/strata/files/setPrimariesName ' + TrackName);
    Engine.Apply('/strata/files/savePrimaries true');

    { Run it the way the GUI does: start, then poll.  While it runs, read
      h1[1] the way the GUI does when a spectrum is being watched; the
      engine thread is inside the event loop, so this must come from the
      copies the worker threads publish and must not block. }
    Engine.BeamOn(NEvents);
    Guard := 0;
    LiveSeen := 0;
    while not Finished do
    begin
      Engine.Poll;
      Live := Default(TStrataHistogram);
      Live.NBins := 100;
      Live.Active := True;
      if Engine.LiveHistogram(1, Live) and (Length(Live.Y) > 0) then
        Inc(LiveSeen);
      Sleep(50);
      Inc(Guard);
      if Guard > 20 * 600 then Break;          { 10 minutes }
    end;
    Engine.Poll;

    Check(LiveSeen > 0,
      Format('a spectrum could be read %d times while the run was going',
             [LiveSeen]));

    Check(not FileExists(OutputName + '.root'),
      'the run wrote no analysis file');
    Check(Finished, 'OnRunFinished fired');
    Check(FinishStatus = STRATA_OK, 'run finished with STRATA_OK');
    Check(LogLines > 0, Format('log events delivered (%d lines)', [LogLines]));
    WriteLn('  last progress report: ', LastProgressLine);
    Check(Engine.EventsDone = NEvents, 'every event accounted for');

    CheckTrackFile(TrackName, NEvents, NThreads);

    Check(Engine.HasResults, 'HasResults');
    Stats := Engine.Stats;
    Check(Stats.events = NEvents, 'stats.events matches the request');
    Check(Engine.ParticleName = 'proton', 'stats.particle is proton');

    WriteLn;
    WriteLn(Format('  %-22s %s at %.3f MeV', ['primary', Engine.ParticleName,
      Stats.beamEnergy]));
    WriteLn(Format('  %-22s %.4f +- %.4f mm', ['projected range',
      Stats.projRange, Stats.projRangeRms]));
    WriteLn(Format('  %-22s %.4f +- %.4f MeV', ['energy deposited',
      Stats.edep, Stats.edepRms]));
    WriteLn(Format('  %-22s %.4f MeV', ['energy balance', Stats.energyBalance]));
    WriteLn(Format('  %-22s %.3f', ['electrons / event', Stats.electronPerEvent]));
    WriteLn(Format('  %-22s %.4f mrad', ['Highland theta0',
      Stats.mscHighland * 1000.0]));
    WriteLn;

    Check(Stats.edep > 0, 'edep > 0');

    // The dose, the mass and the energy have to agree with each other, which
    // is the check that would have caught a mass of 1e19 g: the API reports
    // grams and gray, not Geant4's internal units, in which a gram is 6.24e21
    // and a gray is 1e-12
    Vox := Engine.VoxelDoses;
    Check(Length(Vox) = 1, 'one test volume reported');
    if Length(Vox) = 1 then
    begin
      WriteLn(Format('  %-22s %.6g g', ['test volume mass', Vox[0].Mass]));
      WriteLn(Format('  %-22s %.6g MeV', ['test volume edep', Vox[0].Edep]));
      WriteLn(Format('  %-22s %.6g Gy', ['test volume dose', Vox[0].Dose]));
      WriteLn;
      Check(Abs(Vox[0].Mass - 1.0e-3) < 1.0e-6,
        Format('a 1 mm3 water volume weighs 1 mg (got %.6g g)', [Vox[0].Mass]));
      Check(Vox[0].Edep > 0, 'the test volume absorbed something');
      // 1 MeV = 1.602176634e-13 J, and a gray is one joule per kilogram
      Expected := Vox[0].Edep*1.602176634e-13/(Vox[0].Mass*1.0e-3);
      Check(Abs(Vox[0].Dose - Expected) <= 1.0e-9*Expected,
        Format('dose = edep/mass (%.6g Gy, wanted %.6g Gy)',
          [Vox[0].Dose, Expected]));
      Check((Vox[0].Ratio > 0) and (Vox[0].Ratio <= 100),
        Format('the volume took %.4g %% of what the target absorbed',
          [Vox[0].Ratio]));
    end;

    // The catalogue: what each spectrum is and what its axis measures, from
    // Strata's own table. Geant4 reports no title for a histogram it has not
    // materialised, which is why every inactive one used to read as nameless
    Reals := 0; Dummies := 0; Untitled := 0;
    for i := 0 to Engine.HistogramCount - 1 do
    begin
      H := Engine.Histogram(i, False);
      if not StrataH1IsReal(H) then
      begin
        Inc(Dummies);
        Continue;
      end;
      Inc(Reals);
      if (H.Title = '') or (H.YAxisTitle = '') then Inc(Untitled);
    end;
    Check(Engine.HistogramCount = 81, Format('%d spectra booked', [Engine.HistogramCount]));
    Check(Reals = 54, Format('%d of them are real', [Reals]));
    Check(Dummies = 27, Format('and %d are placeholders', [Dummies]));
    Check(Untitled = 0, 'every real one has a title and a y-axis label');
    Check(Engine.Histogram(1, False).Axis = akLength,
      'h1[1], the stopping power, is plotted against depth');
    Check(Engine.Histogram(10, False).Axis = akEnergy,
      'h1[10], the deposited energy, is an energy');
    Check(Engine.Histogram(22, False).Axis = akFwdAngle,
      'h1[22], transmitted, is a forward angle');
    Check(Engine.Histogram(42, False).Axis = akBackAngle,
      'h1[42], reflected, is a backward angle');
    // 13 is 11 rebinned: StackingAction fills both with the same energy,
    // so log10 is how the bins are spaced and not what the axis measures
    Check(Engine.Histogram(13, False).Axis = akEnergy,
      'h1[13], the log-scale twin of h1[11], is an energy too');

    // A logarithmic axis is stored as log10 of the value, and comes back
    // as the value: 0.01 to 50 keV, not -2 to 1.69897. It was switched on
    // before the run, so it is not re-applied here: that would clear it
    H := Engine.Histogram(13, False);
    Check(H.LogX, 'h1[13] reports that its bins are logarithmic');
    Check(Abs(H.XMin - 0.01) < 1e-12,
      Format('and its lower edge reads back as %.6g keV, not its logarithm', [H.XMin]));
    Check(Abs(H.XMax - 50.0) < 1e-9,
      Format('and its upper edge as %.6g keV', [H.XMax]));
    Engine.Apply('/analysis/h1/set 11 500 0 50 keV');
    Check(not Engine.Histogram(11, False).LogX,
      'while its linear twin reports that they are not');

    // An axis comes back in the unit it was set with, not in Geant4's
    // internal one. Dividing XMax by Unit_ to display it was a real bug: it
    // showed an imported micrometre axis a thousand times too large
    Engine.Apply('/analysis/h1/set 2 50 0 30 um');
    H := Engine.Histogram(2, False);
    Check(Abs(H.XMax - 30.0) < 1e-9,
      Format('an axis set to 30 um reads back as %.6g, not 0.03', [H.XMax]));
    Check(Abs(H.Unit_ - 1.0e-3) < 1e-12,
      Format('and reports its unit as %.6g (a micrometre in mm)', [H.Unit_]));

    H := Engine.Histogram(1, True);
    Check(H.Active, 'h1[1] active');

    { The live copies are the same numbers, divided the same way: once the run
      has ended and Geant4 has merged the workers, the two have to agree bin
      for bin.  h1[1] is one of the six that end of run turns into a per-event
      density, so this also pins that the live read divides by the events it
      actually has rather than by every event finished. }
    Live := Default(TStrataHistogram);
    Live.NBins := H.NBins;
    Live.Active := True;
    Check(Engine.LiveHistogram(1, Live), 'the live copy of h1[1] is there');
    Check(Length(Live.Y) = Length(H.Y),
      Format('live and merged agree on the bin count (%d and %d)',
             [Length(Live.Y), Length(H.Y)]));
    Worst := 0;
    for i := 0 to High(H.Y) do
      if i <= High(Live.Y) then
        if Abs(Live.Y[i] - H.Y[i]) > Worst then Worst := Abs(Live.Y[i] - H.Y[i]);
    Check(Worst < 1.0e-9,
      Format('live and merged agree bin for bin (worst %.3g)', [Worst]));

    { And the same for a logarithmic axis, which is where the two readers
      came apart.  Both now report the centres as Geant4 stores them, which
      for h1[13] set to 0.01..50 keV means log10 values from about -2 to
      1.7: such a spectrum is drawn on a plain linear axis, where evenly
      spaced logarithms are the logarithmic plot.  Comparing the x values
      and not just the heights is the point of this check. }
    LogH := Engine.Histogram(13, True);
    Check(LogH.LogX and (Length(LogH.X) > 0), 'h1[13] has logarithmic data');
    Live := Default(TStrataHistogram);
    Live.NBins := LogH.NBins;
    Live.Active := True;
    Check(Engine.LiveHistogram(13, Live), 'the live copy of h1[13] is there');
    Worst := 0;
    for i := 0 to High(LogH.X) do
      if i <= High(Live.X) then
        if Abs(Live.X[i] - LogH.X[i]) > Worst then
          Worst := Abs(Live.X[i] - LogH.X[i]);
    Check(Worst < 1.0e-9,
      Format('live and merged agree on every bin centre (worst %.3g)', [Worst]));
    { The edges are a different convention from the centres on purpose: the
      command takes keV and Geant4 stores the logarithm, so XMin is 0.01
      while the first centre is just above log10(0.01) = -2.  Pinning both
      is what stops either from drifting into the other. }
    Check((Length(LogH.X) > 0)
          and (LogH.X[0] > -2.0) and (LogH.X[0] < -1.9),
      Format('the centres are the stored logarithms (first %.6g)', [LogH.X[0]]));
    Check(Abs(LogH.XMax - 50.0) < 1e-9,
      Format('while the edges stay in keV (XMax %.6g)', [LogH.XMax]));
    Check(Abs(LogH.X[High(LogH.X)] - 1.69897) < 0.01,
      Format('and the last centre is log10(50) = %.6g', [LogH.X[High(LogH.X)]]));

    Check(H.NBins = 100, 'h1[1] has 100 bins');
    Check(Length(H.Y) = 100, 'h1[1] data returned for every bin');
    Integral := 0; Peak := 0; PeakAt := 0;
    for i := 0 to High(H.Y) do
    begin
      Integral := Integral + H.Y[i];
      if H.Y[i] > Peak then begin Peak := H.Y[i]; PeakAt := H.X[i]; end;
    end;
    WriteLn(Format('  h1[1] "%s"', [H.Title]));
    WriteLn(Format('  integral x bin width = %.4f MeV (edep = %.4f MeV)',
      [Integral * H.Width, Stats.edep]));
    WriteLn(Format('  peak %.4g at x = %.3f mm', [Peak, PeakAt]));
    Check(Integral > 0, 'h1[1] has content');
    { The Se histogram is scaled by 1/(N * binWidth), so its integral times
      the bin width must reproduce the mean energy deposit. }
    Check(Abs(Integral * H.Width - Stats.edep) < 0.05 * Stats.edep,
      'histogram integral agrees with the reported energy deposit');

    { Abort.  The request has to reach the event loop: G4RunManager::AbortRun
      reads the state manager, which is thread-local, so calling it from this
      thread would look as though a run were not in progress and do nothing.
      Ask for far more events than can run, stop it, and check that it did
      stop, and that the events it did run are still accounted for. }
    Finished := False;
    Engine.BeamOn(1000*NEvents);
    Guard := 0;
    while (Engine.EventsDone < NEvents div 2) and (Guard < 20*600) do
    begin
      Engine.Poll;
      Sleep(50);
      Inc(Guard);
    end;
    Check(Engine.AbortRun, 'the backend accepted the abort');
    Guard := 0;
    while not Finished do
    begin
      Engine.Poll;
      Sleep(50);
      Inc(Guard);
      if Guard > 20 * 600 then Break;
    end;
    Engine.Poll;
    Check(Finished, 'the aborted run reported that it finished');
    Check(Engine.EventsDone < 1000*NEvents,
      Format('the run stopped early (%d of %d events)',
        [Engine.EventsDone, 1000*NEvents]));
    Check(Engine.EventsDone >= NEvents div 2,
      'the events that did run are still counted');

    Engine.Close;
    Check(not Engine.IsOpen, 'Close');

    { What the New session button does: the kernel was built in the engine
      process, so another engine can be opened in this same front end }
    Engine.Open(NThreads);
    Check(Engine.IsOpen, 'a second engine opens after the first is closed');
    Check(Engine.State = STRATA_STATE_IDLE, 'the second engine starts IDLE');
    Engine.Apply('/control/verbose 0');
    Engine.Apply('/strata/geometry/layerNumber 1');
    Engine.Apply('/strata/geometry/layerMaterial 0 G4_Si');
    Engine.Apply('/strata/geometry/layerThickness 0 2 um');
    Engine.Apply('/strata/physics/addPhysics standard_opt4');
    Engine.Initialize;
    Engine.Apply('/gun/particle proton');
    Engine.Apply('/gun/energy 2 MeV');
    Engine.BeamOn(20);
    Check(Engine.WaitForRun(120000), 'the second engine finishes its run');
    Check(Engine.Stats.edep > 0., 'the second engine deposits energy');
    Engine.Close;
    Check(not Engine.IsOpen, 'the second engine closes too');
  finally
    Collector.Free;
    Engine.Free;
  end;

  WriteLn;
  if Failures = 0 then
    WriteLn('PASSED (0 failures)')
  else
    WriteLn(Format('FAILED (%d failures)', [Failures]));

  // Geant4's static destructors must not run: its kernel lives on the engine thread
  Flush(Output);
  if StrataLibraryLoaded then
    strata_exit_process(Ord(Failures <> 0));
  Halt(Ord(Failures <> 0));
end.
