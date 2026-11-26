{==============================================================================
  uDatasets.pas: Fetching the Geant4 datasets from the window.

  A missing dataset is something to fix here rather than a reason to go back to
  an installer.
  The work is done by TStrataFetcher in bounded steps driven from a timer:
  no thread, and the window stays alive through a 350 MB download.
==============================================================================}

unit uDatasets;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, Buttons, CheckLst,
  ComCtrls, ExtCtrls, uStrataDatasets, uStrataFetch;

type

  { TDatasetsDlg }

  TDatasetsDlg = class(TForm)
    btnBrowseWhere: TBitBtn;
    btnClose: TBitBtn;
    btnStart: TBitBtn;
    btnStop: TBitBtn;
    DirectoryDialog: TSelectDirectoryDialog;
    editWhere: TEdit;
    lbDatasets: TCheckListBox;
    lblStatus: TLabel;
    lblSummary: TLabel;
    lblWhere: TLabel;
    pbFile: TProgressBar;
    tmrFetch: TTimer;
    procedure btnBrowseWhereClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lbDatasetsClickCheck(Sender: TObject);
    procedure tmrFetchTimer(Sender: TObject);
  private
    FFetcher: TStrataFetcher;
    FFetched: Boolean;              // whether anything was installed here
    function Busy: Boolean;
    procedure FillList;
    procedure UpdateSummary;
    procedure UpdateButtons;
  public
    // The directory to point Geant4 at afterwards
    function Destination: String;
    property Fetched: Boolean read FFetched;
    procedure SetDestination(const ADir: String);
  end;

// Where datasets go when the user has not set a value
function StrataDefaultDataDir: String;

var
  DatasetsDlg: TDatasetsDlg;

implementation

{$R *.lfm}

uses
  uMain, uSciRestorer;

function StrataDefaultDataDir: String;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('LOCALAPPDATA');
  if Result = '' then Result := GetUserDir;
  Result := IncludeTrailingPathDelimiter(Result) + 'Strata' + PathDelim + 'data';
  {$ELSE}
    {$IFDEF DARWIN}
    Result := IncludeTrailingPathDelimiter(GetUserDir) + 'Library/Application Support/Strata/data';
    {$ELSE}
    Result := GetEnvironmentVariable('XDG_DATA_HOME');
    if Result = '' then
      Result := IncludeTrailingPathDelimiter(GetUserDir) + '.local/share';
    Result := IncludeTrailingPathDelimiter(Result) + 'strata/data';
    {$ENDIF}
  {$ENDIF}
end;

{ TDatasetsDlg }

procedure TDatasetsDlg.FormCreate(Sender: TObject);
begin
  MainForm.StrataRestorer.RestoreForm(Self, 'DatasetsDlg', [svSize,svLocation,svState,svPanels,svGrids]);

  FFetcher := TStrataFetcher.Create;
  editWhere.Text := StrataDefaultDataDir;
  FillList;
end;

procedure TDatasetsDlg.FormDestroy(Sender: TObject);
begin
  FFetcher.Free;
end;

procedure TDatasetsDlg.SetDestination(const ADir: String);
begin
  if Trim(ADir) <> '' then editWhere.Text := ADir;
  FFetched := False;
  FillList;
end;

function TDatasetsDlg.Destination: String;
begin
  Result := ExcludeTrailingPathDelimiter(Trim(editWhere.Text));
end;

function TDatasetsDlg.Busy: Boolean;
begin
  Result := FFetcher.Stage in [fsSizing, fsDownloading, fsVerifying, fsExtracting];
end;

// What is there, what is wanted and what it weighs
procedure TDatasetsDlg.FillList;
var
  i: Integer;
  here, what: String;
  present: Boolean;
begin
  here := Destination;
  lbDatasets.Items.BeginUpdate;
  try
    lbDatasets.Items.Clear;
    for i := 0 to kStrataDatasetCount - 1 do
    begin
      present := StrataDatasetPresent(here, kStrataDatasets[i]);
      what := kStrataDatasets[i].Directory;
      if kStrataDatasets[i].Required then
        what := what + '  (required)';
      if present then
        what := what + '  -- already here'
      else
        what := what + '  -- not here';
      what := what + ',  ' + kStrataDatasets[i].Description;
      lbDatasets.Items.Add(what);
      lbDatasets.Checked[i] := kStrataDatasets[i].Required and (not present);
    end;
  finally
    lbDatasets.Items.EndUpdate;
  end;
  UpdateSummary;
  UpdateButtons;
end;

procedure TDatasetsDlg.UpdateSummary;
var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to lbDatasets.Items.Count - 1 do
    if lbDatasets.Checked[i] then Inc(n);
  if n = 0 then
    lblSummary.Caption := 'Nothing selected'
  else
    lblSummary.Caption := Format('%d selected. The archives are fetched one '
                                 + 'at a time, checked against Geant4''s own '
                                 + 'checksums and unpacked here.', [n]);
end;

procedure TDatasetsDlg.UpdateButtons;
begin
  btnStart.Enabled := not Busy;
  btnStop.Enabled := Busy;
  editWhere.Enabled := not Busy;
  btnBrowseWhere.Enabled := not Busy;
  lbDatasets.Enabled := not Busy;
end;

procedure TDatasetsDlg.lbDatasetsClickCheck(Sender: TObject);
begin
  UpdateSummary;
end;

procedure TDatasetsDlg.btnBrowseWhereClick(Sender: TObject);
begin
  DirectoryDialog.Title := 'Select Geant4 Dataset Directory';
  if DirectoryExists(editWhere.Text) then
    DirectoryDialog.FileName := editWhere.Text;
  if DirectoryDialog.Execute then
  begin
    editWhere.Text := DirectoryDialog.FileName;
    FillList;
  end;
end;

procedure TDatasetsDlg.btnStartClick(Sender: TObject);
var
  want: array of Boolean;
  i: Integer;
  err: String;
begin
  SetLength(want, lbDatasets.Items.Count);
  for i := 0 to lbDatasets.Items.Count - 1 do
    want[i] := lbDatasets.Checked[i];

  if not FFetcher.Start(Destination, want, err) then
  begin
    MessageDlg('Geant4 datasets', err, mtError, [mbOK], 0);
    Exit;
  end;

  pbFile.Position := 0;
  lblStatus.Caption := FFetcher.Status;
  tmrFetch.Enabled := True;
  UpdateButtons;
end;

procedure TDatasetsDlg.btnStopClick(Sender: TObject);
begin
  tmrFetch.Enabled := False;
  FFetcher.Stop;
  lblStatus.Caption := 'Stopped. What has arrived is kept, and starting again '
                       + 'carries on from there.';
  UpdateButtons;
end;

procedure TDatasetsDlg.tmrFetchTimer(Sender: TObject);
begin
  FFetcher.Step;

  if FFetcher.FileTotal > 0 then
    pbFile.Position := Round(1000.0*FFetcher.FileDone/FFetcher.FileTotal)
  else
    pbFile.Position := 0;

  if FFetcher.Stage = fsDownloading then
    lblStatus.Caption := Format('%s  (%s of %s)',
      [FFetcher.Status, StrataBytesText(FFetcher.FileDone),
       StrataBytesText(FFetcher.FileTotal)])
  else
    lblStatus.Caption := FFetcher.Status;

  case FFetcher.Stage of
    fsFinished:
      begin
        tmrFetch.Enabled := False;
        FFetched := True;
        pbFile.Position := pbFile.Max;
        FillList;
        lblStatus.Caption := 'Done. Strata will read the datasets from here.';
      end;
    fsFailed:
      begin
        tmrFetch.Enabled := False;
        FillList;
        lblStatus.Caption := FFetcher.Failed;
        MessageDlg('Geant4 datasets', FFetcher.Failed + LineEnding + LineEnding
                   + 'What has arrived is kept, so starting again carries on '
                   + 'from where this stopped.', mtError, [mbOK], 0);
      end;
  end;
end;

procedure TDatasetsDlg.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MainForm.StrataRestorer.SaveForm(Self, 'DatasetsDlg', [svSize,svLocation,svState,svPanels,svGrids]);

  tmrFetch.Enabled := False;
  if Busy then FFetcher.Stop;
end;

end.
