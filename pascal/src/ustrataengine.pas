{==============================================================================
  uStrataEngine.pas: object interface to the Strata backend.

  Wraps uStrataApi in something a Lazarus application can use directly:
  errors become exceptions, C strings become Pascal strings, and the polled
  log/progress of the C layer is turned into events.

  Threading: the backend runs Geant4 on its own thread and never calls back
  into the caller, so everything here is main-thread code.  Drive it from a
  TTimer: call Poll a few times a second and the OnLogLine, OnProgress and
  OnRunFinished events fire from inside that timer, which is exactly where
  the LCL allows widgets to be touched.
==============================================================================}

unit uStrataEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ctypes, uStrataApi;

type
  EStrataError = class(Exception)
  public
    Status: Integer;
    constructor CreateStatus(AStatus: Integer; const ADetail: String);
  end;

  TStrataLogEvent = procedure(Sender: TObject; const ALine: String; AIsError: Boolean) of object;
  TStrataProgressEvent = procedure(Sender: TObject; ADone, ATotal: Int64) of object;
  TStrataRunEvent = procedure(Sender: TObject; AStatus: Integer) of object;

  TStrataLayer = record
    Thickness: Double;       // mm
    Density: Double;         // g/cm3
    XMin, XMax: Double;      // mm
    Material: String;
  end;
  TStrataLayerArray = array of TStrataLayer;

  TStrataVoxelDose = record
    Edep: Double;            // MeV
    Ratio: Double;           // per cent of the total deposit
    Dose: Double;            // gray
    Mass: Double;
  end;
  TStrataVoxelDoseArray = array of TStrataVoxelDose;

  // A test volume as the backend built it; sizes and positions in mm
  TStrataVoxel = record
    SizeX, SizeY, SizeZ: Double;
    PosX, PosY, PosZ: Double;
    Mass: Double;
  end;
  TStrataVoxelArray = array of TStrataVoxel;

  // Which generator produced a run, and the seeds that would repeat it
  TStrataRandom = record
    Engine: String;
    Seed1, Seed2: Int64;
    Randomize: Boolean;
  end;

  // What the x axis of a histogram measures, as the backend reports it
  TStrataAxisKind = (akNone, akLength, akEnergy, akFwdAngle, akBackAngle);

  // Which of Geant4's five groups a predefined material belongs to
  TStrataMaterialGroup = (mgUnknown, mgElement, mgNist, mgHep, mgSpace, mgBio);

  TStrataMaterial = record
    Name: String;
    Group: TStrataMaterialGroup;
    Density: Double;         // g/cm3, 0 when Geant4 records none
  end;
  TStrataMaterialArray = array of TStrataMaterial;

  // One element of a material.  MassFraction is the number Geant4 stores;
  // AtomFraction and AtomDensity are read from the vectors the transport
  // uses, so a recipe written by mass reports them as correctly as one
  // written by atom count
  TStrataElement = record
    Name: String;            // Geant4 names a NIST element by its symbol
    Symbol: String;
    Z: Integer;
    A: Double;               // molar mass, g/mole
    MassFraction: Double;    // 0 to 1
    AtomFraction: Double;    // 0 to 1
    AtomDensity: Double;     // atoms per cm3
  end;
  TStrataElementArray = array of TStrataElement;

  TStrataHistogram = record
    Id: Integer;
    Active: Boolean;
    NBins: Integer;
    Axis: TStrataAxisKind;
    XMin, XMax, Width: Double;
    // The bins are spaced logarithmically
    LogX: Boolean;
    // How large the axis unit is internally, 1.0 if none was set
    Unit_: Double;
    Entries: Double;
    Title, XAxisTitle, YAxisTitle: String;
    X: array of Double;      // bin centres
    Y: array of Double;      // bin heights
  end;

  { TStrataEngine }

  TStrataEngine = class
  private
    FSession: PStrataSession;
    FWasRunning: Boolean;
    FWasBusy: Boolean;
    FOnCommandFinished: TStrataRunEvent;
    FLogBuf: array[0..8191] of AnsiChar;
    FOnLogLine: TStrataLogEvent;
    FOnProgress: TStrataProgressEvent;
    FOnRunFinished: TStrataRunEvent;
    function GetOpen: Boolean;
    function GetState: Integer;
    function GetProgress: Double;
    function GetEventsDone: Int64;
    function GetEventsRequested: Int64;
    function GetThreadCount: Integer;
    procedure Check(AStatus: Integer; const AContext: String);
  public
    // The backend's message for the last call that failed
    function LastError: String;
    constructor Create;
    destructor Destroy; override;

    // Starts the backend
    procedure Open(AThreads: Integer);
    procedure Close;

    // /run/initialize: builds the geometry and the physics tables
    procedure Initialize;

    // Any Geant4 or Strata UI command, raises on rejection
    procedure Apply(const ACommand: String);
    procedure ApplyFmt(const AFormat: String; const AArgs: array of const);
    // Same, but returns False instead of raising
    function TryApply(const ACommand: String; out AError: String): Boolean;
    procedure ExecuteMacro(const AFileName: String);

    // /run/initialize or one command, started without waiting; OnCommandFinished
    // fires from Poll when it is done, unless WaitCommand saw it finish first
    procedure StartInitialize;
    procedure StartApply(const ACommand: String);
    function Busy: Boolean;
    function WaitCommand(ATimeoutMs: Integer): Boolean;
    function CommandStatus: Integer;

    // Starts a run and returns at once
    procedure BeamOn(ANEvents: Int64);
    function AbortRun: Boolean;
    function WaitForRun(ATimeoutMs: Integer): Boolean;

    // Call a few times a second; drains the log and fires the events
    procedure Poll;

    // Results of the last finished run
    function HasResults: Boolean;
    function Stats: TStrataRunStatsC;
    function ParticleName: String;
    function VoxelDoses: TStrataVoxelDoseArray;
    function Voxels: TStrataVoxelArray;
    function RandomState: TStrataRandom;

    // Geometry as the backend currently has it
    function Layers: TStrataLayerArray;
    function WorldMaterial: String;
    procedure WorldSize(out ASizeX, ASizeYZ: Double);
    function Temperature: Double;

    // Catalogues for populating combo boxes
    procedure FillMaterialNames(AList: TStrings);
    // The same catalogue with Geant4's own grouping and the density it would
    // build each one with
    function Materials: TStrataMaterialArray;
    // What a material is made of, by name so that it answers for the
    // catalogue and for anything this session has defined
    function MaterialComposition(const AName: String): TStrataElementArray;
    // Built-in Ed (eV) and arc-dpa constants, False for a material without them
    function DamageDefaults(const AName: String; out AEd, AB, AC: Double): Boolean;
    procedure FillDefinedMaterialNames(AList: TStrings);
    procedure FillElementNames(AList: TStrings);
    procedure FillPhysicsNames(ABase, AOptional: TStrings);
    procedure FillParticleNames(AList: TStrings);
    // Every UI directory and command, as the text uStrataCommands reads
    function CommandTree: String;

    // Histograms; most of them inactive until /analysis/h1/set is applied
    function HistogramCount: Integer;
    function Histogram(AId: Integer; AWithData: Boolean): TStrataHistogram;
    // The points as they stand while a run is still going
    function LiveHistogram(AId: Integer; var AHistogram: TStrataHistogram): Boolean;

    property IsOpen: Boolean read GetOpen;
    property State: Integer read GetState;
    property Progress: Double read GetProgress;
    property EventsDone: Int64 read GetEventsDone;
    property EventsRequested: Int64 read GetEventsRequested;
    property ThreadCount: Integer read GetThreadCount;

    property OnLogLine: TStrataLogEvent read FOnLogLine write FOnLogLine;
    property OnProgress: TStrataProgressEvent read FOnProgress write FOnProgress;
    property OnRunFinished: TStrataRunEvent read FOnRunFinished write FOnRunFinished;
    property OnCommandFinished: TStrataRunEvent read FOnCommandFinished write FOnCommandFinished;
  end;

// Version Strings; safe to call before any session exists
function StrataVersion: String;
function StrataGeant4Version: String;

type
  // One Geant4 dataset, as the backend reports Geant4 resolving it
  TStrataDataset = record
    Variable: String;
    Path: String;       // empty when Geant4 could not resolve it at all
    Present: Boolean;   // the resolved directory really holds the dataset
    Required: Boolean;  // Geant4 aborts when it is missing
  end;
  TStrataDatasets = array of TStrataDataset;

// The Geant4 datasets and whether Geant4 can find each one
{ False for a slot Strata books but never shows: the catalogue has 73 entries
  and 32 of them are placeholders. }
function StrataH1IsReal(const AHistogram: TStrataHistogram): Boolean;

function StrataDatasets: TStrataDatasets;

// Just the required ones the backend says are not there
function StrataMissingDatasets: TStringArray;

// Points Geant4 at a directory of datasets
function StrataSetDataDir(const ADir: String): Integer;

// Why a spectrum that is switched on can still be drawn flat
function StrataEmptySpectrumReason(AId: Integer; AEntries: Double; const AY: array of Double; const APhysics: String): String;

implementation

function StrataH1IsReal(const AHistogram: TStrataHistogram): Boolean;
begin
  Result := AHistogram.Title <> 'dummy';
end;

function PCharToStr(P: PAnsiChar): String;
begin
  if P = nil then Result := '' else Result := String(AnsiString(P));
end;

function BufToStr(const ABuf: array of AnsiChar): String;
var
  i: Integer;
begin
  Result := '';
  for i := Low(ABuf) to High(ABuf) do
  begin
    if ABuf[i] = #0 then Exit;
    Result := Result + ABuf[i];
  end;
end;

function StrataVersion: String;
begin
  if StrataLibraryLoaded then Result := PCharToStr(strata_version())
  else Result := '(not loaded)';
end;

function StrataGeant4Version: String;
begin
  if StrataLibraryLoaded then Result := PCharToStr(strata_geant4_version())
  else Result := '(not loaded)';
end;

function StrataDatasets: TStrataDatasets;
var
  i, n: Integer;
  rec: TStrataDatasetC;
begin
  Result := nil;
  if not StrataLibraryLoaded then Exit;
  n := strata_dataset_count();
  if n <= 0 then Exit;
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    FillChar(rec, SizeOf(rec), 0);
    if strata_get_dataset(i, @rec) <> STRATA_OK then
    begin
      SetLength(Result, i);
      Exit;
    end;
    Result[i].Variable := BufToStr(rec.variable);
    Result[i].Path     := BufToStr(rec.path);
    Result[i].Present  := rec.present <> 0;
    Result[i].Required := rec.required <> 0;
  end;
end;

function StrataSetDataDir(const ADir: String): Integer;
begin
  if not StrataLibraryLoaded then Exit(STRATA_ERR_HANDLE);
  Result := strata_set_data_dir(PAnsiChar(AnsiString(ADir)));
end;

function StrataMissingDatasets: TStringArray;
var
  all: TStrataDatasets;
  i, n: Integer;
begin
  Result := nil;
  all := StrataDatasets;
  SetLength(Result, Length(all));
  n := 0;
  for i := 0 to High(all) do
    if all[i].Required and (not all[i].Present) then
    begin
      Result[n] := all[i].Variable;
      Inc(n);
    end;
  SetLength(Result, n);
end;

{ EStrataError }

constructor EStrataError.CreateStatus(AStatus: Integer; const ADetail: String);
begin
  Status := AStatus;
  if ADetail = '' then
    inherited Create(StrataStatusText(AStatus))
  else
    inherited Create(ADetail);
end;

{ TStrataEngine }

constructor TStrataEngine.Create;
begin
  inherited Create;
  FSession := nil;
  FWasRunning := False;
end;

destructor TStrataEngine.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TStrataEngine.GetOpen: Boolean;
begin
  Result := FSession <> nil;
end;

function TStrataEngine.LastError: String;
begin
  if FSession = nil then Exit('no session');
  Result := PCharToStr(strata_last_error(FSession));
end;

procedure TStrataEngine.Check(AStatus: Integer; const AContext: String);
var
  detail: String;
begin
  if AStatus >= STRATA_OK then Exit;
  detail := LastError;
  if detail = '' then detail := StrataStatusText(AStatus);
  raise EStrataError.CreateStatus(AStatus, Format('%s: %s', [AContext, detail]));
end;

procedure TStrataEngine.Open(AThreads: Integer);
var
  detail: String;
begin
  if FSession <> nil then Exit;
  if not StrataLibraryLoaded then
    raise EStrataError.CreateStatus(STRATA_ERR_HANDLE, 'The Strata backend library has not been loaded');

  FSession := strata_create(AThreads);
  if FSession = nil then
  begin
    // The engine process, or the client when there is no engine, says why
    detail := PCharToStr(strata_last_error(nil));
    if detail <> '' then
      raise EStrataError.CreateStatus(STRATA_ERR_STATE, 'strata_create failed: ' + detail);
    raise EStrataError.CreateStatus(STRATA_ERR_STATE,
      'strata_create failed. Geant4''s run manager is a process singleton, so '
      + 'only one session can exist; check that the Geant4 data environment '
      + 'variables (G4LEDATA and friends) are set.');
  end;
end;

procedure TStrataEngine.Close;
begin
  if FSession = nil then Exit;
  strata_destroy(FSession);
  FSession := nil;
  FWasRunning := False;
  FWasBusy := False;
end;

procedure TStrataEngine.Initialize;
begin
  Check(strata_initialize(FSession), '/run/initialize');
end;

function TStrataEngine.GetState: Integer;
begin
  if FSession = nil then Exit(STRATA_STATE_IDLE);
  Result := strata_state(FSession);
end;

function TStrataEngine.GetProgress: Double;
begin
  if FSession = nil then Exit(0);
  Result := strata_progress(FSession);
end;

function TStrataEngine.GetEventsDone: Int64;
begin
  if FSession = nil then Exit(0);
  Result := strata_events_done(FSession);
end;

function TStrataEngine.GetEventsRequested: Int64;
begin
  if FSession = nil then Exit(0);
  Result := strata_events_requested(FSession);
end;

function TStrataEngine.GetThreadCount: Integer;
begin
  if FSession = nil then Exit(0);
  Result := strata_thread_count(FSession);
end;

procedure TStrataEngine.Apply(const ACommand: String);
begin
  Check(strata_apply(FSession, PAnsiChar(AnsiString(ACommand))), ACommand);
end;

procedure TStrataEngine.ApplyFmt(const AFormat: String; const AArgs: array of const);
begin
  Apply(Format(AFormat, AArgs));
end;

function TStrataEngine.TryApply(const ACommand: String; out AError: String): Boolean;
var
  rc: Integer;
begin
  AError := '';
  rc := strata_apply(FSession, PAnsiChar(AnsiString(ACommand)));
  Result := rc >= STRATA_OK;
  if not Result then AError := LastError;
end;

procedure TStrataEngine.ExecuteMacro(const AFileName: String);
begin
  Check(strata_execute_macro(FSession, PAnsiChar(AnsiString(AFileName))),
        'execute ' + AFileName);
end;

procedure TStrataEngine.StartInitialize;
begin
  Check(strata_initialize_start(FSession), '/run/initialize');
  FWasBusy := True;
end;

procedure TStrataEngine.StartApply(const ACommand: String);
begin
  Check(strata_apply_start(FSession, PAnsiChar(AnsiString(ACommand))), ACommand);
  FWasBusy := True;
end;

function TStrataEngine.Busy: Boolean;
begin
  Result := (FSession <> nil) and (strata_busy(FSession) = 1);
end;

// True when the started command is done; its result is then CommandStatus
function TStrataEngine.WaitCommand(ATimeoutMs: Integer): Boolean;
begin
  Result := (FSession = nil) or (strata_command_wait(FSession, ATimeoutMs) = STRATA_OK);
  if Result then FWasBusy := False;
end;

function TStrataEngine.CommandStatus: Integer;
begin
  if FSession = nil then Exit(STRATA_ERR_HANDLE);
  Result := strata_command_status(FSession);
end;

procedure TStrataEngine.BeamOn(ANEvents: Int64);
begin
  Check(strata_beam_on(FSession, ANEvents), Format('beamOn %d', [ANEvents]));
  FWasRunning := True;
end;

// True when the backend accepted the request
function TStrataEngine.AbortRun: Boolean;
begin
  Result := False;
  if FSession = nil then Exit;
  Result := strata_abort(FSession) = STRATA_OK;
end;

function TStrataEngine.WaitForRun(ATimeoutMs: Integer): Boolean;
begin
  if FSession = nil then Exit(True);
  Result := strata_wait(FSession, ATimeoutMs) = STRATA_OK;
end;

procedure TStrataEngine.Poll;
var
  isErr: cint;
  running: Boolean;
begin
  if FSession = nil then Exit;

  // Keep the log lines reasonable
  isErr := 0;
  while strata_log_pop(FSession, @FLogBuf[0], SizeOf(FLogBuf), @isErr) = 1 do
  begin
    if Assigned(FOnLogLine) then
      FOnLogLine(Self, BufToStr(FLogBuf), isErr <> 0);
  end;

  running := GetState in [STRATA_STATE_RUNNING, STRATA_STATE_ABORTING];

  if FWasRunning and Assigned(FOnProgress) then
    FOnProgress(Self, GetEventsDone, GetEventsRequested);

  if FWasRunning and (not running) then
  begin
    FWasRunning := False;
    if Assigned(FOnRunFinished) then
      FOnRunFinished(Self, strata_run_status(FSession));
  end;

  if FWasBusy and (not Busy) then
  begin
    FWasBusy := False;
    if Assigned(FOnCommandFinished) then
      FOnCommandFinished(Self, strata_command_status(FSession));
  end;
end;

function TStrataEngine.HasResults: Boolean;
var
  s: TStrataRunStatsC;
begin
  if FSession = nil then Exit(False);
  Result := strata_get_stats(FSession, @s) = STRATA_OK;
end;

function TStrataEngine.Stats: TStrataRunStatsC;
begin
  FillChar(Result, SizeOf(Result), 0);
  Check(strata_get_stats(FSession, @Result), 'read run statistics');
end;

function TStrataEngine.ParticleName: String;
var
  s: TStrataRunStatsC;
begin
  s := Stats;
  Result := BufToStr(s.particle);
end;

function TStrataEngine.VoxelDoses: TStrataVoxelDoseArray;
var
  n, i: Integer;
  v: TStrataVoxelResultC;
begin
  Result := nil;
  if FSession = nil then Exit;
  n := strata_voxel_result_count(FSession);
  if n <= 0 then Exit;
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    Check(strata_get_voxel_result(FSession, i, @v), Format('voxel result %d', [i]));
    Result[i].Edep := v.edep;
    Result[i].Ratio := v.ratio;
    Result[i].Dose := v.dose;
    Result[i].Mass := v.mass;
  end;
end;
function TStrataEngine.Voxels: TStrataVoxelArray;
var
  n, i: Integer;
  v: TStrataVoxelInfoC;
begin
  SetLength(Result, 0);
  if FSession = nil then Exit;
  n := strata_voxel_count(FSession);
  if n <= 0 then Exit;
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    FillChar(v, SizeOf(v), 0);
    Check(strata_get_voxel(FSession, i, @v), Format('voxel %d', [i]));
    Result[i].SizeX := v.sizeX;
    Result[i].SizeY := v.sizeY;
    Result[i].SizeZ := v.sizeZ;
    Result[i].PosX := v.posX;
    Result[i].PosY := v.posY;
    Result[i].PosZ := v.posZ;
    Result[i].Mass := v.mass;
  end;
end;

function TStrataEngine.RandomState: TStrataRandom;
var
  buf: array[0..63] of AnsiChar;
  s1, s2: clong;
  rnd: cint;
begin
  Result.Engine := '';
  Result.Seed1 := 0;
  Result.Seed2 := 0;
  Result.Randomize := True;
  if FSession = nil then Exit;
  FillChar(buf, SizeOf(buf), 0);
  s1 := 0; s2 := 0; rnd := 1;
  Check(strata_get_random(FSession, @buf[0], SizeOf(buf), @s1, @s2, @rnd),
        'random state');
  Result.Engine := String(PAnsiChar(@buf[0]));
  Result.Seed1 := s1;
  Result.Seed2 := s2;
  Result.Randomize := rnd <> 0;
end;


function TStrataEngine.Layers: TStrataLayerArray;
var
  n, i: Integer;
  info: TStrataLayerInfoC;
begin
  Result := nil;
  if FSession = nil then Exit;
  n := strata_layer_count(FSession);
  if n <= 0 then Exit;
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    Check(strata_get_layer(FSession, i, @info), Format('layer %d', [i]));
    Result[i].Thickness := info.thickness;
    Result[i].Density := info.density;
    Result[i].XMin := info.xMin;
    Result[i].XMax := info.xMax;
    Result[i].Material := BufToStr(info.material);
  end;
end;

function TStrataEngine.WorldMaterial: String;
var
  buf: array[0..255] of AnsiChar;
begin
  Result := '';
  if FSession = nil then Exit;
  buf[0] := #0;
  Check(strata_get_world_material(FSession, @buf[0], SizeOf(buf)), 'world material');
  Result := BufToStr(buf);
end;

procedure TStrataEngine.WorldSize(out ASizeX, ASizeYZ: Double);
var
  x, yz: cdouble;
begin
  ASizeX := 0; ASizeYZ := 0;
  if FSession = nil then Exit;
  Check(strata_world_size(FSession, @x, @yz), 'world size');
  ASizeX := x;
  ASizeYZ := yz;
end;

function TStrataEngine.Temperature: Double;
begin
  if FSession = nil then Exit(0);
  Result := strata_get_temperature(FSession);
end;

function TStrataEngine.Materials: TStrataMaterialArray;
var
  n, i, kept: Integer;
  rec: TStrataMaterialInfoC;
begin
  Result := nil;
  if FSession = nil then Exit;
  n := strata_material_count(FSession);
  if n <= 0 then Exit;

  SetLength(Result, n);
  kept := 0;
  for i := 0 to n - 1 do
  begin
    FillChar(rec, SizeOf(rec), 0);
    if strata_get_material_info(FSession, i, @rec) <> STRATA_OK then Continue;
    Result[kept].Name := BufToStr(rec.name);
    if (rec.group >= Ord(Low(TStrataMaterialGroup)))
       and (rec.group <= Ord(High(TStrataMaterialGroup))) then
      Result[kept].Group := TStrataMaterialGroup(rec.group)
    else
      Result[kept].Group := mgUnknown;
    Result[kept].Density := rec.density;
    Inc(kept);
  end;
  SetLength(Result, kept);
end;

// Reading a catalogue material builds it, which is what Geant4 does the
// moment it is used; it does not become one of this session's own
function TStrataEngine.DamageDefaults(const AName: String; out AEd, AB, AC: Double): Boolean;
begin
  AEd := 0;
  AB := 0;
  AC := 0;
  Result := StrataLibraryLoaded and (AName <> '')
            and (strata_damage_defaults(PAnsiChar(AnsiString(AName)), @AEd, @AB, @AC) = 1);
end;

function TStrataEngine.MaterialComposition(const AName: String): TStrataElementArray;
var
  n, i: Integer;
  raw: array of TStrataElementFractionC;
begin
  Result := nil;
  if (FSession = nil) or (AName = '') then Exit;
  n := strata_get_material_composition(FSession, PAnsiChar(AnsiString(AName)), nil, 0);
  if n <= 0 then Exit;

  SetLength(raw, n);
  FillChar(raw[0], n*SizeOf(raw[0]), 0);
  n := strata_get_material_composition(FSession, PAnsiChar(AnsiString(AName)), @raw[0], n);
  if n <= 0 then Exit;

  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    Result[i].Name := BufToStr(raw[i].name);
    Result[i].Symbol := BufToStr(raw[i].symbol);
    Result[i].Z := raw[i].z;
    Result[i].A := raw[i].a;
    Result[i].MassFraction := raw[i].massFraction;
    Result[i].AtomFraction := raw[i].atomFraction;
    Result[i].AtomDensity := raw[i].atomDensity;
  end;
end;

procedure TStrataEngine.FillMaterialNames(AList: TStrings);
var
  n, i: Integer;
  buf: array[0..127] of AnsiChar;
begin
  AList.BeginUpdate;
  try
    AList.Clear;
    if FSession = nil then Exit;
    n := strata_material_count(FSession);
    for i := 0 to n - 1 do
      if strata_get_material_name(FSession, i, @buf[0], SizeOf(buf)) = STRATA_OK then
        AList.Add(BufToStr(buf));
  finally
    AList.EndUpdate;
  end;
end;

// All materials, including those made with /strata/material/create
procedure TStrataEngine.FillDefinedMaterialNames(AList: TStrings);
var
  n, i: Integer;
  buf: array[0..127] of AnsiChar;
begin
  AList.BeginUpdate;
  try
    AList.Clear;
    if FSession = nil then Exit;
    n := strata_defined_material_count(FSession);
    for i := 0 to n - 1 do
      if strata_get_defined_material_name(FSession, i, @buf[0], SizeOf(buf)) = STRATA_OK then
        AList.Add(BufToStr(buf));
  finally
    AList.EndUpdate;
  end;
end;

procedure TStrataEngine.FillElementNames(AList: TStrings);
var
  n, i: Integer;
  buf: array[0..63] of AnsiChar;
begin
  AList.BeginUpdate;
  try
    AList.Clear;
    if FSession = nil then Exit;
    n := strata_element_count(FSession);
    // The NIST vector is indexed by atomic number, so entry 0 is blank
    for i := 0 to n - 1 do
      if strata_get_element_name(FSession, i, @buf[0], SizeOf(buf)) = STRATA_OK then
        if Trim(BufToStr(buf)) <> '' then
          AList.Add(Trim(BufToStr(buf)));
  finally
    AList.EndUpdate;
  end;
end;


procedure TStrataEngine.FillPhysicsNames(ABase, AOptional: TStrings);
var
  n, i: Integer;
  buf: array[0..63] of AnsiChar;
  name: String;
begin
  if Assigned(ABase) then ABase.Clear;
  if Assigned(AOptional) then AOptional.Clear;
  if not StrataLibraryLoaded then Exit;
  n := strata_physics_count();
  for i := 0 to n - 1 do
  begin
    if strata_get_physics_name(i, @buf[0], SizeOf(buf)) <> STRATA_OK then Continue;
    name := BufToStr(buf);
    if strata_physics_is_optional(i) = 1 then
    begin
      if Assigned(AOptional) then AOptional.Add(name);
    end
    else if Assigned(ABase) then
      ABase.Add(name);
  end;
end;

procedure TStrataEngine.FillParticleNames(AList: TStrings);
var
  n, i: Integer;
  buf: array[0..63] of AnsiChar;
begin
  AList.BeginUpdate;
  try
    AList.Clear;
    if FSession = nil then Exit;
    n := strata_particle_count(FSession);
    for i := 0 to n - 1 do
      if strata_get_particle_name(FSession, i, @buf[0], SizeOf(buf)) = STRATA_OK then
        AList.Add(BufToStr(buf));
  finally
    AList.EndUpdate;
  end;
end;

function TStrataEngine.CommandTree: String;
var
  n: cint;
begin
  Result := '';
  if FSession = nil then Exit;
  n := strata_get_command_tree(FSession, nil, 0);
  if n <= 1 then Exit;
  SetLength(Result, n);
  n := strata_get_command_tree(FSession, PAnsiChar(Result), n);
  SetLength(Result, StrLen(PAnsiChar(Result)));
end;

function TStrataEngine.HistogramCount: Integer;
begin
  if FSession = nil then Exit(0);
  Result := strata_h1_count(FSession);
end;

function StrataEmptySpectrumReason(AId: Integer; AEntries: Double; const AY: array of Double; const APhysics: String): String;
var
  i: Integer;
  total: Double;
  needsRecoils, madeDuringRun: Boolean;
begin
  Result := '';

  // Only a process that partitions the recoil energy (the screened
  // nuclear recoil of standardNR and SRIM) ever sets h1[2]
  needsRecoils := ((AId = 2) or ((AId >= 4) and (AId <= 6)))
                  and (APhysics <> 'standardNR') and (APhysics <> 'srim');

  // 17 and 18 hold neutrons created during the run.  The beam is not one
  // of them, and an elastic scatter continues the same track rather than
  // starting a new one, so a neutron beam in a scattering medium fills
  // nothing at all: it takes a reaction that produces a neutron
  madeDuringRun := (AId = 17) or (AId = 18);

  if AEntries = 0 then
  begin
    if needsRecoils then
      Result := 'Nothing was filled: the nuclear stopping power needs a '
                + 'physics list that produces nuclear recoils (standardNR or SRIM)'
    else if madeDuringRun then
      Result := 'Nothing was filled: this counts neutrons created during the '
                + 'run, which the beam itself is not, and elastic scattering '
                + 'continues a track rather than starting one. For where a '
                + 'neutron beam went, read the transmitted and reflected '
                + 'neutron spectra'
    else
      Result := 'Nothing was filled: no step of this run contributed to it';
    Exit;
  end;

  total := 0;
  for i := 0 to High(AY) do total := total + AY[i];
  if total <> 0 then Exit;

  if needsRecoils then
    Result := Format('%.0f entries but every bin is zero: this spectrum is '
                     + 'weighted by the non-ionizing energy deposit, which '
                     + 'stays zero with the %s physics list, use standardNR '
                     + 'or SRIM to see it', [AEntries, APhysics])
  else
    Result := Format('%.0f entries but every bin is zero: the values fall '
                     + 'outside the axis, or their weight is zero for this '
                     + 'physics list', [AEntries]);
end;

function TStrataEngine.LiveHistogram(AId: Integer; var AHistogram: TStrataHistogram): Boolean;
var
  n, bins: Integer;
  entries: Double;
begin
  Result := False;
  if (FSession = nil) or (AId < 0) then Exit;

  bins := AHistogram.NBins;
  if bins <= 0 then bins := 1000;
  SetLength(AHistogram.X, bins);
  SetLength(AHistogram.Y, bins);

  entries := 0;
  n := strata_get_h1_live(FSession, AId, @AHistogram.X[0], @AHistogram.Y[0],
                          nil, bins, @entries);
  if n <= 0 then
  begin
    SetLength(AHistogram.X, 0);
    SetLength(AHistogram.Y, 0);
    Exit;
  end;

  SetLength(AHistogram.X, n);
  SetLength(AHistogram.Y, n);
  AHistogram.NBins := n;
  AHistogram.Entries := entries;
  Result := True;
end;

function TStrataEngine.Histogram(AId: Integer; AWithData: Boolean): TStrataHistogram;
var
  info: TStrataH1InfoC;
  n: Integer;
begin
  Result := Default(TStrataHistogram);
  Result.Id := AId;
  if FSession = nil then Exit;

  Check(strata_get_h1_info(FSession, AId, @info), Format('histogram %d', [AId]));
  Result.Active := info.active <> 0;
  Result.NBins := info.nbins;
  Result.XMin := info.xMin;
  Result.XMax := info.xMax;
  Result.Width := info.width;
  Result.LogX := info.logX <> 0;
  Result.Unit_ := info.unit_;
  if (info.axis >= Ord(Low(TStrataAxisKind)))
     and (info.axis <= Ord(High(TStrataAxisKind))) then
    Result.Axis := TStrataAxisKind(info.axis)
  else
    Result.Axis := akNone;
  Result.Entries := info.entries;
  Result.Title := BufToStr(info.title);
  Result.XAxisTitle := BufToStr(info.xAxisTitle);
  Result.YAxisTitle := BufToStr(info.yAxisTitle);

  if (not AWithData) or (not Result.Active) or (Result.NBins <= 0) then Exit;

  SetLength(Result.X, Result.NBins);
  SetLength(Result.Y, Result.NBins);
  n := strata_get_h1_data(FSession, AId, @Result.X[0], @Result.Y[0], nil, Result.NBins);
  if n < 0 then
  begin
    SetLength(Result.X, 0);
    SetLength(Result.Y, 0);
    Exit;
  end;
  SetLength(Result.X, n);
  SetLength(Result.Y, n);
end;

end.
