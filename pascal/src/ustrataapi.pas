{==============================================================================
  uStrataApi.pas: raw Free Pascal binding to libstrata (api/strata_api.h).

  This unit is a mechanical translation of the C header and nothing else: no
  classes, no conveniences, no state beyond the loaded library handle.  The
  friendly interface lives in uStrataEngine.

  The library is loaded at run time rather than linked, so the GUI starts and
  can report a useful message even when the backend or Geant4 is missing.
  Call LoadStrataLibrary before touching anything else.

  Record layouts must match the C structs byte for byte.  {$PACKRECORDS C}
  gets the alignment right, and LoadStrataLibrary additionally asks the
  library for its own sizeof() values and refuses to load on a mismatch --
  a wrong layout would otherwise show up as plausible-looking but wrong
  numbers in the user interface.
==============================================================================}

unit uStrataApi;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  SysUtils, ctypes, DynLibs;

const
  {$IFDEF WINDOWS}
  StrataDefaultLibName = 'strata.' + SharedSuffix;
  {$ELSE}
  StrataDefaultLibName = 'libstrata.' + SharedSuffix;
  {$ENDIF}

  { StrataStatus }
  STRATA_OK =  0;
  STRATA_ERR_HANDLE = -1;
  STRATA_ERR_STATE = -2;
  STRATA_ERR_COMMAND = -3;
  STRATA_ERR_RANGE = -4;
  STRATA_ERR_INTERNAL = -5;

  { StrataState }
  STRATA_STATE_IDLE = 0;
  STRATA_STATE_INITIALISED = 1;
  STRATA_STATE_RUNNING = 2;
  STRATA_STATE_ABORTING = 3;

  { StrataStructId }
  STRATA_SIZE_RUN_STATS = 0;
  STRATA_SIZE_VOXEL_RESULT = 1;
  STRATA_SIZE_LAYER_INFO = 2;
  STRATA_SIZE_VOXEL_INFO = 3;
  STRATA_SIZE_H1_INFO = 4;
  STRATA_SIZE_DATASET = 5;
  STRATA_SIZE_MATERIAL_INFO = 6;
  STRATA_SIZE_ELEMENT_FRACTION = 7;

type
  PStrataSession = type Pointer;

  TStrataRunStatsC = record
    valid: cint;
    events: clong;

    particle: array[0..63] of AnsiChar;
    beamEnergy: cdouble;
    targetThickness: cdouble;
    layers: cint;
    meanDensity: cdouble;

    edep, edepRms: cdouble;
    niel, nielRms: cdouble;
    energyBalance: cdouble;

    projRange, projRangeRms: cdouble;
    meanPrimarySteps: cdouble;

    trakLenCharged, trakLenChargedRms: cdouble;
    trakLenNeutral, trakLenNeutralRms: cdouble;
    stepsCharged, stepsChargedRms: cdouble;
    stepsNeutral, stepsNeutralRms: cdouble;

    gammaPerEvent, electronPerEvent, positronPerEvent: cdouble;

    transmitPrimary, transmitAny: cdouble;
    reflectPrimary, reflectAny: cdouble;

    leakPrimary, leakPrimaryRms: cdouble;
    leakSecondary, leakSecondaryRms: cdouble;

    meanDEdx: cdouble;
    stoppingPower: cdouble;
    dedxRestricted: cdouble;
    dedxFull: cdouble;
    stopPowerRestricted: cdouble;
    stopPowerFull: cdouble;

    mscRms: cdouble;
    mscHighland: cdouble;
    mscThetaCentral: cdouble;
    mscTailRatio: cdouble;
  end;
  PStrataRunStatsC = ^TStrataRunStatsC;

  TStrataVoxelResultC = record
    edep: cdouble;
    ratio: cdouble;
    dose: cdouble;
    mass: cdouble;
  end;
  PStrataVoxelResultC = ^TStrataVoxelResultC;

  TStrataLayerInfoC = record
    thickness: cdouble;
    density: cdouble;
    xMin, xMax: cdouble;
    material: array[0..127] of AnsiChar;
  end;
  PStrataLayerInfoC = ^TStrataLayerInfoC;

  TStrataVoxelInfoC = record
    sizeX, sizeY, sizeZ: cdouble;
    posX, posY, posZ: cdouble;
    mass: cdouble;
  end;
  PStrataVoxelInfoC = ^TStrataVoxelInfoC;

  TStrataH1InfoC = record
    id: cint;
    active: cint;
    nbins: cint;
    axis: cint;              // a StrataAxisKind
    xMin, xMax, width: cdouble;
    logX: cint;              // the bins are spaced logarithmically
    unit_: cdouble;          // 'unit' is a reserved word in Pascal
    entries: cdouble;
    title: array[0..255] of AnsiChar;
    xAxisTitle: array[0..127] of AnsiChar;
    yAxisTitle: array[0..127] of AnsiChar;
  end;
  PStrataH1InfoC = ^TStrataH1InfoC;

  // One Geant4 dataset, as Geant4 itself resolves it
  TStrataDatasetC = record
    variable: array[0..31] of AnsiChar;
    path: array[0..511] of AnsiChar;
    present: cint;
    required: cint;
  end;
  PStrataDatasetC = ^TStrataDatasetC;

  // Which of Geant4's five groups a predefined material belongs to
  TStrataMaterialInfoC = record
    name: array[0..63] of AnsiChar;
    group: cint;
    density: cdouble;        // g/cm3, 0 when Geant4 records none
  end;
  PStrataMaterialInfoC = ^TStrataMaterialInfoC;

  // One element of a material.  The mass fraction is what Geant4 stores
  // whichever way the recipe was written; the atom fraction and the number
  // density come from the vectors the transport uses, so they are right for
  // a recipe given by mass as well as one given by atom count
  TStrataElementFractionC = record
    name: array[0..63] of AnsiChar;
    symbol: array[0..7] of AnsiChar;
    z: cint;                 // atomic number
    a: cdouble;              // molar mass, g/mole
    massFraction: cdouble;   // of the material's mass, 0 to 1
    atomFraction: cdouble;   // of its atoms, 0 to 1
    atomDensity: cdouble;    // atoms per cm3
  end;
  PStrataElementFractionC = ^TStrataElementFractionC;

var
  { Lifecycle }
  strata_version: function: PAnsiChar; cdecl;
  strata_geant4_version: function: PAnsiChar; cdecl;
  strata_struct_size: function(which: cint): cint; cdecl;
  strata_dataset_count: function: cint; cdecl;
  strata_get_dataset: function(index: cint; out_: PStrataDatasetC): cint; cdecl;
  strata_set_data_dir: function(dir: PAnsiChar): cint; cdecl;
  strata_get_material_info: function(s: PStrataSession; index: cint; out_: PStrataMaterialInfoC): cint; cdecl;
  strata_create: function(nThreads: cint): PStrataSession; cdecl;
  strata_destroy: procedure(s: PStrataSession); cdecl;
  strata_initialize: function(s: PStrataSession): cint; cdecl;
  strata_thread_count: function(s: PStrataSession): cint; cdecl;

  { Control }
  strata_apply: function(s: PStrataSession; command: PAnsiChar): cint; cdecl;
  strata_execute_macro: function(s: PStrataSession; path: PAnsiChar): cint; cdecl;
  strata_beam_on: function(s: PStrataSession; nEvents: clong): cint; cdecl;
  strata_abort: function(s: PStrataSession): cint; cdecl;
  strata_wait: function(s: PStrataSession; timeoutMs: cint): cint; cdecl;
  strata_state: function(s: PStrataSession): cint; cdecl;
  strata_events_done: function(s: PStrataSession): clong; cdecl;
  strata_events_requested: function(s: PStrataSession): clong; cdecl;
  strata_progress: function(s: PStrataSession): cdouble; cdecl;
  strata_run_status: function(s: PStrataSession): cint; cdecl;

  { Log }
  strata_log_pop: function(s: PStrataSession; buf: PAnsiChar; bufLen: cint; isError: pcint): cint; cdecl;
  strata_log_pending: function(s: PStrataSession): cint; cdecl;
  strata_log_clear: procedure(s: PStrataSession); cdecl;
  strata_log_dropped: function(s: PStrataSession): clong; cdecl;

  { Results }
  strata_get_stats: function(s: PStrataSession; out_: PStrataRunStatsC): cint; cdecl;
  strata_voxel_result_count: function(s: PStrataSession): cint; cdecl;
  strata_get_voxel_result: function(s: PStrataSession; index: cint; out_: PStrataVoxelResultC): cint; cdecl;

  { Geometry }
  strata_layer_count: function(s: PStrataSession): cint; cdecl;
  strata_get_layer: function(s: PStrataSession; index: cint; out_: PStrataLayerInfoC): cint; cdecl;
  strata_voxel_count: function(s: PStrataSession): cint; cdecl;
  strata_get_voxel: function(s: PStrataSession; index: cint; out_: PStrataVoxelInfoC): cint; cdecl;
  strata_get_random: function(s: PStrataSession; engine: PAnsiChar; engineCap: cint; seed1, seed2: pclong; randomize: pcint): cint; cdecl;
  strata_world_size: function(s: PStrataSession; sizeX, sizeYZ: pcdouble): cint; cdecl;
  strata_get_world_material: function(s: PStrataSession; buf: PAnsiChar; bufLen: cint): cint; cdecl;
  strata_get_temperature: function(s: PStrataSession): cdouble; cdecl;

  { Catalogues }
  strata_material_count: function(s: PStrataSession): cint; cdecl;
  strata_get_material_name: function(s: PStrataSession; index: cint; buf: PAnsiChar; bufLen: cint): cint; cdecl;
  strata_get_material_composition: function(s: PStrataSession; name: PAnsiChar;
    out_: PStrataElementFractionC; maxOut: cint): cint; cdecl;
  strata_defined_material_count: function(s: PStrataSession): cint; cdecl;
  strata_get_defined_material_name: function(s: PStrataSession; index: cint; buf: PAnsiChar; bufLen: cint): cint; cdecl;
  strata_element_count: function(s: PStrataSession): cint; cdecl;
  strata_get_element_name: function(s: PStrataSession; index: cint; buf: PAnsiChar; bufLen: cint): cint; cdecl;
  strata_damage_defaults: function(material: PAnsiChar; ed, b, c: PDouble): cint; cdecl;
  strata_physics_count: function: cint; cdecl;
  strata_get_physics_name: function(index: cint; buf: PAnsiChar; bufLen: cint): cint; cdecl;
  strata_physics_is_optional: function(index: cint): cint; cdecl;
  strata_particle_count: function(s: PStrataSession): cint; cdecl;
  strata_get_particle_name: function(s: PStrataSession; index: cint; buf: PAnsiChar; bufLen: cint): cint; cdecl;
  strata_get_command_tree: function(s: PStrataSession; buf: PAnsiChar; bufLen: cint): cint; cdecl;

  { Histograms }
  strata_h1_count: function(s: PStrataSession): cint; cdecl;
  strata_get_h1_info: function(s: PStrataSession; id: cint; out_: PStrataH1InfoC): cint; cdecl;
  strata_get_h1_data: function(s: PStrataSession; id: cint; centres, heights, errors: pcdouble; maxBins: cint): cint; cdecl;
  strata_get_h1_live: function(s: PStrataSession; id: cint; centres, heights, errors: pcdouble; maxBins: cint; entries: pcdouble): cint; cdecl;

  { Errors and termination }
  strata_last_error: function(s: PStrataSession): PAnsiChar; cdecl;
  strata_exit_process: procedure(code: cint); cdecl;

{ Loads the backend }
function LoadStrataLibrary(const APath: String; out AError: String): Boolean;
procedure UnloadStrataLibrary;
function StrataLibraryLoaded: Boolean;
function StrataLibraryPath: String;

{ Human-readable form of a StrataStatus. }
function StrataStatusText(AStatus: Integer): String;

implementation

var
  gHandle: TLibHandle = NilHandle;
  gPath: String = '';

function StrataLibraryLoaded: Boolean;
begin
  Result := gHandle <> NilHandle;
end;

function StrataLibraryPath: String;
begin
  Result := gPath;
end;

function StrataStatusText(AStatus: Integer): String;
begin
  case AStatus of
    STRATA_OK: Result := 'ok';
    STRATA_ERR_HANDLE: Result := 'invalid session handle';
    STRATA_ERR_STATE: Result := 'wrong state for this operation';
    STRATA_ERR_COMMAND: Result := 'command rejected by Geant4';
    STRATA_ERR_RANGE: Result := 'argument out of range';
    STRATA_ERR_INTERNAL: Result := 'internal error in the backend';
  else
    Result := Format('unknown status %d', [AStatus]);
  end;
end;

// Resolves one symbol, recording the first failure
procedure Bind(var ATarget: Pointer; const AName: String; var AMissing: String);
var
  p: Pointer;
begin
  p := GetProcedureAddress(gHandle, AName);
  if p = nil then
  begin
    if AMissing <> '' then AMissing := AMissing + ', ';
    AMissing := AMissing + AName;
  end;
  ATarget := p;
end;

function BindAll(out AMissing: String): Boolean;
begin
  AMissing := '';
  Bind(Pointer(strata_version), 'strata_version', AMissing);
  Bind(Pointer(strata_geant4_version), 'strata_geant4_version', AMissing);
  Bind(Pointer(strata_struct_size), 'strata_struct_size', AMissing);
  Bind(Pointer(strata_dataset_count), 'strata_dataset_count', AMissing);
  Bind(Pointer(strata_get_dataset), 'strata_get_dataset', AMissing);
  Bind(Pointer(strata_set_data_dir), 'strata_set_data_dir', AMissing);
  Bind(Pointer(strata_get_material_info), 'strata_get_material_info', AMissing);
  Bind(Pointer(strata_create), 'strata_create', AMissing);
  Bind(Pointer(strata_destroy), 'strata_destroy', AMissing);
  Bind(Pointer(strata_initialize), 'strata_initialize', AMissing);
  Bind(Pointer(strata_thread_count), 'strata_thread_count', AMissing);

  Bind(Pointer(strata_apply), 'strata_apply', AMissing);
  Bind(Pointer(strata_execute_macro), 'strata_execute_macro', AMissing);
  Bind(Pointer(strata_beam_on), 'strata_beam_on', AMissing);
  Bind(Pointer(strata_abort), 'strata_abort', AMissing);
  Bind(Pointer(strata_wait), 'strata_wait', AMissing);
  Bind(Pointer(strata_state), 'strata_state', AMissing);
  Bind(Pointer(strata_events_done), 'strata_events_done', AMissing);
  Bind(Pointer(strata_events_requested), 'strata_events_requested', AMissing);
  Bind(Pointer(strata_progress), 'strata_progress', AMissing);
  Bind(Pointer(strata_run_status), 'strata_run_status', AMissing);

  Bind(Pointer(strata_log_pop), 'strata_log_pop', AMissing);
  Bind(Pointer(strata_log_pending), 'strata_log_pending', AMissing);
  Bind(Pointer(strata_log_clear), 'strata_log_clear', AMissing);
  Bind(Pointer(strata_log_dropped), 'strata_log_dropped', AMissing);

  Bind(Pointer(strata_get_stats), 'strata_get_stats', AMissing);
  Bind(Pointer(strata_voxel_result_count), 'strata_voxel_result_count', AMissing);
  Bind(Pointer(strata_get_voxel_result), 'strata_get_voxel_result', AMissing);

  Bind(Pointer(strata_layer_count), 'strata_layer_count', AMissing);
  Bind(Pointer(strata_get_layer), 'strata_get_layer', AMissing);
  Bind(Pointer(strata_voxel_count), 'strata_voxel_count', AMissing);
  Bind(Pointer(strata_get_voxel), 'strata_get_voxel', AMissing);
  Bind(Pointer(strata_get_random), 'strata_get_random', AMissing);
  Bind(Pointer(strata_world_size), 'strata_world_size', AMissing);
  Bind(Pointer(strata_get_world_material), 'strata_get_world_material', AMissing);
  Bind(Pointer(strata_get_temperature), 'strata_get_temperature', AMissing);

  Bind(Pointer(strata_material_count), 'strata_material_count', AMissing);
  Bind(Pointer(strata_get_material_name), 'strata_get_material_name', AMissing);
  Bind(Pointer(strata_get_material_composition), 'strata_get_material_composition', AMissing);
  Bind(Pointer(strata_defined_material_count), 'strata_defined_material_count', AMissing);
  Bind(Pointer(strata_get_defined_material_name), 'strata_get_defined_material_name', AMissing);
  Bind(Pointer(strata_element_count), 'strata_element_count', AMissing);
  Bind(Pointer(strata_get_element_name), 'strata_get_element_name', AMissing);
  Bind(Pointer(strata_damage_defaults), 'strata_damage_defaults', AMissing);
  Bind(Pointer(strata_physics_count), 'strata_physics_count', AMissing);
  Bind(Pointer(strata_get_physics_name), 'strata_get_physics_name', AMissing);
  Bind(Pointer(strata_physics_is_optional), 'strata_physics_is_optional', AMissing);
  Bind(Pointer(strata_particle_count), 'strata_particle_count', AMissing);
  Bind(Pointer(strata_get_particle_name), 'strata_get_particle_name', AMissing);
  Bind(Pointer(strata_get_command_tree), 'strata_get_command_tree', AMissing);

  Bind(Pointer(strata_h1_count), 'strata_h1_count', AMissing);
  Bind(Pointer(strata_get_h1_info), 'strata_get_h1_info', AMissing);
  Bind(Pointer(strata_get_h1_data), 'strata_get_h1_data', AMissing);
  Bind(Pointer(strata_get_h1_live), 'strata_get_h1_live', AMissing);

  Bind(Pointer(strata_last_error), 'strata_last_error', AMissing);
  Bind(Pointer(strata_exit_process), 'strata_exit_process', AMissing);

  Result := AMissing = '';
end;

// Compares the record sizes this unit was compiled with against the ones the library reports
function CheckLayouts(out AError: String): Boolean;

  function One(AId: Integer; APascalSize: Integer; const AName: String): Boolean;
  var
    cSize: Integer;
    why: PAnsiChar;
  begin
    cSize := strata_struct_size(AId);
    Result := cSize = APascalSize;
    if Result then Exit;
    // The sizes come from the engine process, so a negative one is a status:
    // the engine could not be started or did not answer, and the library
    // knows why
    if cSize < 0 then
    begin
      why := strata_last_error(nil);
      if (why <> nil) and (why^ <> #0) then
        AError := 'The Strata engine could not be started: ' + String(AnsiString(why))
      else
        AError := Format('The Strata engine could not be started (status %d)', [cSize]);
    end
    else
      AError := Format('Record layout mismatch for %s: the library says %d bytes, '
                       + 'this binding says %d', [AName, cSize, APascalSize]);
  end;

begin
  AError := '';
  Result := One(STRATA_SIZE_RUN_STATS, SizeOf(TStrataRunStatsC), 'StrataRunStats')
        and One(STRATA_SIZE_VOXEL_RESULT, SizeOf(TStrataVoxelResultC), 'StrataVoxelResult')
        and One(STRATA_SIZE_LAYER_INFO, SizeOf(TStrataLayerInfoC), 'StrataLayerInfo')
        and One(STRATA_SIZE_VOXEL_INFO, SizeOf(TStrataVoxelInfoC), 'StrataVoxelInfo')
        and One(STRATA_SIZE_H1_INFO, SizeOf(TStrataH1InfoC), 'StrataH1Info')
        and One(STRATA_SIZE_DATASET, SizeOf(TStrataDatasetC), 'StrataDataset')
        and One(STRATA_SIZE_MATERIAL_INFO, SizeOf(TStrataMaterialInfoC), 'StrataMaterialInfo')
        and One(STRATA_SIZE_ELEMENT_FRACTION, SizeOf(TStrataElementFractionC), 'StrataElementFraction');
end;

function LoadStrataLibrary(const APath: String; out AError: String): Boolean;
var
  candidate: String;
  missing: String;
begin
  AError := '';
  if gHandle <> NilHandle then
    Exit(True);

  if APath = '' then
    candidate := StrataDefaultLibName
  else if DirectoryExists(APath) then
    candidate := IncludeTrailingPathDelimiter(APath) + StrataDefaultLibName
  else
    candidate := APath;

  gHandle := LoadLibrary(candidate);
  if gHandle = NilHandle then
  begin
    AError := Format('Cannot load %s: %s', [candidate, GetLoadErrorStr]);
    Exit(False);
  end;
  gPath := candidate;

  if not BindAll(missing) then
  begin
    AError := Format('%s is missing these entry points: %s', [candidate, missing]);
    UnloadStrataLibrary;
    Exit(False);
  end;

  if not CheckLayouts(AError) then
  begin
    UnloadStrataLibrary;
    Exit(False);
  end;

  Result := True;
end;

procedure UnloadStrataLibrary;
begin
  if gHandle <> NilHandle then
  begin
    UnloadLibrary(gHandle);
    gHandle := NilHandle;
    gPath := '';
  end;
end;

end.
