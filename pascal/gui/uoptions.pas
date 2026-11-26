{==============================================================================
  uOptions.pas: Geant4/Strata configuration settings.
==============================================================================}

unit uOptions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  ButtonPanel, uStrataApi, uStrataApp;

type

  { TOptionsDlg }

  TOptionsDlg = class(TForm)
    btnBrowseData: TBitBtn;
    btnBrowseGeant4: TBitBtn;
    btnBrowseLibrary: TBitBtn;
    btnBrowseOutput: TBitBtn;
    btnBrowseStrata: TBitBtn;
    ButtonPanel: TButtonPanel;
    editData: TEdit;
    editTerminal: TEdit;
    lblData: TLabel;
    lblTerminal: TLabel;
    editGeant4: TEdit;
    editLibrary: TEdit;
    editOutput: TEdit;
    editStrata: TEdit;
    lblGeant4: TLabel;
    lblLibrary: TLabel;
    lblOutput: TLabel;
    lblStrata: TLabel;
    OpenDialog: TOpenDialog;
    DirectoryDialog: TSelectDirectoryDialog;

    procedure btnBrowseDataClick(Sender: TObject);
    procedure btnBrowseGeant4Click(Sender: TObject);
    procedure btnBrowseLibraryClick(Sender: TObject);
    procedure btnBrowseOutputClick(Sender: TObject);
    procedure btnBrowseStrataClick(Sender: TObject);
  private
    { private declarations }
  public
    // Load settings from record into form edits
    procedure SetOptions(const AOptions: TStrataOptions);
    // Extract settings from form edits into record
    procedure GetOptions(var AOptions: TStrataOptions);
  end;

var
  OptionsDlg: TOptionsDlg;

implementation

{$R *.lfm}

uses uMain;

{ TOptionsDlg }

procedure TOptionsDlg.SetOptions(const AOptions: TStrataOptions);
begin
  editOutput.Text := AOptions.OutputDir;
  editGeant4.Text := AOptions.Geant4Dir;
  editData.Text := AOptions.DataDir;
  editTerminal.Text := AOptions.Terminal;
  editLibrary.Text := AOptions.LibraryDir;
  editStrata.Text := AOptions.StrataExe;
end;

procedure TOptionsDlg.GetOptions(var AOptions: TStrataOptions);
begin
  AOptions.OutputDir := editOutput.Text;
  AOptions.Geant4Dir := editGeant4.Text;
  AOptions.DataDir := editData.Text;
  AOptions.Terminal := editTerminal.Text;
  AOptions.LibraryDir := editLibrary.Text;
  AOptions.StrataExe := editStrata.Text;
end;

procedure TOptionsDlg.btnBrowseOutputClick(Sender: TObject);
begin
  DirectoryDialog.Title := 'Select Output Directory';
  if DirectoryExists(editOutput.Text) then
    DirectoryDialog.FileName := editOutput.Text;

  if DirectoryDialog.Execute then
    editOutput.Text := DirectoryDialog.FileName;
end;

procedure TOptionsDlg.btnBrowseDataClick(Sender: TObject);
begin
  DirectoryDialog.Title := 'Select Geant4 Dataset Directory';
  if DirectoryExists(editData.Text) then
    DirectoryDialog.FileName := editData.Text;

  if DirectoryDialog.Execute then
    editData.Text := DirectoryDialog.FileName;
end;

procedure TOptionsDlg.btnBrowseGeant4Click(Sender: TObject);
begin
  DirectoryDialog.Title := 'Select Geant4 Directory';
  if DirectoryExists(editGeant4.Text) then
    DirectoryDialog.FileName := editGeant4.Text;

  if DirectoryDialog.Execute then
    editGeant4.Text := DirectoryDialog.FileName;
end;

procedure TOptionsDlg.btnBrowseLibraryClick(Sender: TObject);
begin
  OpenDialog.Title := 'Select Strata Library';

  OpenDialog.Filter := Format('Dynamic Library (%s)|%s|All Files (*.*)|*.*', [StrataDefaultLibName, StrataDefaultLibName]);

  if DirectoryExists(editLibrary.Text) then
  begin
    OpenDialog.InitialDir := editLibrary.Text;
    OpenDialog.FileName := StrataDefaultLibName;
  end;

  if OpenDialog.Execute then
    editLibrary.Text := ExtractFilePath(OpenDialog.FileName);
end;

procedure TOptionsDlg.btnBrowseStrataClick(Sender: TObject);
begin
  OpenDialog.Title := 'Select Strata Executable';

  {$IfDef WINDOWS}
  OpenDialog.Filter := 'Executables (*.exe)|*.exe|All Files (*.*)|*.*';
  {$Else}
  OpenDialog.Filter := 'All Files (*)|*';
  {$EndIf}

  if FileExists(editStrata.Text) then
  begin
    OpenDialog.InitialDir := ExtractFilePath(editStrata.Text);
    OpenDialog.FileName := ExtractFileName(editStrata.Text);
  end;

  if OpenDialog.Execute then
    editStrata.Text := OpenDialog.FileName;
end;

end.
