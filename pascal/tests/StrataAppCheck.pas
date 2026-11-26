{==============================================================================
  StrataAppCheck.pas: what uStrataApp does without a window.
  Preferences, the dataset lookup, the environment a child process gets, the
  terminal script and the backend load.  Needs no display; the backend is
  loaded only if one is given.
  Usage: StrataAppCheck [library-path-or-directory]
==============================================================================}

program StrataAppCheck;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process, uStrataApi, uStrataApp;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AWhat: string);
begin
  WriteLn(Format('%-56s %s', [AWhat, BoolToStr(ACondition, 'ok', 'FAILED')]));
  if not ACondition then Inc(Failures);
end;

type
  TSink = class
    Lines: TStringList;
    Asked: Integer;
    Answer: String;
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AText: String);
    function Ask(const AStartDir: String): String;
  end;

constructor TSink.Create;
begin
  Lines := TStringList.Create;
end;

destructor TSink.Destroy;
begin
  Lines.Free;
  inherited;
end;

procedure TSink.Log(const AText: String);
begin
  Lines.Add(AText);
end;

function TSink.Ask(const AStartDir: String): String;
begin
  Inc(Asked);
  Result := Answer;
end;

function Touch(const APath: String): String;
var
  f: TStringList;
begin
  ForceDirectories(ExtractFilePath(APath));
  f := TStringList.Create;
  try
    f.SaveToFile(APath);
  finally
    f.Free;
  end;
  Result := APath;
end;

function EnvOf(AProcess: TProcess; const AName: String): String;
var
  k: Integer;
begin
  Result := '';
  for k := 0 to AProcess.Environment.Count - 1 do
    if SameText(AProcess.Environment.Names[k], AName) then
      Exit(AProcess.Environment.ValueFromIndex[k]);
end;

var
  root, ini, g4, exe, script, err, dir, cmd: String;
  app, back: TStrataApp;
  sink: TSink;
  child: TProcess;
  words: TStringList;
  sh: TStringList;
begin
  root := IncludeTrailingPathDelimiter(GetTempDir) + 'strata-app-check-'
          + IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(root);
  // With no library loaded the executable is also looked for in the current
  // directory, which must not be a build tree here
  ChDir(root);
  ini := root + 'strata.ini';
  sink := TSink.Create;
  app := TStrataApp.Create(ini);
  app.OnLog := @sink.Log;
  app.OnAskExe := @sink.Ask;
  try
    { --- a command line split the way a shell would --- }
    words := TStringList.Create;
    try
      SplitCommand('gnome-terminal -- "/a dir/strata shell.sh"  -x', words);
      Check((words.Count = 4) and (words[2] = '/a dir/strata shell.sh') and (words[3] = '-x'),
            'a quoted path stays one word, doubled spaces are one');
    finally
      words.Free;
    end;

    { --- preferences go out and come back --- }
    app.Options.OutputDir := root + 'out';
    app.Options.Geant4Dir := root + 'g4';
    app.Options.DataDir := '';
    app.Options.LibraryDir := root + 'lib';
    app.Options.StrataExe := root + 'bin' + PathDelim + StrataExeName;
    app.Options.Terminal := 'xterm -e %s';
    app.Options.LastInterface := 'editor';
    app.SavePreferences;
    back := TStrataApp.Create(ini);
    try
      back.Options.OutputDir := 'kept';
      back.RestorePreferences;
      Check((back.Options.Geant4Dir = app.Options.Geant4Dir)
            and (back.Options.LibraryDir = app.Options.LibraryDir)
            and (back.Options.StrataExe = app.Options.StrataExe)
            and (back.Options.Terminal = app.Options.Terminal)
            and (back.Options.LastInterface = 'editor')
            and (back.Options.OutputDir = app.Options.OutputDir),
            'every preference survives the file');
    finally
      back.Free;
    end;
    back := TStrataApp.Create(root + 'never-written.ini');
    try
      back.Options.OutputDir := 'kept';
      back.RestorePreferences;
      Check(back.Options.OutputDir = 'kept', 'a preference never saved keeps its value');
    finally
      back.Free;
    end;

    { --- where the datasets are --- }
    g4 := root + 'g4' + PathDelim;
    Check(app.LocateGeant4Data = '', 'no share directory, no datasets');
    ForceDirectories(g4 + 'share' + PathDelim + 'Geant4-11.4.3' + PathDelim + 'data');
    Check(app.LocateGeant4Data = g4 + 'share' + PathDelim + 'Geant4-11.4.3' + PathDelim + 'data',
          'the versioned share directory is found');
    ForceDirectories(g4 + 'share' + PathDelim + 'Geant4' + PathDelim + 'data');
    Check(app.LocateGeant4Data = g4 + 'share' + PathDelim + 'Geant4' + PathDelim + 'data',
          'the unversioned one wins');
    app.Options.DataDir := root + 'no-such-data';
    sink.Lines.Clear;
    Check(app.Geant4DataPath = g4 + 'share' + PathDelim + 'Geant4' + PathDelim + 'data',
          'a missing preference falls back to the lookup');
    Check((sink.Lines.Count = 1) and (Pos('does not exist', sink.Lines[0]) > 0),
          'and says so in the log');
    app.Options.DataDir := root + 'out';
    ForceDirectories(app.Options.DataDir);
    Check(app.Geant4DataPath = root + 'out', 'an existing preference is taken as it is');

    { --- the batch executable --- }
    app.Options.StrataExe := '';
    sink.Answer := '';
    sink.Asked := 0;
    Check(app.LocateStrataExecutable = '', 'nothing found, nothing answered');
    Check(sink.Asked = 1, 'and the window was asked once');
    exe := Touch(root + 'bin' + PathDelim + StrataExeName);
    sink.Answer := exe;
    Check(app.LocateStrataExecutable = exe, 'the answer is taken');
    sink.Asked := 0;
    Check((app.LocateStrataExecutable = exe) and (sink.Asked = 0), 'and kept, without asking again');

    { --- the environment a child gets --- }
    child := TProcess.Create(nil);
    try
      app.ApplyGeant4Environment(child);
      Check(Pos(ExcludeTrailingPathDelimiter(ExtractFilePath(exe)) + PathSeparator,
                EnvOf(child, 'PATH')) = 1, 'the executable''s directory leads PATH');
      Check(Pos(g4 + 'bin', EnvOf(child, 'PATH')) > 0, 'Geant4''s bin is on PATH');
      Check(EnvOf(child, 'GEANT4_DATA_DIR') = root + 'out', 'GEANT4_DATA_DIR is the preference');
      Check(child.Environment.Count >= GetEnvironmentVariableCount,
            'the rest of the environment is inherited');
    finally
      child.Free;
    end;

    { --- the terminal script --- }
    script := app.WriteTerminalScript(err);
    Check((script <> '') and (err = '') and FileExists(script), 'the terminal script is written');
    sh := TStringList.Create;
    try
      if FileExists(script) then sh.LoadFromFile(script);
      Check(Pos(root + 'out', sh.Text) > 0, 'it sets the datasets');
      Check(Pos(ExcludeTrailingPathDelimiter(ExtractFilePath(exe)), sh.Text) > 0,
            'and puts Strata on the PATH');
    finally
      sh.Free;
    end;

    { --- the viewer's scratch directory --- }
    Check(app.NewViewerDirectory(dir, err) and DirectoryExists(dir + 'macros'),
          'the viewer gets a directory with a macros folder');

    { --- the backend, when one is given --- }
    if ParamStr(1) <> '' then
    begin
      app.Options.LibraryDir := ExpandFileName(ParamStr(1));
      sink.Lines.Clear;
      Check(app.LoadBackend, 'the backend loads from the preference');
      Check((sink.Lines.Count > 0) and (Pos('Loaded ', sink.Lines[sink.Lines.Count - 1]) = 1),
            'and the log says from where');
      cmd := GetEnvironmentVariable('STRATA_DATA');
      if cmd <> '' then
      begin
        app.Options.DataDir := cmd;
        Check(app.ConfigureGeant4 = ExcludeTrailingPathDelimiter(cmd), 'the datasets are set');
        Check(app.DataDirSet = ExcludeTrailingPathDelimiter(cmd), 'and remembered');
      end;
    end
    else
      WriteLn('(no backend given, its checks skipped)');
  finally
    app.Free;
    sink.Free;
  end;

  WriteLn;
  if Failures = 0 then
    WriteLn('PASSED (0 failures)')
  else
    WriteLn(Format('FAILED (%d failures)', [Failures]));
  Flush(Output);
  if StrataLibraryLoaded then strata_exit_process(Ord(Failures > 0));
  Halt(Ord(Failures > 0));
end.
