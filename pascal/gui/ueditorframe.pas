{==============================================================================
  uEditorFrame.pas: the macro editor and the .mac document behind it.

  The macro is the document: nothing outside the text changes what a run
  does.  The log here is this mode's own; the panels keep theirs.
==============================================================================}

unit uEditorFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, ActnList, StdActns, Buttons, ImgList, SynEdit, TAGraph, TASeries,
  uStrataApi, uStrataEngine, uStrataApp, uStrataMacro, SynEditMiscClasses,
  SynEditTypes, SynEditKeyCmds, SynCompletion, LCLType, uStrataCommands,
  uSynStrataMacro, uStrataWidgets, uResultsFrame;

type
  // Starts an engine of its own for a run, False when it could not
  TStrataStartEngine = function: Boolean of object;
  // Reads the command tree from an engine, False when it could not
  TStrataNeedCommands = function: Boolean of object;

  { TEditorFrame }

  TEditorFrame = class(TFrame)
    actEdClearLog: TAction;
    actEdExportHistogram: TAction;
    actEdExportAllHistograms: TAction;
    actEdRun: TAction;
    actEdRunToCursor: TAction;
    actEdStep: TAction;
    actEdSaveLog: TFileSaveAs;
    actNewMacro: TAction;
    actSaveMacro: TAction;
    actSaveMacroAs: TFileSaveAs;
    btnEdClearLog: TSpeedButton;
    btnEdExportHistogram: TSpeedButton;
    btnEdExportAllHistograms: TSpeedButton;
    btnEdSaveLog: TSpeedButton;
    chtEdHistogram: TChart;
    chtEdHistogramSeries: TLineSeries;
    dlgEdExportHistogram: TSaveDialog;
    EditorActions: TActionList;
    lbEdHistograms: TListBox;
    mEdHelp: TMemo;
    mEdLog: TMemo;
    pcEditor: TPageControl;
    pnlEdHistograms: TPanel;
    pnlEdLogButtons: TPanel;
    spltEdHelp: TSplitter;
    spltEdHistograms: TSplitter;
    synMacro: TSynEdit;
    tabEdHistograms: TTabSheet;
    tabEdLog: TTabSheet;
    tabEdResults: TTabSheet;
    fraEdResults: TResultsFrame;
    tabMacro: TTabSheet;
    procedure actEdClearLogExecute(Sender: TObject);
    procedure actEdExportHistogramExecute(Sender: TObject);
    procedure actEdExportAllHistogramsExecute(Sender: TObject);
    procedure actEdRunExecute(Sender: TObject);
    procedure actEdRunToCursorExecute(Sender: TObject);
    procedure actEdStepExecute(Sender: TObject);
    procedure lbEdHistogramsSelectionChange(Sender: TObject; User: boolean);
    procedure actEdSaveLogAccept(Sender: TObject);
    procedure actEdSaveLogBeforeExecute(Sender: TObject);
    procedure actNewMacroExecute(Sender: TObject);
    procedure actSaveMacroAsAccept(Sender: TObject);
    procedure actSaveMacroAsBeforeExecute(Sender: TObject);
    procedure actSaveMacroExecute(Sender: TObject);
    procedure synMacroChange(Sender: TObject);
  private
    FEngine: TStrataEngine;
    FFileName: String;               // the file it came from, empty when untitled
    FProposedName: String;           // what Save as offers for an untitled macro
    FSavedText: String;              // its text when it was last read or written
    FCommands: TStrataMacroCommands; // the macro being run
    FNext: Integer;                  // the next of them to send
    FBusy: Boolean;                  // a run of the macro is under way
    FStopRequested: Boolean;         // Abort: no more commands after this run
    FErrorLine: Integer;             // the line that was refused, 0 for none
    FRunLine: Integer;               // the /run/beamOn being run, 0 for none
    FPaused: Boolean;                // stopped between commands, engine idle
    FPauseLine: Integer;             // the line it stopped before, 0 for none
    FToSend: Integer;                // commands to send before stopping, -1 all
    FStopLine: Integer;              // stop before reaching this line, 0 never
    FHistogramIds: array of Integer; // what the list shows
    FHistogramCache: array of TStrataHistogram;  // their descriptions
    FLivePolls: Integer;
    FOnStatus: TStrataNotify;
    FOnLog: TStrataNotify;
    FOnDocumentChanged: TNotifyEvent;
    FOnStateChanged: TNotifyEvent;
    FOnRunStarting: TNotifyEvent;
    FOnStartEngine: TStrataStartEngine;
    FOnNeedCommands: TStrataNeedCommands;
    FOnKernelBuilt: TNotifyEvent;
    FTree: TStrataCommandTree;       // what Geant4 accepts, empty until read
    FHighlighter: TSynStrataMacroSyn;
    FCompletion: TSynCompletion;
    FSlashTyped: Boolean;            // the change under way is a typed '/'
    FSpaceTyped: Boolean;            // the change under way is a typed space
    FKnownMaterials: TStringList;    // what the engine offers
    FMaterials: TStringList;         // those plus the ones the macro creates
    FReadFailed: Boolean;            // reading the tree failed; '/' stops trying
    FStampFile: String;              // the file FDiskStamp belongs to
    FDiskStamp: String;              // its time and size when last read or written
    FCheckingDisk: Boolean;          // the reload question is showing
    procedure DoStatus(const AText: String);
    procedure DoLog(const AText: String);
    procedure DoDocumentChanged;
    procedure DoStateChanged;
    procedure ContinueRun;
    function StartSession: Boolean;
    procedure Resume(AToSend, AStopLine: Integer);
    procedure PauseAt(const ACommand: TStrataMacroCommand);
    procedure FinishRun(const AText: String);
    procedure StopAt(const ACommand: TStrataMacroCommand; const AError: String);
    procedure MacroLineMarkup(Sender: TObject; Line: Integer; var Special: Boolean;
      Markup: TSynSelectedColor);
    function CurrentHistogramId: Integer;
    procedure RefreshHistogramList;
    procedure ShowHistogram;
    function HistogramOutputName: String;
    function SaveHistogramAs(const AHistogram: TStrataHistogram): Boolean;
    procedure SetImages(AValue: TCustomImageList);
    function WriteMacro(const AFileName: String): Boolean;
    procedure MacroKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MacroKeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
    procedure MacroStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure CompletionAccepted(var Value: string; SourceValue: string;
      var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
    procedure AsyncComplete(Data: PtrInt);
    procedure ListKeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
    procedure UpdateHelp;
    procedure CollectMaterials;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetCommandTree(const AText: String);
    procedure LoadCommandTree(const AFileName: String);
    procedure SetMaterialNames(AList: TStrings);
    property MaterialNames: TStringList read FKnownMaterials;
    procedure ShowCompletion(ASilent: Boolean = False);
    function WriteViewerSetup(const AMacro: String; AGeometryOnly: Boolean = False): Boolean;
    procedure UpdateState(AOpen, AReady, ARunning: Boolean);
    procedure ShowLog;
    procedure AppendLog(ALines: TStrings);
    function Modified: Boolean;
    function MayReplaceMacro: Boolean;
    function OpenFile(const AFileName: String; AAskFirst: Boolean = True): Boolean;
    procedure LoadText(const AText, AProposedName: String);
    procedure RunFinished(AStatus: Integer);
    procedure StopAfterRun;
    procedure EndPause;
    property Paused: Boolean read FPaused;
    procedure LivePoll;
    property Busy: Boolean read FBusy;
    function MacroText: String;
    procedure CheckDiskFile;
    function DocumentCaption: String;
    property FileName: String read FFileName;
    property Engine: TStrataEngine read FEngine write FEngine;
    property Images: TCustomImageList write SetImages;
    property OnStatus: TStrataNotify read FOnStatus write FOnStatus;
    property OnLog: TStrataNotify read FOnLog write FOnLog;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnRunStarting: TNotifyEvent read FOnRunStarting write FOnRunStarting;
    property OnStartEngine: TStrataStartEngine read FOnStartEngine write FOnStartEngine;
    property OnNeedCommands: TStrataNeedCommands read FOnNeedCommands write FOnNeedCommands;
    property OnKernelBuilt: TNotifyEvent read FOnKernelBuilt write FOnKernelBuilt;
    property CommandTree: TStrataCommandTree read FTree;
    property OnDocumentChanged: TNotifyEvent read FOnDocumentChanged write FOnDocumentChanged;
  end;

implementation

{$R *.lfm}

{ TEditorFrame }

constructor TEditorFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // A SynEdit read from a form file gets only the keys the file lists, and
  // this one lists none, so the editing keys are put in here
  synMacro.SetDefaultKeystrokes;
  synMacro.ResetMouseActions;
  // A fixed-width face that every platform has, smoothed: SynEdit's own
  // default draws it without anti-aliasing
  {$IFDEF DARWIN}
  synMacro.Font.Name := 'Menlo';
  synMacro.Font.Size := 13;
  {$ELSE}
  {$IFDEF WINDOWS}
  synMacro.Font.Name := 'Consolas';
  synMacro.Font.Size := 11;
  {$ELSE}
  synMacro.Font.Name := 'Monospace';
  synMacro.Font.Size := 11;
  {$ENDIF}
  {$ENDIF}
  synMacro.Font.Quality := fqCleartypeNatural;
  synMacro.OnSpecialLineMarkup := @MacroLineMarkup;
  FTree := TStrataCommandTree.Create;
  FKnownMaterials := TStringList.Create;
  FMaterials := TStringList.Create;
  FMaterials.Sorted := True;
  FMaterials.Duplicates := dupIgnore;
  FTree.Materials := FMaterials;
  FHighlighter := TSynStrataMacroSyn.Create(Self);
  FHighlighter.Tree := FTree;
  synMacro.Highlighter := FHighlighter;
  // The list is shown by the frame, which knows what a word is here
  FCompletion := TSynCompletion.Create(Self);
  FCompletion.Editor := synMacro;
  FCompletion.ShortCut := 0;
  FCompletion.EndOfTokenChr := '"';
  FCompletion.OnCodeCompletion := @CompletionAccepted;
  FCompletion.OnUTF8KeyPress := @ListKeyPress;
  synMacro.OnKeyDown := @MacroKeyDown;
  synMacro.OnUTF8KeyPress := @MacroKeyPress;
  synMacro.OnStatusChange := @MacroStatusChange;
  FSavedText := synMacro.Text;
  UpdateHelp;
end;

destructor TEditorFrame.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  synMacro.Highlighter := nil;
  FreeAndNil(FTree);
  FreeAndNil(FMaterials);
  FreeAndNil(FKnownMaterials);
  inherited Destroy;
end;

// A new tree: colours, completion and help follow it
procedure TEditorFrame.SetCommandTree(const AText: String);
begin
  if not FTree.LoadFromText(AText) then FTree.Clear;
  synMacro.Invalidate;
  UpdateHelp;
end;

procedure TEditorFrame.LoadCommandTree(const AFileName: String);
begin
  if not FTree.LoadFromFile(AFileName) then FTree.Clear;
  synMacro.Invalidate;
  UpdateHelp;
end;

procedure TEditorFrame.UpdateHelp;
var
  s: String;
begin
  if FTree.Count = 0 then
    s := 'The list of Geant4 commands is read the first time the engine is ' +
         'initialised, or when a command is started with ''/''.'
  else
    s := FTree.Describe(synMacro.LineText, synMacro.LogicalCaretXY.X);
  if mEdHelp.Text <> s then mEdHelp.Text := s;
end;

procedure TEditorFrame.MacroStatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
  if Changes * [scCaretX, scCaretY, scModified] <> [] then UpdateHelp;
end;

procedure TEditorFrame.MacroKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_SPACE) and (ssCtrl in Shift) then
  begin
    Key := 0;
    ShowCompletion;
  end;
end;

procedure TEditorFrame.MacroKeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
begin
  FSlashTyped := UTF8Key = '/';
  FSpaceTyped := UTF8Key = ' ';
end;

procedure TEditorFrame.SetMaterialNames(AList: TStrings);
begin
  FKnownMaterials.Assign(AList);
end;

// The materials the engine knows, and those the macro creates
procedure TEditorFrame.CollectMaterials;
var
  i: Integer;
  words: TStringList;
  starts: TStringArray;
begin
  FMaterials.Assign(FKnownMaterials);
  words := TStringList.Create;
  try
    for i := 0 to synMacro.Lines.Count - 1 do
    begin
      StrataMacroWords(synMacro.Lines[i], words, starts);
      if (words.Count > 1) and (words[0] = '/strata/material/create') then
        FMaterials.Add(words[1]);
    end;
  finally
    words.Free;
  end;
end;

// What can be typed where the caret is, in a list under it
procedure TEditorFrame.ShowCompletion(ASilent: Boolean);
var
  line, prefix: String;
  caret, start: Integer;
  p: TPoint;
begin
  if synMacro.ReadOnly then Exit;
  if (FTree.Count = 0) and Assigned(FOnNeedCommands) then
  begin
    // Typing does not retry what already failed; asking for it does
    if ASilent and FReadFailed then Exit;
    DoStatus('Reading the list of Geant4 commands...');
    FReadFailed := not FOnNeedCommands();
    if FReadFailed then Exit;
  end;
  if FTree.Count = 0 then Exit;
  if FCompletion.IsActive then FCompletion.Deactivate;
  line := synMacro.LineText;
  caret := synMacro.LogicalCaretXY.X;
  CollectMaterials;
  FCompletion.ItemList.Clear;
  FTree.Complete(line, caret, FCompletion.ItemList, start);
  if FCompletion.ItemList.Count = 0 then
  begin
    if not ASilent then DoStatus('Nothing to complete here');
    Exit;
  end;
  prefix := Copy(line, start, caret - start);
  p := synMacro.ClientToScreen(Point(synMacro.CaretXPix,
    synMacro.CaretYPix + synMacro.LineHeight + 1));
  FCompletion.Execute(prefix, p.X, p.Y);
end;

procedure TEditorFrame.AsyncComplete(Data: PtrInt);
begin
  // A space only offers what is known, it does not start an engine
  if (Data = 2) and (FTree.Count = 0) then Exit;
  if Visible and synMacro.Focused then ShowCompletion(Data <> 0);
end;

// With the list open, only letters and digits filter it.  A '/' goes one
// level down, a space closes it, and anything else is typed, not taken as
// accepting what is selected
procedure TEditorFrame.ListKeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
begin
  if (Length(UTF8Key) <> 1) or (UTF8Key[1] < ' ') or
     (UTF8Key[1] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) then Exit;
  if UTF8Key = '/' then
  begin
    FCompletion.Deactivate;
    FSlashTyped := True;
    synMacro.CommandProcessor(ecChar, UTF8Key, nil);
  end
  else if UTF8Key = ' ' then
  begin
    FCompletion.Deactivate;
    FSpaceTyped := True;
    synMacro.CommandProcessor(ecChar, UTF8Key, nil);
  end
  else
  begin
    synMacro.CommandProcessor(ecChar, UTF8Key, nil);
    FCompletion.CurrentString := FCompletion.CurrentString + UTF8Key;
  end;
  UTF8Key := '';
end;

// A directory chosen from the list opens the next level
procedure TEditorFrame.CompletionAccepted(var Value: string; SourceValue: string;
  var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
begin
  if (Value <> '') and (Value[Length(Value)] = '/') then
    Application.QueueAsyncCall(@AsyncComplete, 0);
end;

// The macro as the viewer should read it: everything but the runs
function TEditorFrame.WriteViewerSetup(const AMacro: String; AGeometryOnly: Boolean): Boolean;
var
  cmds: TStrataMacroCommands;
  L: TStringList;
  i: Integer;
begin
  cmds := StrataParseMacro(synMacro.Lines);
  L := TStringList.Create;
  try
    if FFileName <> '' then
      L.Add('/control/macroPath ' + ExcludeTrailingPathDelimiter(ExtractFilePath(FFileName)));
    for i := 0 to High(cmds) do
    begin
      if cmds[i].Kind <> mkBeamOn then L.Add(cmds[i].Command);
      // The geometry is all there once the kernel is built
      if AGeometryOnly and (cmds[i].Kind = mkInitialize) then Break;
    end;
    try
      L.SaveToFile(AMacro);
      Result := True;
    except
      on E: Exception do
      begin
        DoStatus('Could not write ' + AMacro + ': ' + E.Message);
        Result := False;
      end;
    end;
  finally
    L.Free;
  end;
end;

procedure TEditorFrame.DoStatus(const AText: String);
begin
  if Assigned(FOnStatus) then FOnStatus(AText);
end;

procedure TEditorFrame.DoLog(const AText: String);
begin
  if Assigned(FOnLog) then FOnLog(AText);
end;

procedure TEditorFrame.DoDocumentChanged;
begin
  if Assigned(FOnDocumentChanged) then FOnDocumentChanged(Self);
end;

procedure TEditorFrame.DoStateChanged;
begin
  if Assigned(FOnStateChanged) then FOnStateChanged(Self);
end;

// The images live with the window, so the frame is handed them
procedure TEditorFrame.SetImages(AValue: TCustomImageList);
begin
  EditorActions.Images := AValue;
  btnEdClearLog.Images := AValue;
  btnEdSaveLog.Images := AValue;
  btnEdExportHistogram.Images := AValue;
  btnEdExportAllHistograms.Images := AValue;
end;

procedure TEditorFrame.UpdateState(AOpen, AReady, ARunning: Boolean);
begin
  // The text is what a run is doing, so it stays as it is until the run ends
  // Stopped between commands, the cursor can move but the text cannot change
  synMacro.Enabled := not ARunning and ((not FBusy) or FPaused);
  synMacro.ReadOnly := FBusy;
  actNewMacro.Enabled := not (ARunning or FBusy);
  // Every run starts an engine of its own, so only the backend is needed
  actEdRun.Enabled := StrataLibraryLoaded and not ARunning and ((not FBusy) or FPaused);
  actEdStep.Enabled := actEdRun.Enabled;
  actEdRunToCursor.Enabled := actEdRun.Enabled;
  lbEdHistograms.Enabled := AOpen;
  actEdExportHistogram.Enabled := AOpen and (not ARunning);
  actEdExportAllHistograms.Enabled := AOpen and (not ARunning);
end;

procedure TEditorFrame.ShowLog;
begin
  pcEditor.ActivePage := tabEdLog;
end;

procedure TEditorFrame.AppendLog(ALines: TStrings);
const
  MaxMemoLines = 20000;
begin
  mEdLog.Lines.BeginUpdate;
  try
    mEdLog.Lines.AddStrings(ALines);
    while mEdLog.Lines.Count > MaxMemoLines do
      mEdLog.Lines.Delete(0);
  finally
    mEdLog.Lines.EndUpdate;
  end;
  mEdLog.SelStart := Length(mEdLog.Text);
end;

function TEditorFrame.Modified: Boolean;
begin
  Result := synMacro.Text <> FSavedText;
end;

function TEditorFrame.MayReplaceMacro: Boolean;
begin
  Result := True;
  if not Modified then Exit;
  case MessageDlg('Strata', 'The macro has been modified. Save it?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      begin
        actSaveMacro.Execute;
        // A cancelled Save as leaves it modified, and then so is the answer
        Result := not Modified;
      end;
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

function TEditorFrame.OpenFile(const AFileName: String; AAskFirst: Boolean): Boolean;
begin
  Result := False;
  if AAskFirst and (not MayReplaceMacro) then Exit;
  try
    synMacro.Lines.LoadFromFile(AFileName);
  except
    on E: Exception do
    begin
      MessageDlg('Strata', 'The macro could not be read:' + LineEnding
                 + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  FFileName := AFileName;
  FProposedName := '';
  FSavedText := synMacro.Text;
  FStampFile := AFileName;
  FDiskStamp := StrataFileStamp(AFileName);
  DoDocumentChanged;
  DoStatus('Loaded ' + ExtractFileName(AFileName));
  Result := True;
end;

// A macro that has no file yet, such as one written from the panels
procedure TEditorFrame.LoadText(const AText, AProposedName: String);
begin
  synMacro.Text := AText;
  FFileName := '';
  FProposedName := AProposedName;
  FSavedText := '';
  DoDocumentChanged;
end;

// Another program changed the file: offer to read it again, once per change
procedure TEditorFrame.CheckDiskFile;
var
  stamp, question: String;
begin
  if (FFileName = '') or FCheckingDisk or FBusy then Exit;
  stamp := StrataFileStamp(FFileName);
  if FStampFile <> FFileName then
  begin
    FStampFile := FFileName;
    FDiskStamp := stamp;
    Exit;
  end;
  if (stamp = '') or (stamp = FDiskStamp) then Exit;
  FDiskStamp := stamp;
  if Modified then
    question := ExtractFileName(FFileName) + ' has changed on disk, and the '
                + 'changes made here are not saved.' + LineEnding + LineEnding
                + 'Reload it and lose them?'
  else
    question := ExtractFileName(FFileName) + ' has changed on disk. Reload it?';
  FCheckingDisk := True;
  try
    if MessageDlg('Strata', question, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      OpenFile(FFileName, False);
  finally
    FCheckingDisk := False;
  end;
end;

function TEditorFrame.MacroText: String;
begin
  Result := synMacro.Text;
end;

function TEditorFrame.DocumentCaption: String;
begin
  if FFileName = '' then
    Result := 'Untitled.mac'
  else
    Result := ExtractFileName(FFileName);
  if Modified then Result := '*' + Result;
end;

function TEditorFrame.WriteMacro(const AFileName: String): Boolean;
begin
  Result := False;
  try
    synMacro.Lines.SaveToFile(AFileName);
  except
    on E: Exception do
    begin
      MessageDlg('Strata', 'The macro could not be written:' + LineEnding
                 + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  FFileName := AFileName;
  FProposedName := '';
  FSavedText := synMacro.Text;
  FStampFile := AFileName;
  FDiskStamp := StrataFileStamp(AFileName);
  DoDocumentChanged;
  DoStatus('Saved ' + ExtractFileName(AFileName));
  Result := True;
end;

procedure TEditorFrame.actNewMacroExecute(Sender: TObject);
begin
  if not MayReplaceMacro then Exit;
  synMacro.Clear;
  FFileName := '';
  FProposedName := '';
  FSavedText := synMacro.Text;
  DoDocumentChanged;
  DoStatus('New macro');
end;

procedure TEditorFrame.actSaveMacroExecute(Sender: TObject);
begin
  if FFileName = '' then
    actSaveMacroAs.Execute
  else
    WriteMacro(FFileName);
end;

procedure TEditorFrame.actSaveMacroAsBeforeExecute(Sender: TObject);
begin
  // Propose what is being worked on, and a name only when there is none
  if FFileName <> '' then
    actSaveMacroAs.Dialog.FileName := FFileName
  else if FProposedName <> '' then
    actSaveMacroAs.Dialog.FileName := FProposedName
  else if actSaveMacroAs.Dialog.FileName = '' then
    actSaveMacroAs.Dialog.FileName := 'strata.mac';
end;

procedure TEditorFrame.actSaveMacroAsAccept(Sender: TObject);
begin
  WriteMacro(actSaveMacroAs.Dialog.FileName);
end;

procedure TEditorFrame.actEdClearLogExecute(Sender: TObject);
begin
  mEdLog.Clear;
end;

procedure TEditorFrame.actEdSaveLogBeforeExecute(Sender: TObject);
begin
  if actEdSaveLog.Dialog.FileName = '' then
    actEdSaveLog.Dialog.FileName := 'strata-log.txt';
end;

procedure TEditorFrame.actEdSaveLogAccept(Sender: TObject);
begin
  mEdLog.Lines.SaveToFile(actEdSaveLog.Dialog.FileName);
  DoStatus('Log saved to ' + ExtractFileName(actEdSaveLog.Dialog.FileName));
end;

procedure TEditorFrame.synMacroChange(Sender: TObject);
var
  start: Integer;
  prefix: String;
begin
  // The mark belongs to the text that was refused, not to the one now
  if FErrorLine > 0 then
  begin
    FErrorLine := 0;
    synMacro.Invalidate;
  end;
  // A '/' typed in the command word offers the next level
  if FSlashTyped then
  begin
    FSlashTyped := False;
    if StrataWordAt(synMacro.LineText, synMacro.LogicalCaretXY.X, start, prefix) = 0 then
      Application.QueueAsyncCall(@AsyncComplete, 1);
  end;
  // A space after the command offers the next parameter's choices
  if FSpaceTyped then
  begin
    FSpaceTyped := False;
    if StrataWordAt(synMacro.LineText, synMacro.LogicalCaretXY.X, start, prefix) > 0 then
      Application.QueueAsyncCall(@AsyncComplete, 2);
  end;
  DoDocumentChanged;
end;

procedure TEditorFrame.MacroLineMarkup(Sender: TObject; Line: Integer;
  var Special: Boolean; Markup: TSynSelectedColor);
begin
  if (Line = FErrorLine) and (Line > 0) then
  begin
    Special := True;
    Markup.Foreground := clBlack;
    Markup.Background := $00C8C8FF;   // light red
  end
  else if (Line = FRunLine) and (Line > 0) then
  begin
    Special := True;
    Markup.Foreground := clBlack;
    Markup.Background := $00B8F0FF;   // light yellow
  end
  else if (Line = FPauseLine) and (Line > 0) then
  begin
    Special := True;
    Markup.Foreground := clBlack;
    Markup.Background := $00C8F0C8;   // light green
  end;
end;

// A new engine, and the macro parsed again, for Run, Step or Run to cursor
function TEditorFrame.StartSession: Boolean;
begin
  Result := False;
  CheckDiskFile;
  FCommands := StrataParseMacro(synMacro.Lines);
  if Length(FCommands) = 0 then
  begin
    DoStatus('The macro has no commands to run');
    Exit;
  end;
  FErrorLine := 0;
  FRunLine := 0;
  FPauseLine := 0;
  synMacro.Invalidate;
  // Relative paths in the macro mean what they would beside the file
  if FFileName <> '' then SetCurrentDir(ExtractFilePath(FFileName));
  if (not Assigned(FOnStartEngine)) or (not FOnStartEngine()) then Exit;
  fraEdResults.Clear;
  RefreshHistogramList;
  ShowHistogram;
  FBusy := True;
  FPaused := False;
  FStopRequested := False;
  FNext := 0;
  Result := True;
end;

procedure TEditorFrame.Resume(AToSend, AStopLine: Integer);
begin
  FToSend := AToSend;
  FStopLine := AStopLine;
  FPaused := False;
  FPauseLine := 0;
  synMacro.Invalidate;
  DoStateChanged;
  ContinueRun;
end;

// Run: an engine of its own, then the commands one by one; when stopped
// between commands, the rest of them
procedure TEditorFrame.actEdRunExecute(Sender: TObject);
begin
  if FPaused then
    Resume(-1, 0)
  else if (not FBusy) and StartSession then
    Resume(-1, 0);
end;

// Step: the next command, then stop; the first Step only starts the engine
procedure TEditorFrame.actEdStepExecute(Sender: TObject);
begin
  if FPaused then
    Resume(1, 0)
  else if (not FBusy) and StartSession then
    Resume(0, 0);
end;

// Run to cursor: every command before the cursor's line
procedure TEditorFrame.actEdRunToCursorExecute(Sender: TObject);
var
  target: Integer;
begin
  target := synMacro.CaretY;
  if FPaused then
  begin
    if FCommands[FNext].Line >= target then
    begin
      DoStatus(Format('Line %d has been sent already; put the cursor further down',
        [target]));
      Exit;
    end;
    Resume(-1, target);
  end
  else if (not FBusy) and StartSession then
    Resume(-1, target);
end;

// Stopped before a command: it is marked and the cursor put on it
procedure TEditorFrame.PauseAt(const ACommand: TStrataMacroCommand);
begin
  FPaused := True;
  FPauseLine := ACommand.Line;
  pcEditor.ActivePage := tabMacro;
  synMacro.CaretXY := Point(1, ACommand.Line);
  synMacro.EnsureCursorPosVisible;
  synMacro.Invalidate;
  DoStatus(Format('Stopped before line %d: Step, Run to cursor, Run, or Abort',
    [ACommand.Line]));
  DoStateChanged;
end;

// Abort while stopped: the engine keeps what was sent
procedure TEditorFrame.EndPause;
begin
  if FPaused then FinishRun('Stopped; the rest of the macro was not sent');
end;

// Sends commands until the macro ends, one is refused, or a run starts
procedure TEditorFrame.ContinueRun;
var
  cmd: TStrataMacroCommand;
  err: String;
begin
  while FNext <= High(FCommands) do
  begin
    cmd := FCommands[FNext];
    if (FToSend = 0) or ((FStopLine > 0) and (cmd.Line >= FStopLine)) then
    begin
      PauseAt(cmd);
      Exit;
    end;
    if FToSend > 0 then Dec(FToSend);
    Inc(FNext);
    if cmd.Error <> '' then
    begin
      StopAt(cmd, cmd.Error);
      Exit;
    end;
    case cmd.Kind of
      mkInitialize:
        begin
          Screen.Cursor := crHourGlass;
          try
            try
              FEngine.Initialize;
              if Assigned(FOnKernelBuilt) then FOnKernelBuilt(Self);
            except
              on E: Exception do
              begin
                StopAt(cmd, E.Message);
                Exit;
              end;
            end;
          finally
            Screen.Cursor := crDefault;
          end;
        end;
      mkBeamOn:
        begin
          // The spectra are read now, while the engine can still answer
          RefreshHistogramList;
          if Assigned(FOnRunStarting) then FOnRunStarting(Self);
          try
            FEngine.BeamOn(cmd.Events);
          except
            on E: Exception do
            begin
              StopAt(cmd, E.Message);
              Exit;
            end;
          end;
          FRunLine := cmd.Line;
          synMacro.Invalidate;
          DoStatus(Format('Line %d: running %d events...', [cmd.Line, cmd.Events]));
          DoStateChanged;
          Exit;   // RunFinished goes on from the next command
        end;
    else
      if not FEngine.TryApply(cmd.Command, err) then
      begin
        StopAt(cmd, err);
        Exit;
      end;
    end;
  end;
  FinishRun('Macro finished');
end;

procedure TEditorFrame.RunFinished(AStatus: Integer);
begin
  FRunLine := 0;
  synMacro.Invalidate;
  RefreshHistogramList;
  ShowHistogram;
  fraEdResults.ShowResults(FEngine);
  if not FBusy then Exit;
  if FStopRequested then
    FinishRun('Run aborted, the rest of the macro was not sent')
  else if AStatus <> STRATA_OK then
    FinishRun('Run ended with: ' + StrataStatusText(AStatus))
  else
    ContinueRun;
end;

procedure TEditorFrame.StopAfterRun;
begin
  FStopRequested := True;
end;

procedure TEditorFrame.FinishRun(const AText: String);
begin
  FBusy := False;
  FPaused := False;
  if FPauseLine > 0 then
  begin
    FPauseLine := 0;
    synMacro.Invalidate;
  end;
  DoStatus(AText);
  DoStateChanged;
end;

// The line that was refused is marked and the caret put on it
procedure TEditorFrame.StopAt(const ACommand: TStrataMacroCommand; const AError: String);
begin
  FErrorLine := ACommand.Line;
  DoLog(Format('Line %d refused: %s', [ACommand.Line, AError]));
  DoLog('    ' + ACommand.Command);
  pcEditor.ActivePage := tabMacro;
  synMacro.CaretXY := Point(1, ACommand.Line);
  synMacro.EnsureCursorPosVisible;
  synMacro.Invalidate;
  FinishRun(Format('Stopped at line %d: %s', [ACommand.Line, AError]));
end;

function TEditorFrame.CurrentHistogramId: Integer;
begin
  Result := -1;
  if (lbEdHistograms.ItemIndex >= 0) and (lbEdHistograms.ItemIndex <= High(FHistogramIds)) then
    Result := FHistogramIds[lbEdHistograms.ItemIndex];
end;

// The spectra the macro has switched on, read while the engine can answer
procedure TEditorFrame.RefreshHistogramList;
var
  i, keep, n: Integer;
  h: TStrataHistogram;
begin
  keep := CurrentHistogramId;
  SetLength(FHistogramIds, 0);
  SetLength(FHistogramCache, 0);
  lbEdHistograms.Items.BeginUpdate;
  try
    lbEdHistograms.Items.Clear;
    if Assigned(FEngine) and FEngine.IsOpen
       and (not (FEngine.State in [STRATA_STATE_RUNNING, STRATA_STATE_ABORTING])) then
    begin
      for i := 0 to FEngine.HistogramCount - 1 do
      begin
        h := FEngine.Histogram(i, False);
        if (not h.Active) or (h.Title = 'dummy') then Continue;
        n := Length(FHistogramIds);
        SetLength(FHistogramIds, n + 1);
        SetLength(FHistogramCache, n + 1);
        FHistogramIds[n] := i;
        FHistogramCache[n] := h;
        lbEdHistograms.Items.Add(Format('%d - %s', [i, h.Title]));
      end;
    end;
  finally
    lbEdHistograms.Items.EndUpdate;
  end;
  for i := 0 to High(FHistogramIds) do
    if FHistogramIds[i] = keep then
    begin
      lbEdHistograms.ItemIndex := i;
      Exit;
    end;
  if lbEdHistograms.Items.Count > 0 then lbEdHistograms.ItemIndex := 0;
end;

procedure TEditorFrame.ShowHistogram;
var
  h: TStrataHistogram;
  i, k: Integer;
begin
  chtEdHistogramSeries.Clear;
  k := lbEdHistograms.ItemIndex;
  if (k < 0) or (k > High(FHistogramIds)) then
  begin
    chtEdHistogram.Title.Text.Text := 'Histogram';
    Exit;
  end;
  if FEngine.State in [STRATA_STATE_RUNNING, STRATA_STATE_ABORTING] then
  begin
    h := FHistogramCache[k];
    FEngine.LiveHistogram(FHistogramIds[k], h);
  end
  else
    h := FEngine.Histogram(FHistogramIds[k], True);
  chtEdHistogram.Title.Text.Text := Format('h1[%d]  %s', [h.Id, h.Title]);
  chtEdHistogram.BottomAxis.Title.Caption := h.XAxisTitle;
  chtEdHistogram.LeftAxis.Title.Caption := h.YAxisTitle;
  for i := 0 to High(h.Y) do
    chtEdHistogramSeries.AddXY(h.X[i], h.Y[i]);
end;

// The spectrum being watched, as far as the run has got
procedure TEditorFrame.LivePoll;
begin
  if pcEditor.ActivePage <> tabEdHistograms then Exit;
  Inc(FLivePolls);
  if FLivePolls >= 2 then
  begin
    FLivePolls := 0;
    ShowHistogram;
  end;
end;

procedure TEditorFrame.lbEdHistogramsSelectionChange(Sender: TObject; User: boolean);
begin
  ShowHistogram;
end;

procedure TEditorFrame.actEdExportHistogramExecute(Sender: TObject);
var
  h: TStrataHistogram;
begin
  if CurrentHistogramId < 0 then Exit;
  h := FEngine.Histogram(CurrentHistogramId, True);
  if Length(h.Y) = 0 then
  begin
    MessageDlg('Strata', 'That histogram has no data to export.', mtInformation,
      [mbOK], 0);
    Exit;
  end;
  SaveHistogramAs(h);
end;

// The argument of the macro's last /analysis/setFileName, empty when it has none
function TEditorFrame.HistogramOutputName: String;
const
  kCmd = '/analysis/setFileName';
var
  i: Integer;
  line: String;
begin
  Result := '';
  for i := synMacro.Lines.Count - 1 downto 0 do
  begin
    line := Trim(synMacro.Lines[i]);
    if (Pos(kCmd, line) = 1) and ((Length(line) = Length(kCmd)) or (line[Length(kCmd) + 1] in [' ', #9])) then
      Exit(Trim(Copy(line, Length(kCmd) + 1, MaxInt)));
  end;
end;

// Asks where to write one histogram and writes it; False when the user cancels
function TEditorFrame.SaveHistogramAs(const AHistogram: TStrataHistogram): Boolean;
var
  outName: String;
begin
  outName := HistogramOutputName;
  dlgEdExportHistogram.FileName := StrataHistogramCSVName(StrataHistogramBase(outName, FFileName), AHistogram.Id);
  dlgEdExportHistogram.Filter := 'Comma-separated values|*.csv|All files|*';
  if (outName <> '') and ((outName[1] in ['/', '\']) or (ExtractFileDrive(outName) <> '')) then
    dlgEdExportHistogram.InitialDir := ExtractFileDir(outName)
  else if FFileName <> '' then
    dlgEdExportHistogram.InitialDir := ExtractFileDir(FFileName);
  Result := dlgEdExportHistogram.Execute;
  if not Result then Exit;
  WriteHistogramCSV(AHistogram, dlgEdExportHistogram.FileName);
  DoStatus('exported ' + dlgEdExportHistogram.FileName);
end;

// Every active histogram, each to the file the user picks; Cancel stops the rest
procedure TEditorFrame.actEdExportAllHistogramsExecute(Sender: TObject);
var
  h: TStrataHistogram;
  i, nSaved: Integer;
  noData: String;
begin
  RefreshHistogramList;
  if Length(FHistogramIds) = 0 then
  begin
    MessageDlg('Strata', 'There are no active histograms to export.', mtInformation, [mbOK], 0);
    Exit;
  end;
  nSaved := 0;
  noData := '';
  for i := 0 to High(FHistogramIds) do
  begin
    h := FEngine.Histogram(FHistogramIds[i], True);
    if Length(h.Y) = 0 then
    begin
      noData := noData + Format(' h1[%d]', [FHistogramIds[i]]);
      Continue;
    end;
    if not SaveHistogramAs(h) then Break;
    Inc(nSaved);
  end;
  if noData <> '' then
    DoStatus(Format('exported %d of %d active histograms; no data in%s', [nSaved, Length(FHistogramIds), noData]))
  else
    DoStatus(Format('exported %d of %d active histograms', [nSaved, Length(FHistogramIds)]));
end;

end.
