{==============================================================================
  StrataGUI: Lazarus front end for the Strata Geant4 backend.
==============================================================================}

program StrataGUI;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms, lazcontrols,
  uStrataApi, uMain, uOptions, uAbout, uDatasets, uMaterials, uStrataWidgets,
  uPanelsFrame, uEditorFrame, uSynStrataMacro;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Title:='Strata';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TOptionsDlg, OptionsDlg);
  Application.CreateForm(TAboutBox, AboutBox);
  Application.CreateForm(TDatasetsDlg, DatasetsDlg);
  Application.CreateForm(TMaterialsDlg, MaterialsDlg);
  Application.Run;

  // Exit Strata proccess
  if StrataLibraryLoaded then
    strata_exit_process(0);
end.
