{==============================================================================
  uMain.pas: Strata's main window.

  The form owns a TStrataEngine and drives it from a single timer: Poll()
  drains the backend's log ring buffer and fires the progress and
  run-finished events on the GUI thread.  Nothing in this unit runs on a
  background thread, and nothing in the backend ever calls into the LCL.

  What the window shows is a frame: TPanelsFrame holds the set-up pages and
  the .scf document; the toolbar and the menus carry its commands.
==============================================================================}

unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Menus, ActnList, StdActns, Buttons, LCLType, uSciRestorer,
  uExtSVGImageList, BCTrackbarUpdown, uStrataApi, uStrataEngine, uStrataApp,
  uOptions, uDatasets, uPanelsFrame, uEditorFrame, LCLIntf;

type

  { TMainForm }

  TMainForm = class(TForm)
    fraPanels: TPanelsFrame;
    fraEditor: TEditorFrame;
    actOpenDocument: TFileOpen;
    actSwitchMode: TAction;
    tbSwitchMode: TToolButton;
    mnuSwitchMode: TMenuItem;
    actAbortRun: TAction;
    actAbout: TAction;
    actOptions: TAction;
    actNewSession: TAction;
    actDatasets: TAction;
    actTerminal: TAction;
    actVisualize: TAction;
    actPreviewGeometry: TAction;
    actStartEngine: TAction;
    lblGeant4: TLabel;
    mnuSaveConfig: TMenuItem;
    mnuNewConfig: TMenuItem;
    pbRun: TProgressBar;
    tbEvents: TBCTrackbarUpdown;
    tbThreads: TBCTrackbarUpdown;
    mnuAbout: TMenuItem;
    mnuHelp: TMenuItem;
    mnuSaveLog: TMenuItem;
    mnuClearLog: TMenuItem;
    mnuDeactivateHistogram: TMenuItem;
    mnuActivateHistogram: TMenuItem;
    mnuExportHistogram: TMenuItem;
    mnuExportAllHistograms: TMenuItem;
    mnuRefreshHistograms: TMenuItem;
    mnuPrintMaterials: TMenuItem;
    mnuRefreshMaterials: TMenuItem;
    mnuCreateMaterial: TMenuItem;
    mnuRemoveElement: TMenuItem;
    mnuAddElement: TMenuItem;
    mnuRunMacro: TMenuItem;
    mnuSendCommand: TMenuItem;
    mnuApplyPhysics: TMenuItem;
    mnuApplyBeam: TMenuItem;
    mnuApplyGeometry: TMenuItem;
    mnuAbortRun: TMenuItem;
    mnuBeamOn: TMenuItem;
    mnuDatasets: TMenuItem;
    mnuTerminal: TMenuItem;
    mnuVisualize: TMenuItem;
    mnuPreviewGeometry: TMenuItem;
    mnuEdStep: TMenuItem;
    mnuEdRunToCursor: TMenuItem;
    mnuNewSession: TMenuItem;
    mnuInitialize: TMenuItem;
    mnuStartEngine: TMenuItem;
    mnuLog: TMenuItem;
    mnuHistograms: TMenuItem;
    mnuMaterials: TMenuItem;
    mnuGeant4: TMenuItem;
    mnuSep2: TMenuItem;
    mnuSep3: TMenuItem;
    mnuSep4: TMenuItem;
    mnuSep5: TMenuItem;
    mnuSep6: TMenuItem;
    mnuSep7: TMenuItem;
    StrataActionList: TActionList;
    dlgOpenExe: TOpenDialog;
    dlgOutputDir: TSelectDirectoryDialog;
    StrataRestorer: TSciRestorer;
    StrataSVGImageList: TExtSVGImageList;
    mnuExportMacro: TMenuItem;
    mnuFile: TMenuItem;
    mnuImportMacro: TMenuItem;
    mnuMain: TMainMenu;
    mnuOpenConfig: TMenuItem;
    mnuSaveConfigAs: TMenuItem;
    mnuSep1: TMenuItem;
    pnlTop: TPanel;
    sbMain: TStatusBar;
    tmrPoll: TTimer;
    tbStrata: TToolBar;
    tbOpenConfig: TToolButton;
    tbSaveConfigAs: TToolButton;
    tbSep1: TToolButton;
    tbImportMacro: TToolButton;
    tbExportMacro: TToolButton;
    tbSep2: TToolButton;
    tbStartEngine: TToolButton;
    tbInitialize: TToolButton;
    tbSep3: TToolButton;
    tbBeamOn: TToolButton;
    tbAbortRun: TToolButton;
    tbSep4: TToolButton;
    tbNewSession: TToolButton;
    tbVisualize: TToolButton;
    tbPreviewGeometry: TToolButton;
    tbEdStep: TToolButton;
    tbEdRunToCursor: TToolButton;
    tbSep5: TToolButton;
    tbAbout: TToolButton;
    tbSep6: TToolButton;
    tbOptions: TToolButton;
    tbTerminal: TToolButton;
    tbDatasets: TToolButton;
    tbNewConfig: TToolButton;
    tbSaveConfig: TToolButton;

    procedure actOpenDocumentAccept(Sender: TObject);
    procedure actOpenDocumentBeforeExecute(Sender: TObject);
    procedure actSwitchModeExecute(Sender: TObject);
    procedure actAbortRunExecute(Sender: TObject);
    procedure actAboutExecute(Sender: TObject);
    procedure actOptionsExecute(Sender: TObject);
    procedure actNewSessionExecute(Sender: TObject);
    procedure actStartEngineExecute(Sender: TObject);
    procedure actDatasetsExecute(Sender: TObject);
    procedure actTerminalExecute(Sender: TObject);
    procedure actVisualizeExecute(Sender: TObject);
    procedure actPreviewGeometryExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrPollTimer(Sender: TObject);
  private
    FToolOrder: array of TControl;   // toolbar buttons as designed
    FEditing: Boolean;               // the macro editor is the one shown
    FEngine: TStrataEngine;
    FLogPending: TStringList;        // batched so the memo is touched once per tick
    FStage: String;                  // what is in flight, for the crash report

    FApp: TStrataApp;                // preferences, backend, Geant4, terminal, viewer

    procedure HandleLogLine(Sender: TObject; const ALine: String; AIsError: Boolean);
    procedure HandleProgress(Sender: TObject; ADone, ATotal: Int64);
    procedure HandleRunFinished(Sender: TObject; AStatus: Integer);


    procedure HandleException(Sender: TObject; E: Exception);
    procedure LoadBackend;
    procedure ArrangeToolbar;
    procedure OpenViewer(AEvents: Integer; AGeometryOnly: Boolean);
    function CommandCacheFile: String;
    function MaterialCacheFile: String;
    procedure KernelBuilt(Sender: TObject);
    function NeedCommands: Boolean;
    function AskForExecutable(const AStartDir: String): String;
    procedure UpdateControlState;
    procedure ShowTrackbarState(ATrackbar: TBCTrackbarUpdown);
    procedure UpdateCaption;
    function StageText: String;
    procedure Status(const AText: String);
    procedure SetStage(const AText: String);
    procedure LogLocal(const AText: String);
    function RunningOrAborting: Boolean;
    function RestartEngine(const AWhy: String): Boolean;
    procedure ShowInterface(AEditor: Boolean);
    procedure BindCommands;
    function CloseEngine(const AQuestion: String): Boolean;
    function NewSessionForDocument: Boolean;
    function CloseEngineForSwitch: Boolean;
    procedure ShowLogPage;
    function StartEngine: Boolean;
    function FreshEngine: Boolean;
    procedure PanelsStateChanged(Sender: TObject);
    procedure PanelsDocumentChanged(Sender: TObject);
    procedure PanelsRunStarting(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  uAbout;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  i, j: Integer;
  c: TControl;
begin
  Caption := 'Strata';
  // The designed order, before anything is hidden
  SetLength(FToolOrder, tbStrata.ControlCount);
  for i := 0 to tbStrata.ControlCount - 1 do
  begin
    c := tbStrata.Controls[i];
    j := i;
    while (j > 0) and (FToolOrder[j - 1].Left > c.Left) do
    begin
      FToolOrder[j] := FToolOrder[j - 1];
      Dec(j);
    end;
    FToolOrder[j] := c;
  end;
  FLogPending := TStringList.Create;

  Application.OnException := @HandleException;

  FEngine := TStrataEngine.Create;
  FApp := TStrataApp.Create(StrataRestorer.FullIniFileName);
  FApp.OnLog := @LogLocal;
  FApp.OnAskExe := @AskForExecutable;
  FEngine.OnLogLine := @HandleLogLine;
  FEngine.OnProgress := @HandleProgress;
  FEngine.OnRunFinished := @HandleRunFinished;

  // The panels reach the engine and the window through these
  fraPanels.Engine := FEngine;
  fraPanels.App := FApp;
  fraPanels.ThreadsBox := tbThreads;
  fraPanels.EventsBox := tbEvents;
  fraPanels.Images := StrataSVGImageList;
  fraPanels.OnStatus := @Status;
  fraPanels.OnLog := @LogLocal;
  fraPanels.OnStage := @SetStage;
  fraPanels.OnStateChanged := @PanelsStateChanged;
  fraPanels.OnDocumentChanged := @PanelsDocumentChanged;
  fraPanels.OnRunStarting := @PanelsRunStarting;
  fraEditor.Engine := FEngine;
  fraEditor.Images := StrataSVGImageList;
  fraEditor.OnStatus := @Status;
  fraEditor.OnDocumentChanged := @PanelsDocumentChanged;
  fraEditor.OnLog := @LogLocal;
  fraEditor.OnStateChanged := @PanelsStateChanged;
  fraEditor.OnRunStarting := @PanelsRunStarting;
  fraEditor.OnStartEngine := @FreshEngine;
  fraEditor.OnNeedCommands := @NeedCommands;
  fraEditor.OnKernelBuilt := @KernelBuilt;
  fraPanels.OnKernelBuilt := @KernelBuilt;
  fraPanels.OnNewDocument := @NewSessionForDocument;
  // Shown only with the editor, so bound once
  tbEdStep.Action := fraEditor.actEdStep;
  tbEdRunToCursor.Action := fraEditor.actEdRunToCursor;
  mnuEdStep.Action := fraEditor.actEdStep;
  mnuEdRunToCursor.Action := fraEditor.actEdRunToCursor;
  // The panels' commands on the window's toolbar and menus
  tbImportMacro.Action := fraPanels.actImportMacro;
  tbExportMacro.Action := fraPanels.actExportMacro;
  tbInitialize.Action := fraPanels.actInitialize;
  mnuImportMacro.Action := fraPanels.actImportMacro;
  mnuExportMacro.Action := fraPanels.actExportMacro;
  mnuInitialize.Action := fraPanels.actInitialize;
  mnuApplyGeometry.Action := fraPanels.actApplyGeometry;
  mnuApplyBeam.Action := fraPanels.actApplyBeam;
  mnuApplyPhysics.Action := fraPanels.actApplyPhysics;
  mnuSendCommand.Action := fraPanels.actSendCommand;
  mnuRunMacro.Action := fraPanels.actRunMacro;
  mnuAddElement.Action := fraPanels.actAddElement;
  mnuRemoveElement.Action := fraPanels.actRemoveElement;
  mnuCreateMaterial.Action := fraPanels.actCreateMaterial;
  mnuRefreshMaterials.Action := fraPanels.actRefreshMaterials;
  mnuPrintMaterials.Action := fraPanels.actPrintMaterials;
  mnuRefreshHistograms.Action := fraPanels.actRefreshHistograms;
  mnuExportHistogram.Action := fraPanels.actExportHistogram;
  mnuExportAllHistograms.Action := fraPanels.actExportAllHistograms;
  mnuActivateHistogram.Action := fraPanels.actActivateHistogram;
  mnuDeactivateHistogram.Action := fraPanels.actDeactivateHistogram;

  // Launched from a file manager the process starts at the root, which is
  // no place to put exports; anywhere else, the directory it was started in
  // is what the user meant
  FApp.Options.OutputDir := GetCurrentDir;
  if (FApp.Options.OutputDir = '') or (FApp.Options.OutputDir = PathDelim) then
    FApp.Options.OutputDir := GetUserDir;

  tbThreads.Value := 2;

  // Before LoadBackend, not after
  FApp.RestorePreferences;
  LoadBackend;
  FApp.ConfigureGeant4;

  fraPanels.Start;

  // The interface used last, with a clean document
  ShowInterface(FApp.Options.LastInterface = 'editor');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  tmrPoll.Enabled := False;
  FreeAndNil(FEngine);
  FreeAndNil(FApp);
  FreeAndNil(FLogPending);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;
  if RunningOrAborting then
  begin
    if MessageDlg('Strata', 'A run is still in progress. Abort it and quit?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      CanClose := False;
      Exit;
    end;
    FEngine.AbortRun;
    FEngine.WaitForRun(30000);
  end;

  CanClose := fraPanels.MayReplaceConfig and fraEditor.MayReplaceMacro;
end;

procedure TMainForm.HandleException(Sender: TObject; E: Exception);
var
  report: TStringList;
  frames: PPointer;
  i: Integer;
  path: String;
begin
  report := TStringList.Create;
  try
    report.Add('*** unhandled exception: ' + E.ClassName);
    report.Add('    ' + E.Message);
    if FEngine <> nil then
      report.Add(Format('    engine open=%s state=%d histogram=%d',
        [BoolToStr(FEngine.IsOpen, True), FEngine.State, fraPanels.CurrentHistogramId]));
    if FStage <> '' then
      report.Add('    while: ' + FStage);
    report.Add('    backtrace (addresses only on macOS; symbolise with '
               + '"atos -o <StrataGUI binary> <address>"):');
    report.Add('      ' + BackTraceStrFunc(ExceptAddr));
    frames := ExceptFrames;
    for i := 0 to ExceptFrameCount - 1 do
      report.Add('      ' + BackTraceStrFunc(frames[i]));

    for i := 0 to report.Count - 1 do LogLocal(report[i]);

    path := IncludeTrailingPathDelimiter(GetTempDir) + 'strata-crash.txt';
    try
      report.SaveToFile(path);
      LogLocal('    (also written to ' + path + ')');
    except
      path := '';
    end;
  finally
    report.Free;
  end;

  ShowLogPage;
  Status('Unhandled exception, see the Log tab');
  if path <> '' then
    path := ' and to' + LineEnding + path
  else
    path := '.';
  MessageDlg('Strata',
             E.ClassName + ': ' + E.Message + LineEnding + LineEnding
             + 'A backtrace has been written to the Log tab' + path,
             mtError, [mbOK], 0);
end;

procedure TMainForm.LoadBackend;
begin
  if not FApp.LoadBackend then
  begin
    lblGeant4.Caption := 'Backend not loaded';
    Status('Backend not loaded, see the Log tab');
    ShowLogPage;
    if MessageDlg('Strata', 'Strata could not start its engine. The usual cause is that '
                  + 'Geant4 is not installed. Install it from the Geant4 installers.' + LineEnding + LineEnding
                  + 'Open the download page?', mtWarning, [mbYes, mbNo], 0) = mrYes then
      OpenURL(StrataGeant4URL);
    Exit;
  end;
  lblGeant4.Caption := Format('libstrata %s/%s', [StrataVersion, StrataGeant4Version]);
  Status('Backend loaded, engine not started');
  // The commands the last engine of this library knew, until one is built
  if FileExists(CommandCacheFile) then
    fraEditor.LoadCommandTree(CommandCacheFile);
  if FileExists(MaterialCacheFile) then
    fraEditor.MaterialNames.LoadFromFile(MaterialCacheFile);
end;

function TMainForm.MaterialCacheFile: String;
begin
  Result := ExtractFilePath(StrataRestorer.FullIniFileName) + 'materials-' +
    StrataVersion + '.txt';
end;

// The command tree is kept beside the settings, one per library version
function TMainForm.CommandCacheFile: String;
begin
  Result := ExtractFilePath(StrataRestorer.FullIniFileName) + 'commands-' +
    StrataVersion + '.txt';
end;

// After every /run/initialize the editor learns the commands of this engine
procedure TMainForm.KernelBuilt(Sender: TObject);
var
  s: String;
  all, defined: TStringList;
begin
  all := TStringList.Create;
  defined := TStringList.Create;
  try
    FEngine.FillMaterialNames(all);
    FEngine.FillDefinedMaterialNames(defined);
    all.AddStrings(defined);
    fraEditor.SetMaterialNames(all);
    try
      all.SaveToFile(MaterialCacheFile);
    except
      on E: Exception do LogLocal('Could not keep the material list: ' + E.Message);
    end;
  finally
    defined.Free;
    all.Free;
  end;
  s := FEngine.CommandTree;
  if s = '' then Exit;
  fraEditor.SetCommandTree(s);
  if fraEditor.CommandTree.Count = 0 then Exit;
  try
    fraEditor.CommandTree.SaveToFile(CommandCacheFile);
  except
    on E: Exception do LogLocal('Could not keep the command list: ' + E.Message);
  end;
end;

// Completion was asked for before any engine was initialised
function TMainForm.NeedCommands: Boolean;
begin
  Result := False;
  if RunningOrAborting then Exit;
  if not (FEngine.IsOpen and (FEngine.State <> STRATA_STATE_IDLE)) then
  begin
    if not FreshEngine then Exit;
    Screen.Cursor := crHourGlass;
    try
      try
        FEngine.Initialize;
      except
        on E: Exception do
        begin
          Status('Could not read the command list: ' + E.Message);
          UpdateControlState;
          Exit;
        end;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
  end;
  KernelBuilt(Self);
  UpdateControlState;
  Result := fraEditor.CommandTree.Count > 0;
  if Result then
    Status(Format('%d Geant4 commands known', [fraEditor.CommandTree.Count]));
end;

// The last resort when the batch executable is nowhere to be found
function TMainForm.AskForExecutable(const AStartDir: String): String;
begin
  Result := '';
  if MessageDlg('Strata executable',
                'The Strata batch executable could not be found next to the backend '
                + 'library or next to this application.' + LineEnding + LineEnding
                + 'It is the program the viewer and the terminal run.  Locate it?',
                mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  dlgOpenExe.InitialDir := AStartDir;
  if dlgOpenExe.Execute and FileExists(dlgOpenExe.FileName) then
    Result := dlgOpenExe.FileName;
end;

// Geant4 builds its kernel once per process, and that process is the engine,
// so a new kernel is a new engine and this window stays up
function TMainForm.RestartEngine(const AWhy: String): Boolean;
begin
  Result := False;
  if RunningOrAborting then
  begin
    Status('A run is in progress, abort it first');
    Exit;
  end;

  if MessageDlg('New session', AWhy + LineEnding + LineEnding
                + 'The geometry, beam, physics list, test volumes, generator '
                + 'and the configured spectra are kept as they are, and the '
                + 'engine comes back stopped so that any of them can be '
                + 'changed before it is built again.' + LineEnding + LineEnding
                + 'Results that have not been exported are lost.'
                + LineEnding + LineEnding + 'Restart the engine now?',
                mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  tmrPoll.Enabled := False;
  Screen.Cursor := crHourGlass;
  try
    FEngine.Close;
  finally
    Screen.Cursor := crDefault;
  end;

  // The next start sends these again, to the engine the preferences now name
  FApp.DataDirSet := '';
  fraPanels.EngineStopped;
  UpdateControlState;
  Status('Engine stopped, Start engine when ready');
  Result := True;
end;

procedure TMainForm.actNewSessionExecute(Sender: TObject);
begin
  RestartEngine('Geant4 can only build its kernel once per engine process, so '
                + 'a fresh session means restarting the engine.');
end;

procedure TMainForm.actAbortRunExecute(Sender: TObject);
begin
  // Stopped between commands, there is no run to abort, only the rest
  if FEditing and fraEditor.Paused and not RunningOrAborting then
  begin
    fraEditor.EndPause;
    UpdateControlState;
    Exit;
  end;
  // A macro does not go on past an aborted run
  if FEditing then fraEditor.StopAfterRun;
  if FEngine.AbortRun then
    Status('Abort requested; every worker stops at the end of the event it '
           + 'is in, and the results of what did run are kept')
  else
    Status('The backend refused the abort: no run is in progress');
  UpdateControlState;
end;

procedure TMainForm.actAboutExecute(Sender: TObject);
begin
  AboutBox.ShowModal;
end;

procedure TMainForm.UpdateCaption;
var
  shown: String;
begin
  if FEditing then
    shown := 'Strata - ' + fraEditor.DocumentCaption
  else
    shown := 'Strata - ' + fraPanels.DocumentCaption;
  if Caption <> shown then Caption := shown;
end;

procedure TMainForm.actOptionsExecute(Sender: TObject);
var
  needs, wanted: String;
begin
  OptionsDlg.SetOptions(FApp.Options);
  if (OptionsDlg.ShowModal <> mrOK) then Exit;
  OptionsDlg.GetOptions(FApp.Options);
  // Read by the next engine strata.dll starts
  FApp.ExportGeant4Dir;

  if not StrataLibraryLoaded then
  begin
    LoadBackend;
    FApp.ConfigureGeant4;
    UpdateControlState;
    Exit;
  end;

  // A dataset directory can still be changed while there is no session
  if not FEngine.IsOpen then
  begin
    // An engine that could not start before may be able to now
    lblGeant4.Caption := Format('libstrata %s/%s', [StrataVersion, StrataGeant4Version]);
    FApp.ConfigureGeant4;
    Exit;
  end;

  // A library already loaded cannot be swapped whatever the engine does
  if (Trim(FApp.Options.LibraryDir) <> '')
     and (not SameFileName(ExcludeTrailingPathDelimiter(Trim(FApp.Options.LibraryDir)),
                ExcludeTrailingPathDelimiter(ExtractFilePath(StrataLibraryPath)))) then
  begin
    Status('The backend in use is still ' + StrataLibraryPath
           + ', the new one is loaded the next time Strata starts');
    LogLocal('Backend directory changed, ' + StrataLibraryPath
             + ' stays in use for this run of Strata');
  end;

  // A dataset path Geant4 has resolved stays resolved, and that is the
  // engine, so another engine reads the new one
  wanted := FApp.Geant4DataPath;
  if (wanted <> '') and (FApp.DataDirSet <> '') and (wanted <> FApp.DataDirSet) then
  begin
    needs := 'The engine is still reading its data from ' + FApp.DataDirSet
             + ', because the paths Geant4 has resolved cannot be moved.';
    if not RestartEngine(needs) then
      LogLocal(StringReplace(needs, LineEnding, ' ', [rfReplaceAll]));
  end;
end;

procedure TMainForm.actStartEngineExecute(Sender: TObject);
begin
  StartEngine;
end;

// Starts the engine, after the datasets check; False when it is not running
function TMainForm.StartEngine: Boolean;
var
  missing: TStringArray;
  i: Integer;
  list, where: String;
begin
  Result := FEngine.IsOpen;
  if Result then
  begin
    UpdateControlState;
    Exit;
  end;

  fraPanels.EngineStarting;

  // Configure first, ask afterwards
  where := FApp.ConfigureGeant4;

  missing := FApp.MissingGeant4Datasets;
  if Length(missing) > 0 then
  begin
    list := '';
    for i := 0 to High(missing) do
      list := list + sLineBreak + '    ' + missing[i];
    LogLocal('Geant4 cannot find these required datasets:' + list);
    if where <> '' then
      where := 'Strata pointed Geant4 at' + sLineBreak + '    ' + where
               + sLineBreak + 'and these are not under it:'
    else
      where := 'Strata has no dataset directory to point Geant4 at, and the '
               + 'Geant4 it was built against cannot find these:';
    case MessageDlg('Strata',
                  where + list + sLineBreak + sLineBreak
                  + 'Geant4 treats a missing dataset as a fatal exception and '
                  + 'aborts the process, so a run will very likely take this '
                  + 'window down with it.' + sLineBreak + sLineBreak
                  + 'Geant4 datasets... downloads them, or give the '
                  + 'directory that already holds them under Geant4 Datasets '
                  + 'in the preferences.' + sLineBreak + sLineBreak
                  + 'Download them now?',
                  mtWarning, [mbYes, mbNo, mbIgnore], 0) of
      mrYes:
        begin
          actDatasetsExecute(nil);
          // Whether that helped is the same question as before
          if Length(FApp.MissingGeant4Datasets) > 0 then
          begin
            Status('Engine not started: Geant4 datasets still missing');
            Exit;
          end;
        end;
      mrIgnore:
        ;        // start it anyway, and find out
      else
        begin
          Status('Engine not started: Geant4 datasets not configured');
          Exit;
        end;
    end;
  end;

  Screen.Cursor := crHourGlass;
  try
    FEngine.Open(tbThreads.Value);
  finally
    Screen.Cursor := crDefault;
  end;
  tmrPoll.Enabled := True;
  fraPanels.EngineStarted;
  Status(Format('Engine started (%d worker threads)', [FEngine.ThreadCount]));
  UpdateControlState;
  Result := FEngine.IsOpen;
end;

procedure TMainForm.actDatasetsExecute(Sender: TObject);
var
  where: String;
begin
  where := Trim(FApp.Options.DataDir);
  if where = '' then where := FApp.Geant4DataPath;
  DatasetsDlg.SetDestination(where);
  DatasetsDlg.ShowModal;
  if not DatasetsDlg.Fetched then Exit;

  // Whatever was fetched is only of use if Geant4 is pointed at it
  FApp.Options.DataDir := DatasetsDlg.Destination;
  FApp.SavePreferences;
  LogLocal('Geant4 datasets downloaded to ' + FApp.Options.DataDir);
  FApp.ConfigureGeant4;
  if Length(FApp.MissingGeant4Datasets) = 0 then Exit;

  // Either something required is still missing, or Geant4 resolved
  // where to look before the download
  if not RestartEngine('The datasets are now at ' + FApp.Options.DataDir
                       + ', but the engine had already settled where to look '
                       + 'for them before they arrived, and what Geant4 has '
                       + 'resolved cannot be moved afterwards.') then
    LogLocal('Geant4 reads the datasets from the new directory in the next session.');
end;

procedure TMainForm.actTerminalExecute(Sender: TObject);
var
  script, err: String;
begin
  if not FApp.OpenTerminal(script, err) then
  begin
    if err <> '' then MessageDlg('Terminal', err, mtError, [mbOK], 0);
    Exit;
  end;
  LogLocal('Terminal started:');
  LogLocal('    ' + script);
  LogLocal('    Strata on the PATH, the Geant4 environment set, the output '
           + 'directory to start in');
  Status('Terminal started');
end;

procedure TMainForm.actVisualizeExecute(Sender: TObject);
var
  answer: String;
  events: Integer;
begin
  if RunningOrAborting then
  begin
    Status('A run is in progress; wait for it, or abort it');
    Exit;
  end;
  answer := '10';
  if not InputQuery('Geant4 viewer',
                    'How many events should be drawn?  A handful is usually enough; '
                    + 'every track is kept and drawn.', answer) then Exit;
  events := StrToIntDef(Trim(answer), 0);
  if events < 0 then events := 0;
  OpenViewer(events, False);
end;

// The geometry alone: nothing shot, and the macro only up to /run/initialize
procedure TMainForm.actPreviewGeometryExecute(Sender: TObject);
begin
  OpenViewer(0, True);
end;

procedure TMainForm.OpenViewer(AEvents: Integer; AGeometryOnly: Boolean);
var
  scratch, setupMac, command, err: String;
begin
  if RunningOrAborting then
  begin
    Status('A run is in progress; wait for it, or abort it');
    Exit;
  end;
  if FApp.LocateStrataExecutable = '' then
  begin
    Status('No Strata executable, no viewer');
    Exit;
  end;

  if not FApp.NewViewerDirectory(scratch, err) then
  begin
    MessageDlg('Geant4 viewer', err, mtError, [mbOK], 0);
    Exit;
  end;
  setupMac := scratch + 'setup.mac';

  // Results go to the scratch directory to avoid overwriting real output
  if FEditing then
  begin
    if not fraEditor.WriteViewerSetup(setupMac, AGeometryOnly) then Exit;
  end
  else
    fraPanels.WriteViewerSetup(setupMac, ExcludeTrailingPathDelimiter(scratch), 'viewer');

  if not FApp.LaunchViewer(setupMac, AEvents, command, err) then
  begin
    MessageDlg('Geant4 viewer', err, mtError, [mbOK], 0);
    Exit;
  end;

  LogLocal('Geant4 viewer started:');
  LogLocal('    ' + command);
  LogLocal('    working directory ' + scratch);
  LogLocal('    the viewer is a separate process; this window stays usable');
  if AEvents = 0 then
    Status('Viewer started with the geometry only')
  else
    Status(Format('Viewer started with %d event(s)', [AEvents]));
end;

procedure TMainForm.HandleProgress(Sender: TObject; ADone, ATotal: Int64);
begin
  if ATotal > 0 then
    pbRun.Position := Round(1000.0*ADone/ATotal)
  else
    pbRun.Position := 0;
  sbMain.Panels[2].Text := Format('%d/%d events', [ADone, ATotal]);
end;

procedure TMainForm.HandleRunFinished(Sender: TObject; AStatus: Integer);
begin
  pbRun.Position := pbRun.Max;
  pbRun.Visible := False;
  if AStatus = STRATA_OK then
    Status('Run finished')
  else
    Status('Run ended with: ' + StrataStatusText(AStatus));
  if FEditing then
    fraEditor.RunFinished(AStatus)
  else
    fraPanels.RunFinished;
  UpdateControlState;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FApp.SavePreferences;
end;

procedure TMainForm.HandleLogLine(Sender: TObject; const ALine: String; AIsError: Boolean);
begin
  if AIsError then
    FLogPending.Add('[G4cerr] ' + ALine)
  else
    FLogPending.Add(ALine);
end;

procedure TMainForm.LogLocal(const AText: String);
begin
  if Assigned(FLogPending) then FLogPending.Add(AText);
end;

procedure TMainForm.tmrPollTimer(Sender: TObject);
begin
  if FEngine = nil then Exit;
  FEngine.Poll;

  if FLogPending.Count > 0 then
  begin
    if FEditing then
      fraEditor.AppendLog(FLogPending)
    else
      fraPanels.AppendLog(FLogPending);
    FLogPending.Clear;
  end;

  if RunningOrAborting then
    if FEditing then
      fraEditor.LivePoll
    else
      fraPanels.LivePoll;

  UpdateCaption;
end;

function TMainForm.RunningOrAborting: Boolean;
begin
  Result := Assigned(FEngine) and (FEngine.State in [STRATA_STATE_RUNNING, STRATA_STATE_ABORTING]);
end;

procedure TMainForm.SetStage(const AText: String);
begin
  FStage := AText;
end;

procedure TMainForm.Status(const AText: String);
begin
  sbMain.Panels[1].Text := AText;
end;

// What the window says it is doing, and what can be done next
function TMainForm.StageText: String;
begin
  if not StrataLibraryLoaded then
    Result := 'Backend not loaded'
  else if RunningOrAborting then
  begin
    if FEngine.State = STRATA_STATE_ABORTING then
      Result := 'Stopping after the current event'
    else
      Result := 'Running';
  end
  else if not FEngine.IsOpen then
    Result := 'Engine stopped'
  else if FEngine.State = STRATA_STATE_IDLE then
    Result := 'Engine started'
  else
    Result := 'Kernel built';
end;

// A disabled trackbar only halves the alpha of its own number: the arrows and
// the field keep full contrast, so a disabled one looks live. Dim them to match
procedure TMainForm.ShowTrackbarState(ATrackbar: TBCTrackbarUpdown);
begin
  if ATrackbar.Enabled then
  begin
    ATrackbar.ArrowColor := clBtnText;
    ATrackbar.Background.Color := clWindow;
  end
  else
  begin
    ATrackbar.ArrowColor := clGrayText;
    ATrackbar.Background.Color := clBtnFace;
  end;
end;

procedure TMainForm.UpdateControlState;
var
  libLoaded, open, ready, running: Boolean;
begin
  libLoaded := StrataLibraryLoaded;
  open := libLoaded and FEngine.IsOpen;
  ready := open and (FEngine.State <> STRATA_STATE_IDLE);
  running := RunningOrAborting;

  sbMain.Panels[0].Text := StageText;

  // The engine itself
  actStartEngine.Enabled := libLoaded and (not open);
  // The thread count reaches Geant4 when the run manager is built
  tbThreads.Enabled := libLoaded and (not open);
  actNewSession.Enabled := not running;
  actVisualize.Enabled := not running;
  // The point of downloading them is to have Geant4 read them, and that
  // cannot be arranged while a run is in flight
  actDatasets.Enabled := not running;
  actAbortRun.Enabled := running or (FEditing and fraEditor.Paused);
  actPreviewGeometry.Enabled := not running;
  tbEvents.Enabled := not running;

  // Opening a document or switching rewrites what the run would be, and a
  // macro being run is busy between its runs as well
  actOpenDocument.Enabled := not (running or fraEditor.Busy);
  actSwitchMode.Enabled := not (running or fraEditor.Busy);

  fraPanels.UpdateState(open, ready, running);
  fraEditor.UpdateState(open, ready, running);

  ShowTrackbarState(tbThreads);
  ShowTrackbarState(tbEvents);
end;

procedure TMainForm.PanelsStateChanged(Sender: TObject);
begin
  UpdateControlState;
end;

procedure TMainForm.PanelsDocumentChanged(Sender: TObject);
begin
  UpdateCaption;
end;

procedure TMainForm.PanelsRunStarting(Sender: TObject);
begin
  pbRun.Visible := True;
  pbRun.Position := 0;
  pbRun.Max := 1000;
end;

// The editor's runs each start from an engine of their own
function TMainForm.FreshEngine: Boolean;
begin
  Result := False;
  if not StrataLibraryLoaded then
  begin
    Status('Backend not loaded');
    Exit;
  end;
  if RunningOrAborting then Exit;
  if FEngine.IsOpen then
  begin
    tmrPoll.Enabled := False;
    Screen.Cursor := crHourGlass;
    try
      FEngine.Close;
    finally
      Screen.Cursor := crDefault;
    end;
    FApp.DataDirSet := '';
    fraPanels.EngineStopped;
  end;
  Result := StartEngine;
end;

procedure TMainForm.ShowLogPage;
begin
  if FEditing then
    fraEditor.ShowLog
  else
    fraPanels.ShowLog;
end;

// The toolbar and the menus carry the commands of the frame that is shown
procedure TMainForm.BindCommands;
const
  // Shown only with the panels
  PanelsOnly: array[0..22] of String = (
    'tbImportMacro', 'tbExportMacro', 'tbSep2', 'tbStartEngine',
    'tbInitialize', 'tbEvents',
    'tbNewSession',
    'mnuSep1', 'mnuImportMacro', 'mnuExportMacro', 'mnuStartEngine',
    'mnuInitialize', 'mnuSep2',
    'mnuNewSession', 'mnuSep4', 'mnuApplyGeometry',
    'mnuApplyBeam', 'mnuApplyPhysics', 'mnuSep5', 'mnuSendCommand',
    'mnuRunMacro', 'mnuMaterials', 'mnuHistograms');
  // Shown only with the editor
  EditorOnly: array[0..3] of String = (
    'tbEdStep', 'tbEdRunToCursor', 'mnuEdStep', 'mnuEdRunToCursor');
var
  i: Integer;
  c: TComponent;
begin
  if FEditing then
  begin
    tbNewConfig.Action := fraEditor.actNewMacro;
    tbSaveConfig.Action := fraEditor.actSaveMacro;
    tbSaveConfigAs.Action := fraEditor.actSaveMacroAs;
    mnuNewConfig.Action := fraEditor.actNewMacro;
    mnuSaveConfig.Action := fraEditor.actSaveMacro;
    mnuSaveConfigAs.Action := fraEditor.actSaveMacroAs;
    mnuClearLog.Action := fraEditor.actEdClearLog;
    tbBeamOn.Action := fraEditor.actEdRun;
    mnuBeamOn.Action := fraEditor.actEdRun;
    mnuSaveLog.Action := fraEditor.actEdSaveLog;
  end
  else
  begin
    tbNewConfig.Action := fraPanels.actNewConfig;
    tbSaveConfig.Action := fraPanels.actSaveConfig;
    tbSaveConfigAs.Action := fraPanels.actSaveConfigAs;
    mnuNewConfig.Action := fraPanels.actNewConfig;
    mnuSaveConfig.Action := fraPanels.actSaveConfig;
    mnuSaveConfigAs.Action := fraPanels.actSaveConfigAs;
    mnuClearLog.Action := fraPanels.actClearLog;
    tbBeamOn.Action := fraPanels.actBeamOn;
    mnuBeamOn.Action := fraPanels.actBeamOn;
    mnuSaveLog.Action := fraPanels.actSaveLog;
  end;
  for i := Low(PanelsOnly) to High(PanelsOnly) do
  begin
    c := FindComponent(PanelsOnly[i]);
    if c is TControl then
      TControl(c).Visible := not FEditing
    else if c is TMenuItem then
      TMenuItem(c).Visible := not FEditing;
  end;
  for i := Low(EditorOnly) to High(EditorOnly) do
  begin
    c := FindComponent(EditorOnly[i]);
    if c is TControl then
      TControl(c).Visible := FEditing
    else if c is TMenuItem then
      TMenuItem(c).Visible := FEditing;
  end;
  ArrangeToolbar;
end;

// The toolbar orders its buttons by Left, and a button that was hidden
// keeps the Left it had, so every switch puts them back in designed order
procedure TMainForm.ArrangeToolbar;
var
  i: Integer;
begin
  tbStrata.DisableAlign;
  try
    for i := 0 to High(FToolOrder) do
      FToolOrder[i].Left := (i + 1)*1000;
  finally
    tbStrata.EnableAlign;
  end;
end;

procedure TMainForm.ShowInterface(AEditor: Boolean);
begin
  FEditing := AEditor;
  fraPanels.Visible := not AEditor;
  fraEditor.Visible := AEditor;
  if AEditor then
  begin
    FApp.Options.LastInterface := 'editor';
    actSwitchMode.Caption := 'Panels';
    actSwitchMode.Hint := 'Panels|Switch to the set-up panels';
    actSwitchMode.ImageIndex := 38;
  end
  else
  begin
    FApp.Options.LastInterface := 'panels';
    actSwitchMode.Caption := 'Macro editor';
    actSwitchMode.Hint := 'Macro editor|Switch to the macro editor';
    actSwitchMode.ImageIndex := 37;
  end;
  BindCommands;
  UpdateCaption;
  UpdateControlState;
end;

// Each interface runs its own set-up, so an engine built by the other one
// does not carry over
function TMainForm.CloseEngineForSwitch: Boolean;
begin
  Result := CloseEngine('Switching closes the engine, and results that have not '
                        + 'been exported are lost.' + LineEnding + LineEnding + 'Switch now?');
end;

// A built kernel is closed so the new configuration can be changed freely
function TMainForm.NewSessionForDocument: Boolean;
begin
  Result := True;
  if (not StrataLibraryLoaded) or (not FEngine.IsOpen) then Exit;
  if FEngine.State = STRATA_STATE_IDLE then Exit;
  Result := CloseEngine('Another configuration needs a new session, and results '
                        + 'that have not been exported are lost.' + LineEnding
                        + LineEnding + 'Continue?');
  UpdateControlState;
end;

function TMainForm.CloseEngine(const AQuestion: String): Boolean;
begin
  Result := True;
  if (not StrataLibraryLoaded) or (not FEngine.IsOpen) then Exit;
  Result := False;
  if RunningOrAborting then
  begin
    Status('A run is in progress, abort it first');
    Exit;
  end;
  if FEngine.HasResults
     and (MessageDlg('Strata', AQuestion, mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  tmrPoll.Enabled := False;
  Screen.Cursor := crHourGlass;
  try
    FEngine.Close;
  finally
    Screen.Cursor := crDefault;
  end;
  FApp.DataDirSet := '';
  fraPanels.EngineStopped;
  Status('Engine stopped');
  Result := True;
end;

procedure TMainForm.actSwitchModeExecute(Sender: TObject);
var
  answer: Integer;
  path, proposed: String;
begin
  if FEditing then
    answer := MessageDlg('Strata', 'Load the macro into the panels?'
      + LineEnding + LineEnding + 'Yes replaces the configuration with what '
      + 'the macro sets. Comments and the order of the commands are not kept, '
      + 'and lines the panels cannot show go to the command boxes on the '
      + 'Options tab.' + LineEnding + LineEnding + 'No switches and leaves '
      + 'both documents as they are.', mtConfirmation, [mbYes, mbNo, mbCancel], 0)
  else
    answer := MessageDlg('Strata', 'Write the configuration into the macro '
      + 'editor?' + LineEnding + LineEnding + 'Yes replaces the macro with the '
      + 'configuration written as a macro, as Export does.' + LineEnding
      + LineEnding + 'No switches and leaves both documents as they are.',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if answer = mrCancel then Exit;

  // The document about to be replaced is offered for saving first
  if answer = mrYes then
    if FEditing then
    begin
      if not fraPanels.MayReplaceConfig then Exit;
    end
    else if not fraEditor.MayReplaceMacro then Exit;
  if not CloseEngineForSwitch then Exit;

  if answer = mrYes then
    if FEditing then
    begin
      path := GetTempFileName(GetTempDir, 'strata');
      try
        with TStringList.Create do
        try
          Text := fraEditor.MacroText;
          SaveToFile(path);
        finally
          Free;
        end;
        proposed := '';
        if fraEditor.FileName <> '' then
          proposed := ChangeFileExt(fraEditor.FileName, '.scf');
        fraPanels.ImportMacro(path, proposed, False);
      finally
        DeleteFile(path);
      end;
    end
    else
    begin
      proposed := '';
      if fraPanels.ConfigFileName <> '' then
        proposed := ChangeFileExt(fraPanels.ConfigFileName, '.mac');
      fraEditor.LoadText(fraPanels.ConfigAsMacro, proposed);
    end;

  ShowInterface(not FEditing);
end;

procedure TMainForm.actOpenDocumentBeforeExecute(Sender: TObject);
begin
  actOpenDocument.Dialog.InitialDir := GetCurrentDir;
end;

// A macro opens in the editor and anything else in the panels
procedure TMainForm.actOpenDocumentAccept(Sender: TObject);
var
  fileName: String;
  macro, switching: Boolean;
begin
  fileName := actOpenDocument.Dialog.FileName;
  macro := SameText(ExtractFileExt(fileName), '.mac');
  // Switching has already asked about the document being replaced
  switching := macro <> FEditing;
  if switching then
  begin
    if macro then
    begin
      if not fraEditor.MayReplaceMacro then Exit;
    end
    else if not fraPanels.MayReplaceConfig then Exit;
    if not CloseEngineForSwitch then Exit;
    ShowInterface(macro);
  end;
  if macro then
    fraEditor.OpenFile(fileName, not switching)
  else
    fraPanels.OpenConfigFile(fileName, not switching);
end;

end.
