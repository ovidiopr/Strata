unit uStrataApp;

// What the front end needs whatever it shows: the preferences, the backend,
// where Geant4 and its datasets are, and the terminal and viewer it starts.
// No widgets, so the window decides how anything is shown.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, IniFiles, uStrataApi, uStrataEngine;

type
  // The preferences
  TStrataOptions = record
    OutputDir: String;
    Geant4Dir: String;
    DataDir: String;
    LibraryDir: String;
    StrataExe: String;
    Terminal: String;
    // The interface shown last: 'panels' or 'editor'
    LastInterface: String;
  end;

  TStrataNotify = procedure(const AText: String) of object;
  // Asked for the batch executable when it cannot be found, '' to give up
  TStrataAskExe = function(const AStartDir: String): String of object;

  TStrataApp = class
  private
    FIniFile: String;
  public
    Options: TStrataOptions;
    DataDirSet: String;          // what the backend was told about datasets
    OnLog: TStrataNotify;
    OnAskExe: TStrataAskExe;

    constructor Create(const AIniFile: String);

    procedure SavePreferences;
    procedure RestorePreferences;

    function LoadBackend: Boolean;
    procedure ExportGeant4Dir;
    function MissingGeant4Datasets: TStringArray;
    function ConfigureGeant4: String;
    function Geant4DataPath: String;
    function LocateGeant4Data: String;
    procedure Geant4Directories(out AExeDir, ALibDir, AG4Dir, ADataDir: String);
    procedure ApplyGeant4Environment(AProcess: TProcess);

    function LocateStrataExecutable: String;
    function WriteTerminalScript(out AError: String): String;
    function OpenTerminal(out AScript, AError: String): Boolean;

    // A scratch directory for the viewer, with the macros folder it reads
    function NewViewerDirectory(out ADir, AError: String): Boolean;
    // Runs ASetupMac in the viewer, then shoots AEvents
    function LaunchViewer(const ASetupMac: String; AEvents: Integer; out ACommand, AError: String): Boolean;

    procedure Log(const AText: String);
  end;

const
  // Where Geant4 is installed from
  StrataGeant4URL = 'https://github.com/ovidiopr/geant4-installers/releases';

  // The batch executable the viewer and the terminal run
  {$IFDEF WINDOWS}
  StrataExeName = 'Strata.exe';
  {$ELSE}
  StrataExeName = 'Strata';
  {$ENDIF}

// Splits a command line the way a shell would
procedure SplitCommand(const ALine: String; AList: TStrings);

implementation

{$IFDEF UNIX}
uses
  BaseUnix;
{$ENDIF}

{$IFDEF WINDOWS}
function SetEnvironmentVariableW(lpName, lpValue: PWideChar): LongBool; stdcall;
  external 'kernel32.dll' name 'SetEnvironmentVariableW';
{$ENDIF}

procedure SplitCommand(const ALine: String; AList: TStrings);
var
  i: Integer;
  quoted: Boolean;
  item: String;
begin
  AList.Clear;
  item := '';
  quoted := False;
  for i := 1 to Length(ALine) do
    if ALine[i] = '"' then
      quoted := not quoted
    else if (ALine[i] = ' ') and (not quoted) then
    begin
      if item <> '' then AList.Add(item);
      item := '';
    end
    else
      item := item + ALine[i];
  if item <> '' then AList.Add(item);
end;

constructor TStrataApp.Create(const AIniFile: String);
begin
  inherited Create;
  FIniFile := AIniFile;
end;

procedure TStrataApp.Log(const AText: String);
begin
  if Assigned(OnLog) then OnLog(AText);
end;

procedure TStrataApp.SavePreferences;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FIniFile);
  try
    with Options do
    begin
      Ini.WriteString('StrataOptions', 'OutputDir', OutputDir);
      Ini.WriteString('StrataOptions', 'Geant4Dir', Geant4Dir);
      Ini.WriteString('StrataOptions', 'DataDir', DataDir);
      Ini.WriteString('StrataOptions', 'Terminal', Terminal);
      Ini.WriteString('StrataOptions', 'LibraryDir', LibraryDir);
      Ini.WriteString('StrataOptions', 'StrataExe', StrataExe);
      Ini.WriteString('StrataOptions', 'Interface', LastInterface);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TStrataApp.RestorePreferences;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FIniFile);
  try
    with Options do
    begin
      // A setting never saved keeps the value worked out at startup
      OutputDir := Ini.ReadString('StrataOptions', 'OutputDir', OutputDir);
      Geant4Dir := Ini.ReadString('StrataOptions', 'Geant4Dir', Geant4Dir);
      DataDir := Ini.ReadString('StrataOptions', 'DataDir', DataDir);
      Terminal := Ini.ReadString('StrataOptions', 'Terminal', Terminal);
      LibraryDir := Ini.ReadString('StrataOptions', 'LibraryDir', LibraryDir);
      StrataExe := Ini.ReadString('StrataOptions', 'StrataExe', StrataExe);
      LastInterface := Ini.ReadString('StrataOptions', 'Interface', LastInterface);
    end;
  finally
    Ini.Free;
  end;
end;

function TStrataApp.LoadBackend: Boolean;
var
  tried: TStringList;
  err, exeDir, candidate: String;
  i: Integer;

  // Returns True once something loaded
  function TryLoad(const APath, AWhy: String): Boolean;
  begin
    if StrataLibraryLoaded then Exit(True);
    if APath = '' then
      tried.Add('  (dynamic loader search path)        -- ' + AWhy)
    else
      tried.Add('  ' + APath + '   -- ' + AWhy);
    Result := LoadStrataLibrary(APath, err);
    if Result then
      Options.LibraryDir := APath
    else
      tried[tried.Count - 1] := tried[tried.Count - 1] + sLineBreak + '      ' + err;
  end;

begin
  // Before the first call: even strata_version starts the engine
  ExportGeant4Dir;

  exeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  tried := TStringList.Create;
  try
    // An explicit answer always wins
    if Options.LibraryDir <> '' then
      Options.LibraryDir := ExpandFileName(Options.LibraryDir);
    TryLoad(Options.LibraryDir, 'from LibraryDirectory');

    for i := 1 to ParamCount do
      if Copy(ParamStr(i), 1, Length('--strata-lib=')) = '--strata-lib=' then
      begin
        candidate := Copy(ParamStr(i), Length('--strata-lib=') + 1, MaxInt);
        TryLoad(candidate, 'from --strata-lib');
      end;

    if GetEnvironmentVariable('STRATA_LIB') <> '' then
      TryLoad(GetEnvironmentVariable('STRATA_LIB'), 'from $STRATA_LIB');

    TryLoad(exeDir, 'next to the executable');

    {$IFDEF DARWIN}
    // Launched as StrataGUI.app the library sits three levels up, beside the bundle
    TryLoad(ExpandFileName(exeDir + '..' + PathDelim + '..' + PathDelim + '..'), 'beside the .app bundle');
    {$ENDIF}

    // Last resort: the loader's own search path, which a Finder-launched
    // application does not inherit from a shell
    TryLoad('', 'loader search path');

    Result := StrataLibraryLoaded;
    if not Result then
    begin
      Log('The Strata backend library could not be loaded. Tried:');
      for i := 0 to tried.Count - 1 do Log(tried[i]);
      Log('');
      Log('Build libstrata with CMake, then either copy it next to this '
          + 'executable, set STRATA_LIB to it, or pass --strata-lib=<path>.');
      Exit;
    end;
  finally
    tried.Free;
  end;
  Log('Loaded ' + StrataLibraryPath);
end;

// Windows has no run path: the engine finds the Geant4 DLLs through the PATH
// strata.dll gives it, which puts %STRATA_GEANT4_DIR%\bin first
procedure TStrataApp.ExportGeant4Dir;
{$IFDEF WINDOWS}
var
  envName, envValue: UnicodeString;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  envName := 'STRATA_GEANT4_DIR';
  envValue := UnicodeString(ExcludeTrailingPathDelimiter(Trim(Options.Geant4Dir)));
  if envValue = '' then
    SetEnvironmentVariableW(PWideChar(envName), nil)
  else
    SetEnvironmentVariableW(PWideChar(envName), PWideChar(envValue));
  {$ENDIF}
end;

// Geant4 treats a missing dataset as a fatal exception
function TStrataApp.MissingGeant4Datasets: TStringArray;
begin
  // The backend asks Geant4 the question Geant4 will ask itself
  Result := StrataMissingDatasets;
end;

// The backend sets the variables
function TStrataApp.ConfigureGeant4: String;
var
  rc: Integer;
begin
  Result := '';
  if not StrataLibraryLoaded then Exit;

  Result := Geant4DataPath;
  if Result = '' then Exit;

  rc := StrataSetDataDir(Result);
  if rc = STRATA_OK then
  begin
    DataDirSet := Result;
    Log('Geant4 datasets: ' + Result);
  end
  else
  begin
    Log('Could not point Geant4 at ' + Result + ': ' + StrataStatusText(rc));
    Result := '';
  end;
end;

// Where the datasets are, as the preferences have it
function TStrataApp.Geant4DataPath: String;
begin
  Result := ExcludeTrailingPathDelimiter(Trim(Options.DataDir));
  if Result <> '' then
  begin
    if DirectoryExists(Result) then Exit;
    Log('The dataset directory in the preferences does not exist: ' + Result);
  end;
  Result := LocateGeant4Data;
end;

function TStrataApp.LocateGeant4Data: String;
var
  base, share, cand: String;
  found: TSearchRec;
begin
  Result := '';
  base := ExcludeTrailingPathDelimiter(Trim(Options.Geant4Dir));
  if base = '' then Exit;

  share := base + PathDelim + 'share' + PathDelim;
  if DirectoryExists(share + 'Geant4' + PathDelim + 'data') then
    Exit(share + 'Geant4' + PathDelim + 'data');

  if FindFirst(share + 'Geant4-*', faDirectory, found) = 0 then
  begin
    repeat
      cand := share + found.Name + PathDelim + 'data';
      if DirectoryExists(cand) then
      begin
        Result := cand;
        Break;
      end;
    until FindNext(found) <> 0;
    FindClose(found);
  end;
end;

procedure TStrataApp.Geant4Directories(out AExeDir, ALibDir, AG4Dir, ADataDir: String);
begin
  AExeDir := ExcludeTrailingPathDelimiter(ExtractFilePath(LocateStrataExecutable));
  ALibDir := '';
  if StrataLibraryPath <> '' then
    ALibDir := ExcludeTrailingPathDelimiter(ExtractFilePath(StrataLibraryPath));
  AG4Dir := ExcludeTrailingPathDelimiter(Trim(Options.Geant4Dir));
  ADataDir := Geant4DataPath;
end;

// Gives a child process the environment a Geant4 program needs
procedure TStrataApp.ApplyGeant4Environment(AProcess: TProcess);
const
  {$IFDEF DARWIN}
  LibVar = 'DYLD_LIBRARY_PATH';
  {$ELSE}
  LibVar = 'LD_LIBRARY_PATH';
  {$ENDIF}
var
  i: Integer;
  exeDir, libDir, g4Dir, dataDir: String;

  function GetVar(const AName: String): String;
  var
    k: Integer;
  begin
    Result := '';
    for k := 0 to AProcess.Environment.Count - 1 do
      if SameText(AProcess.Environment.Names[k], AName) then
        Exit(AProcess.Environment.ValueFromIndex[k]);
  end;

  // Case-insensitively, because Windows spells it Path as often as PATH
  procedure PutVar(const AName, AValue: String);
  var
    k: Integer;
  begin
    for k := 0 to AProcess.Environment.Count - 1 do
      if SameText(AProcess.Environment.Names[k], AName) then
      begin
        AProcess.Environment[k] := AProcess.Environment.Names[k] + '=' + AValue;
        Exit;
      end;
    AProcess.Environment.Add(AName + '=' + AValue);
  end;

  procedure Prepend(const AName, ADir: String);
  var
    was: String;
  begin
    if ADir = '' then Exit;
    was := GetVar(AName);
    if was = '' then PutVar(AName, ADir)
    else PutVar(AName, ADir + PathSeparator + was);
  end;

begin
  Geant4Directories(exeDir, libDir, g4Dir, dataDir);

  // An empty Environment means "inherit", so it is filled before it is edited
  AProcess.Environment.Clear;
  for i := 1 to GetEnvironmentVariableCount do
    AProcess.Environment.Add(GetEnvironmentString(i));

  if g4Dir <> '' then
    Prepend('PATH', IncludeTrailingPathDelimiter(g4Dir) + 'bin');
  Prepend('PATH', exeDir);
  {$IFNDEF WINDOWS}
  Prepend(LibVar, libDir);
  {$ENDIF}
  if dataDir <> '' then PutVar('GEANT4_DATA_DIR', dataDir);
end;

// Looks for the batch executable, and asks as a last resort
function TStrataApp.LocateStrataExecutable: String;

  function TryFind(const APath: String): Boolean;
  begin
    Result := (APath <> '') and FileExists(APath);
    if Result then Options.StrataExe := APath;
  end;

var
  i: Integer;
  exeDir, libDir: String;
begin
  if (Options.StrataExe <> '') and FileExists(Options.StrataExe) then
    Exit(Options.StrataExe);

  exeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  libDir := '';
  if StrataLibraryPath <> '' then
    libDir := IncludeTrailingPathDelimiter(ExtractFilePath(StrataLibraryPath));

  for i := 1 to ParamCount do
    if Copy(ParamStr(i), 1, Length('--strata-exe=')) = '--strata-exe=' then
      if TryFind(Copy(ParamStr(i), Length('--strata-exe=') + 1, MaxInt)) then
        Exit(Options.StrataExe);

  if TryFind(GetEnvironmentVariable('STRATA_EXE')) then
    Exit(Options.StrataExe);
  // The library and the batch executable come out of the same build
  if TryFind(libDir + StrataExeName) then Exit(Options.StrataExe);
  if TryFind(exeDir + StrataExeName) then Exit(Options.StrataExe);
  {$IFDEF DARWIN}
  // Launched as StrataGUI.app the executable sits three levels up, beside the bundle
  if TryFind(ExpandFileName(exeDir + '..' + PathDelim + '..' + PathDelim + '..'
             + PathDelim + StrataExeName)) then Exit(Options.StrataExe);
  {$ENDIF}

  Options.StrataExe := '';
  if Assigned(OnAskExe) then TryFind(OnAskExe(libDir));
  Result := Options.StrataExe;
end;

// The environment a terminal needs goes into a script
function TStrataApp.WriteTerminalScript(out AError: String): String;
const
  {$IFDEF DARWIN}
  LibVar = 'DYLD_LIBRARY_PATH';
  {$ELSE}
  LibVar = 'LD_LIBRARY_PATH';
  {$ENDIF}
var
  sh: TStringList;
  exe, exeDir, libDir, g4Dir, g4Script, dataDir, outDir: String;
begin
  Result := '';
  AError := '';
  exe := LocateStrataExecutable;
  if exe = '' then Exit;

  Geant4Directories(exeDir, libDir, g4Dir, dataDir);
  outDir := ExcludeTrailingPathDelimiter(Trim(Options.OutputDir));
  if not DirectoryExists(outDir) then
    outDir := ExcludeTrailingPathDelimiter(GetUserDir);

  sh := TStringList.Create;
  try
    {$IFDEF WINDOWS}
    Result := IncludeTrailingPathDelimiter(GetTempDir) + 'strata-shell.bat';
    sh.Add('@echo off');
    sh.Add('rem Written by the Strata front end, it can be deleted at any time');
    if g4Dir <> '' then
      sh.Add(Format('set "PATH=%s\bin;%%PATH%%"', [g4Dir]));
    sh.Add(Format('set "PATH=%s;%%PATH%%"', [exeDir]));
    if dataDir <> '' then
      sh.Add(Format('set "GEANT4_DATA_DIR=%s"', [dataDir]));
    sh.Add(Format('cd /d "%s"', [outDir]));
    sh.Add('echo Strata is on the PATH, Strata --help says how to use it');
    {$ELSE}
    Result := IncludeTrailingPathDelimiter(GetTempDir) + 'strata-shell.sh';
    sh.Add('#!/bin/sh');
    sh.Add('# Written by the Strata front end, it can be deleted at any time');
    // Geant4's own script is used only when the datasets were not found
    g4Script := g4Dir + '/bin/geant4.sh';
    if dataDir <> '' then
    begin
      sh.Add(Format('GEANT4_DATA_DIR="%s"', [dataDir]));
      sh.Add('export GEANT4_DATA_DIR');
    end
    else if (g4Dir <> '') and FileExists(g4Script) then
      sh.Add(Format('. "%s"', [g4Script]));
    if g4Dir <> '' then
      sh.Add(Format('PATH="%s/bin:$PATH"', [g4Dir]));
    sh.Add(Format('PATH="%s:$PATH"', [exeDir]));
    sh.Add('export PATH');
    if libDir <> '' then
    begin
      sh.Add(Format('%s="%s:$%s"', [LibVar, libDir, LibVar]));
      sh.Add('export ' + LibVar);
    end;
    sh.Add(Format('cd "%s"', [outDir]));
    sh.Add('echo "Strata is on the PATH, Strata --help says how to use it"');
    // The window belongs to the shell from here on, not to this script
    sh.Add('exec "${SHELL:-/bin/sh}"');
    {$ENDIF}
    try
      sh.SaveToFile(Result);
    except
      on E: Exception do
      begin
        AError := 'Could not write' + LineEnding + Result + LineEnding + LineEnding + E.Message;
        Exit('');
      end;
    end;
  finally
    sh.Free;
  end;
  {$IFDEF UNIX}
  FpChmod(Result, &755);
  {$ENDIF}
end;

// There is no standard way to open a terminal, least of all on Unix, so the
// script is handed to whatever the platform has
function TStrataApp.OpenTerminal(out AScript, AError: String): Boolean;
{$IF DEFINED(UNIX) AND NOT DEFINED(DARWIN)}
const
  // %s is where the script goes; the first one installed wins
  Terminals: array[0..5] of String = (
    'x-terminal-emulator -e %s',
    'gnome-terminal -- %s',
    'konsole -e %s',
    'xfce4-terminal -x %s',
    'mate-terminal -- %s',
    'xterm -e %s');
{$ENDIF}
var
  child: TProcess;
  {$IF DEFINED(UNIX) AND NOT DEFINED(DARWIN)}
  cmd: String;
  i: Integer;
  {$ENDIF}
begin
  Result := False;
  AScript := WriteTerminalScript(AError);
  if AScript = '' then Exit;

  child := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    child.Executable := 'cmd.exe';
    child.Parameters.Add('/K');
    child.Parameters.Add(AScript);
    child.Options := [poNewConsole];
    {$ENDIF}
    {$IFDEF DARWIN}
    child.Executable := '/usr/bin/open';
    child.Parameters.Add('-a');
    child.Parameters.Add('Terminal');
    child.Parameters.Add(AScript);
    {$ENDIF}
    {$IF DEFINED(UNIX) AND NOT DEFINED(DARWIN)}
    cmd := Trim(Options.Terminal);
    if cmd = '' then
      for i := Low(Terminals) to High(Terminals) do
        if ExeSearch(Copy(Terminals[i], 1, Pos(' ', Terminals[i]) - 1),
                     GetEnvironmentVariable('PATH')) <> '' then
        begin
          cmd := Terminals[i];
          Break;
        end;
    if cmd = '' then
    begin
      AError := 'No terminal emulator was found.' + LineEnding + LineEnding
                + 'Name one under Terminal Command in the preferences, '
                + 'writing %s where the script to run goes.';
      Exit;
    end;
    if Pos('%s', cmd) > 0 then
      cmd := StringReplace(cmd, '%s', AScript, [rfReplaceAll])
    else
      cmd := cmd + ' ' + AScript;
    SplitCommand(cmd, child.Parameters);
    child.Executable := child.Parameters[0];
    child.Parameters.Delete(0);
    {$ENDIF}
    try
      child.Execute;
    except
      on E: Exception do
      begin
        AError := 'Could not start' + LineEnding + child.Executable
                  + LineEnding + LineEnding + E.Message;
        Exit;
      end;
    end;
  finally
    child.Free;
  end;
  Result := True;
end;

function TStrataApp.NewViewerDirectory(out ADir, AError: String): Boolean;
begin
  AError := '';
  ADir := IncludeTrailingPathDelimiter(GetTempDir) + 'strata-viewer-'
          + FormatDateTime('yyyymmdd-hhnnss', Now);
  Result := ForceDirectories(ADir + PathDelim + 'macros');
  if Result then
    ADir := IncludeTrailingPathDelimiter(ADir)
  else
    AError := 'Could not create a scratch directory at' + LineEnding + ADir;
end;

function TStrataApp.LaunchViewer(const ASetupMac: String; AEvents: Integer; out ACommand, AError: String): Boolean;
const
  // Used when the executable has no macros/vis.mac beside it
  FallbackVis: array[0..11] of String = (
    '/vis/open OGLI 600x600-0+0',
    '/vis/viewer/set/autoRefresh false',
    '/vis/verbose errors',
    '/vis/drawVolume',
    '/vis/viewer/set/viewpointThetaPhi 0. 0.',
    '/vis/viewer/zoom 1.4',
    '/vis/scene/add/trajectories smooth',
    '/vis/modeling/trajectories/create/drawByCharge',
    '/vis/modeling/trajectories/drawByCharge-0/default/setDrawStepPts true',
    '/vis/scene/endOfEventAction accumulate',
    '/vis/viewer/set/autoRefresh true',
    '/vis/verbose warnings');
var
  exe, exeDir, dir: String;
  vis: TStringList;
  child: TProcess;
  i: Integer;
begin
  Result := False;
  ACommand := '';
  AError := '';
  exe := LocateStrataExecutable;
  if exe = '' then
  begin
    AError := 'No Strata executable, no viewer';
    Exit;
  end;
  exeDir := IncludeTrailingPathDelimiter(ExtractFilePath(exe));
  dir := IncludeTrailingPathDelimiter(ExtractFilePath(ASetupMac));

  // The project's own vis.mac if there is one
  vis := TStringList.Create;
  try
    if FileExists(exeDir + 'macros' + PathDelim + 'vis.mac') then
      vis.LoadFromFile(exeDir + 'macros' + PathDelim + 'vis.mac')
    else
      for i := Low(FallbackVis) to High(FallbackVis) do vis.Add(FallbackVis[i]);
    vis.Add('');
    vis.Add('# added by the Strata front end: shoot after the viewer is up');
    if AEvents > 0 then vis.Add(Format('/run/beamOn %d', [AEvents]));
    vis.SaveToFile(dir + 'macros' + PathDelim + 'vis.mac');
  finally
    vis.Free;
  end;

  child := TProcess.Create(nil);
  try
    child.Executable := exe;
    child.Parameters.Add('-g');
    child.Parameters.Add('-n');
    child.Parameters.Add('1');
    child.Parameters.Add(ASetupMac);
    // vis.mac is looked up relative to the working directory
    child.CurrentDirectory := ExcludeTrailingPathDelimiter(dir);
    ApplyGeant4Environment(child);
    // A console of its own, because a G4UIExecutive built without Qt falls
    // back to a terminal session
    child.Options := [{$IFDEF WINDOWS}poNewConsole{$ENDIF}];
    try
      child.Execute;
    except
      on E: Exception do
      begin
        AError := 'Could not start' + LineEnding + exe + LineEnding + LineEnding + E.Message;
        Exit;
      end;
    end;
  finally
    child.Free;
  end;
  ACommand := exe + ' -g -n 1 ' + ASetupMac;
  Result := True;
end;

end.
