{==============================================================================
  uPanelsFrame.pas: the set-up pages and the .scf document behind them.

  Geometry, beam and physics panels do not hold state of their own: pressing
  Apply translates the widgets into Geant4 UI commands, and the geometry
  page is then refilled from what the backend actually built.  That way the
  window can never drift out of step with the simulation.
==============================================================================}

unit uPanelsFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Grids, Spin, CheckLst, Menus, ActnList, StdActns, Buttons, LCLType,
  ImgList, uSciEdit, uSciPeriodicTableDlg, Process, uStrataConfig,
  DividerBevel, BCTrackbarUpdown, uStrataApi, uStrataEngine, uStrataApp,
  uUnitParser, uSciGrid, uMaterials, uStrataWidgets, TAGraph,
  TASeries, FileUtil;

type
  // A yes/no question the window answers
  TStrataQuery = function: Boolean of object;

  TStringArray = array of String;

  { TPanelsFrame }

  TPanelsFrame = class(TFrame)
    PanelsActions: TActionList;
    actInitialize: TAction;
    actApplyGeometry: TAction;
    actApplyBeam: TAction;
    actApplyField: TAction;
    actApplyPhysics: TAction;
    actAddElement: TAction;
    actCreateMaterial: TAction;
    actClearLog: TAction;
    actSelectMaterial: TAction;
    actSelectElement: TAction;
    actSelectIon: TAction;
    actSendCommand: TAction;
    actPrintMaterials: TAction;
    actRefreshMaterials: TAction;
    actRemoveElement: TAction;
    actSaveLog: TFileSaveAs;
    actBeamOn: TAction;
    actSaveConfig: TAction;
    actNewConfig: TAction;
    actImportMacro: TFileOpen;
    actSaveConfigAs: TFileSaveAs;
    actExportMacro: TFileSaveAs;
    btnApplyGeometry: TSpeedButton;
    btnUseLastSeeds: TSpeedButton;
    cbRndEngine: TComboBox;
    chkDamage: TCheckBox;
    chkRandomize: TCheckBox;
    chkSaveCascades: TCheckBox;
    chkSavePrimaries: TCheckBox;
    divRBS: TDividerBevel;
    divRandom: TDividerBevel;
    edCascadesName: TEdit;
    edOutputBase: TEdit;
    edPrimariesName: TEdit;
    edWorldMaterial: TLabel;
    gbOutput: TGroupBox;
    gbRandom: TGroupBox;
    gbTarget: TGroupBox;
    lblCutElectron: TLabel;
    lblCutGamma: TLabel;
    lblCutPositron: TLabel;
    lblCutProton: TLabel;
    lblLayerCount: TLabel;
    lblOutputBase: TLabel;
    lblOutputHint: TLabel;
    lblRndEngine: TLabel;
    lblRndSeeds: TLabel;
    lblSizeYZ: TLabel;
    lblTemperature: TLabel;
    lblTracksHint: TLabel;
    lblWorldMaterial: TLabel;
    pnlCuts: TPanel;
    pnlEField: TPanel;
    pnlBField: TPanel;
    pnlEditors: TPanel;
    pnlOptions: TPanel;
    pnlIon: TPanel;
    seCutElectron: TSciEdit;
    seCutGamma: TSciEdit;
    seCutPositron: TSciEdit;
    seCutProton: TSciEdit;
    seEFieldEx: TSciEdit;
    seEFieldEy: TSciEdit;
    seEFieldEz: TSciEdit;
    seFieldBx: TSciEdit;
    seFieldBy: TSciEdit;
    seFieldBz: TSciEdit;
    seIonA: TSpinEdit;
    seIonQ: TSpinEdit;
    seIonZ: TSpinEdit;
    seLayerCount: TSpinEdit;
    seRndSeed1: TSpinEdit;
    seRndSeed2: TSpinEdit;
    seSizeYZ: TSciEdit;
    seTemperature: TSciEdit;
    btnWorldMaterial: TSpeedButton;
    spltOptions: TSplitter;
    tabOptions: TTabSheet;
    btnApplyBeam: TSpeedButton;
    btnSelectIon: TSpeedButton;
    btnApplyPhysics: TSpeedButton;
    btnMatAddRow: TSpeedButton;
    btnMatCreate: TSpeedButton;
    btnMatDelRow: TSpeedButton;
    btnFieldApply: TSpeedButton;
    cbParticle: TComboBox;
    cbPhysicsList: TComboBox;
    cbFieldStepper: TComboBox;
    actApplyEField: TAction;
    cbEFieldStepper: TComboBox;
    clbOptionalPhysics: TCheckListBox;
    btnEFieldApply: TSpeedButton;
    gbCmdBeam: TGroupBox;
    gbEField: TGroupBox;
    lblEFieldE: TLabel;
    lblEFieldHint: TLabel;
    lblEFieldMinStep: TLabel;
    lblEFieldStepper: TLabel;
    gbDeexcitation: TGroupBox;
    gbCuts: TGroupBox;
    gbTracking: TGroupBox;
    chkEmFluo: TCheckBox;
    chkEmAuger: TCheckBox;
    chkEmAugerCascade: TCheckBox;
    chkEmPixe: TCheckBox;
    chkEmDeexIgnoreCut: TCheckBox;
    chkCut: TCheckBox;
    chkStepMax: TCheckBox;
    cbKillSecondaries: TComboBox;
    lblDeexHint: TLabel;
    lblKillSecondaries: TLabel;
    seCut: TSciEdit;
    seStepMax: TSciEdit;
    gbRBS: TGroupBox;
    chkRBS: TCheckBox;
    chkRBSScreening: TCheckBox;
    lblRBSAngle: TLabel;
    lblRBSSolidAngle: TLabel;
    lblRBSResolution: TLabel;
    lblRBSTilt: TLabel;
    seRBSAngle: TSciEdit;
    seRBSSolidAngle: TSciEdit;
    seRBSResolution: TSciEdit;
    seRBSTilt: TSciEdit;
    seEFieldMinStep: TSciEdit;
    gbCmdGeometry: TGroupBox;
    gbCmdPreInit: TGroupBox;
    gbCmdRun: TGroupBox;
    memCmdBeam: TMemo;
    memCmdGeometry: TMemo;
    memCmdPreInit: TMemo;
    memCmdRun: TMemo;
    edMatName: TEdit;
    actRunMacro: TFileOpen;
    gbBeam: TGroupBox;
    gbLayers: TGroupBox;
    gbNewMaterial: TGroupBox;
    gbDamage: TGroupBox;
    gbOptionalPhysics: TGroupBox;
    gbField: TGroupBox;
    lblBeamAngle: TLabel;
    lblBeamRadius: TLabel;
    lblEnergy: TLabel;
    lblIon: TLabel;
    lblIonHint: TLabel;
    lblMatDensity: TLabel;
    lblMatName: TLabel;
    lblMatSum: TLabel;
    lblParticle: TLabel;
    lblPhysicsList: TLabel;
    lblFieldB: TLabel;
    lblFieldHint: TLabel;
    lblFieldMinStep: TLabel;
    lblFieldStepper: TLabel;
    pnlNewMaterial: TPanel;
    pnlPhysics: TPanel;
    pnlBeam: TPanel;
    pnlGeometry: TPanel;
    rgMatMode: TRadioGroup;
    StrataTableDlg: TSciPeriodicTableDlg;
    seBeamAngle: TSciEdit;
    seBeamRadius: TSciEdit;
    seEnergy: TSciEdit;
    seMatDensity: TSciEdit;
    sgConstituents: TStringGrid;
    sgDamage: TStringGrid;
    sgLayers: TStringGrid;
    divMaterials: TDividerBevel;
    spltMaterials: TSplitter;
    spltGeometry: TSplitter;
    spltBeamMaterials: TSplitter;
    btnClearLog: TSpeedButton;
    btnMatPrint: TSpeedButton;
    btnMatRefresh: TSpeedButton;
    btnRunMacro: TSpeedButton;
    btnSaveLog: TSpeedButton;
    btnSendCommand: TSpeedButton;
    edCommand: TEdit;
    gbDefinedMaterials: TGroupBox;
    lbDefinedMaterials: TListBox;
    mLog: TMemo;
    pcMain: TPageControl;
    pnlCommand: TPanel;
    pnlLogButtons: TPanel;
    seFieldMinStep: TSciEdit;
    sgVoxelDefs: TStringGrid;
    gbVoxels: TGroupBox;
    lblVoxelCount: TLabel;
    lblVoxelHint: TLabel;
    seVoxelCount: TSpinEdit;
    tabBeamPhysics: TTabSheet;
    tabGeometry: TTabSheet;
    tabHistograms: TTabSheet;
    tabLog: TTabSheet;
    tabMaterials: TTabSheet;
    tabResults: TTabSheet;
    actActivateHistogram: TAction;
    actDeactivateHistogram: TAction;
    actExportHistogram: TAction;
    actRefreshHistograms: TAction;
    btnExportHistogram: TSpeedButton;
    btnH1Apply: TSpeedButton;
    btnH1Off: TSpeedButton;
    btnRefreshHistograms: TSpeedButton;
    chbH1Log: TCheckBox;
    chkOnlyActiveHistograms: TCheckBox;
    chtHistogram: TChart;
    chtHistogramSeries: TLineSeries;
    dlgExportHistogram: TSaveDialog;
    lbHistogram: TListBox;
    lblH1Bins: TLabel;
    lblH1Hint: TLabel;
    lblH1Max: TLabel;
    lblH1Min: TLabel;
    pnlHistogramSetup: TPanel;
    pnlHistograms: TPanel;
    seH1Bins: TSpinEdit;
    seH1Max: TSciEdit;
    seH1Min: TSciEdit;
    spltHistograms: TSplitter;
    pnlSummary: TPanel;
    sgSummary: TStringGrid;
    sgVoxels: TStringGrid;
    spltResults: TSplitter;
    procedure actActivateHistogramExecute(Sender: TObject);
    procedure actDeactivateHistogramExecute(Sender: TObject);
    procedure actExportHistogramExecute(Sender: TObject);
    procedure actRefreshHistogramsExecute(Sender: TObject);
    procedure lbHistogramSelectionChange(Sender: TObject; User: boolean);
    procedure actAddElementExecute(Sender: TObject);
    procedure actApplyBeamExecute(Sender: TObject);
    procedure actApplyGeometryExecute(Sender: TObject);
    procedure actApplyBFieldExecute(Sender: TObject);
    procedure actApplyEFieldExecute(Sender: TObject);
    procedure actApplyPhysicsExecute(Sender: TObject);
    procedure actNewConfigExecute(Sender: TObject);
    procedure actSaveConfigExecute(Sender: TObject);
    procedure actSelectMaterialExecute(Sender: TObject);
    procedure chkRandomizeChange(Sender: TObject);
    procedure chkSaveTracksChange(Sender: TObject);
    procedure RBSEnabledChange(Sender: TObject);
    procedure DamageEnabledChange(Sender: TObject);
    procedure pcMainChange(Sender: TObject);
    procedure OptionToggled(Sender: TObject);
    procedure btnUseLastSeedsClick(Sender: TObject);
    procedure actBeamOnExecute(Sender: TObject);
    procedure actClearLogExecute(Sender: TObject);
    procedure actCreateMaterialExecute(Sender: TObject);
    procedure actExportMacroAccept(Sender: TObject);
    procedure actExportMacroBeforeExecute(Sender: TObject);
    procedure actImportMacroAccept(Sender: TObject);
    procedure actInitializeExecute(Sender: TObject);
    procedure actPrintMaterialsExecute(Sender: TObject);
    procedure actRefreshMaterialsExecute(Sender: TObject);
    procedure actRemoveElementExecute(Sender: TObject);
    procedure actRunMacroAccept(Sender: TObject);
    procedure actRunMacroBeforeExecute(Sender: TObject);
    procedure actSaveConfigAsAccept(Sender: TObject);
    procedure actSaveConfigAsBeforeExecute(Sender: TObject);
    procedure actSaveLogAccept(Sender: TObject);
    procedure actSaveLogBeforeExecute(Sender: TObject);
    procedure actSelectElementExecute(Sender: TObject);
    procedure actSelectIonExecute(Sender: TObject);
    procedure actSendCommandExecute(Sender: TObject);
    procedure cbParticleChange(Sender: TObject);
    procedure edCommandKeyPress(Sender: TObject; var Key: char);
    procedure FieldValueChange(Sender: TObject; NewValue: Double);
    procedure lbDefinedMaterialsDblClick(Sender: TObject);
    procedure lbDefinedMaterialsDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure rgMatModeClick(Sender: TObject);
    procedure sgConstituentsEditingDone(Sender: TObject);
    procedure seLayerCountChange(Sender: TObject);
    procedure sgConstituentsSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
    procedure seVoxelCountChange(Sender: TObject);
    procedure sgConstituentsButtonClick(Sender: TObject; aCol, aRow: Integer);
    procedure sgLayersButtonClick(Sender: TObject; aCol, aRow: Integer);
    procedure sgVoxelDefsSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
    procedure sgLayersSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
    procedure sgDamageSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
  private
    FEngine: TStrataEngine;
    FApp: TStrataApp;
    FThreads: TBCTrackbarUpdown;     // the window's thread count, saved with the set-up
    FEvents: TBCTrackbarUpdown;      // the window's event count, saved with the set-up
    FHistogramIds: array of Integer;
    FHistogramActive: array of Boolean;
    // What each spectrum is, indexed by id and read while the engine could still answer
    FHistogramCache: array of TStrataHistogram;
    FLivePolls: Integer;             // so the chart is redrawn every other poll
    FH1Units: TStringList;           // unit last applied, per histogram id
    FH1Fcns: TStringList;            // binning function, per histogram id
    FH1Commands: TStringList;        // the /analysis/h1/set commands in force
    FOnStatus: TStrataNotify;
    FOnLog: TStrataNotify;
    FOnStage: TStrataNotify;
    FOnStateChanged: TNotifyEvent;
    FOnKernelBuilt: TNotifyEvent;
    FOnDocumentChanged: TNotifyEvent;
    FOnRunStarting: TNotifyEvent;
    FOnNewDocument: TStrataQuery;
    FConfig: TStrataConfig;          // the set-up, as it is saved and loaded
    // Once addPhysics has been sent there is no way back
    FPhysicsApplied: Boolean;
    FConfigFile: String;             // the file it came from, empty when untitled
    FConfigSaved: String;            // its text when it was last read or written
    FMaterialNames: TStringList;     // union of defined and NIST, for picking
    FDefinedMaterials: TStringList;  // only what the material table holds
    FElementNames: TStringList;      // NIST element symbols

    // One value-and-unit editor per quantity column, created on first use
    FLayerThicknessEditor: TSciGridEditor;
    FLayerDensityEditor: TSciGridEditor;
    FVoxelEditor: TSciGridEditor;
    procedure FillStepperList;
    function CurrentStepper: Integer;
    procedure SelectStepper(ANumber: Integer);
    procedure FillEStepperList;
    function CurrentEStepper: Integer;
    procedure SelectEStepper(ANumber: Integer);
    function MagneticFieldWanted: Boolean;
    function ElectricFieldWanted: Boolean;
    function ReadVoxelTriple(ARow, AColX, AColY, AColZ: Integer; out AX, AY, AZ: Double; out AUnit: String): Boolean;
    function CommandEditor(AStage: TStrataStage): TMemo;
    procedure SendStageCommands(AStage: TStrataStage);
    function ConfigText: String;
    function ConfigModified: Boolean;
    procedure ApplyRBS;
    procedure ApplyDamage;
    procedure DamageFromGrid;
    procedure RefreshDamageGrid;
    procedure ApplyRunOptions(AIdleOnly: Boolean);
    function ParticleCutEdit(AIndex: Integer): TSciEdit;
    procedure AdoptConfigFile(const AFileName: String);
    procedure MarkConfigSaved;
    procedure WriteConfig(const AFileName: String);
    function PhysicsListName: String;

    procedure PopulateCatalogues;
    procedure ShowOptionalPhysics;
    function RestoreSelection(ACombo: TComboBox; const AWanted, ADefault: String): Boolean;
    procedure RefreshGeometryGrid;
    procedure SetVoxelCount(ACount: Integer);
    procedure RefreshVoxelGrid;
    procedure ApplyRandomSetup;
    procedure ApplyTrackFiles;
    function SavingTracks: Boolean;
    function TrackOutputAccepted: Boolean;
    procedure ResizeLayerGrid(ACount: Integer);

    procedure ConfigFromWidgets;
    procedure ConfigToWidgets;
    procedure ReplayMaterials;
    procedure WorkInDirectoryOf(const AFileName: String);
    procedure RefreshMaterialCatalogue;
    procedure ResizeConstituentGrid(ACount: Integer);
    procedure LoadMaterialIntoEditor(const AName: String);
    procedure RecordMaterialRecipe(AIndex: Integer; const AName: String; ADensity: Double);
    procedure UpdateConstituentSum;
    function MaterialByAtoms: Boolean;
    procedure PickMaterialInto(AGrid: TStringGrid; ACol, ARow: Integer);
    function IonSelected: Boolean;
    function OutputFolder: String;
    function ApplyOutputSettings: Boolean;
    function ProposeH1Range(const AHistogram: TStrataHistogram; out ALow, AHigh: Double; out AUnit: String): Boolean;
    procedure DoStatus(const AText: String);
    procedure DoLog(const AText: String);
    procedure DoStage(const AText: String);
    procedure DoStateChanged;
    procedure DoDocumentChanged;
    procedure DoRunStarting;
    procedure SetImages(AValue: TCustomImageList);
    function RunningOrAborting: Boolean;
    function HistogramFor(AId: Integer; AWithData: Boolean): TStrataHistogram;
    procedure SelectHistogram(AId: Integer);
    procedure lbHistogramDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure RefreshHistogramList;
    procedure ShowHistogram(AId: Integer; AQuiet: Boolean = False);
    procedure FillH1Setup(AId: Integer);
    procedure ApplyStoredSpectra;
    procedure RefreshResults;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start;
    procedure UpdateState(AOpen, AReady, ARunning: Boolean);
    procedure ShowLog;
    procedure AppendLog(ALines: TStrings);
    procedure LivePoll;
    function CurrentHistogramId: Integer;
    procedure EngineStarting;
    procedure EngineStarted;
    procedure EngineStopped;
    procedure RunFinished;
    procedure WriteViewerSetup(const AMacro, AFolder, ABase: String);
    function DocumentCaption: String;

    function MayReplaceConfig: Boolean;
    function OpenConfigFile(const AFileName: String; AAskFirst: Boolean = True): Boolean;
    function ImportMacro(const AFileName, ADocument: String; AAskFirst: Boolean = True): Boolean;
    function ConfigAsMacro: String;
    function ConfigFileName: String;
    property Engine: TStrataEngine read FEngine write FEngine;
    property App: TStrataApp read FApp write FApp;
    property ThreadsBox: TBCTrackbarUpdown read FThreads write FThreads;
    property EventsBox: TBCTrackbarUpdown read FEvents write FEvents;
    property Images: TCustomImageList write SetImages;
    property OnStatus: TStrataNotify read FOnStatus write FOnStatus;
    property OnLog: TStrataNotify read FOnLog write FOnLog;
    property OnStage: TStrataNotify read FOnStage write FOnStage;
    property OnStateChanged: TNotifyEvent read FOnStateChanged write FOnStateChanged;
    property OnKernelBuilt: TNotifyEvent read FOnKernelBuilt write FOnKernelBuilt;
    property OnDocumentChanged: TNotifyEvent read FOnDocumentChanged write FOnDocumentChanged;
    property OnRunStarting: TNotifyEvent read FOnRunStarting write FOnRunStarting;
    // Asked before another configuration replaces this one
    property OnNewDocument: TStrataQuery read FOnNewDocument write FOnNewDocument;
  end;

implementation

{$R *.lfm}

uses
  Math, uStrataMacro;

const
  // The steppers EFieldSetup knows, in its own numbering
  kEFieldSteppers: array[0..5] of record
    Number: Integer;
    Name: String;
  end = ((Number: 4; Name: 'Classical RK4 (default)'),
         (Number: 0; Name: 'Explicit Euler'),
         (Number: 1; Name: 'Implicit Euler'),
         (Number: 2; Name: 'Simple Runge'),
         (Number: 3; Name: 'Simple Heum'),
         (Number: 5; Name: 'Cash-Karp RKF 4/5'));

  // The steppers BFieldSetup knows
  kFieldSteppers: array[0..16] of record
    Number: Integer;
    Name: String;
  end = ((Number: 17; Name: 'Dormand-Prince 7(4/5) (default)'),
         (Number:  0; Name: 'Explicit Euler'),
         (Number:  1; Name: 'Implicit Euler'),
         (Number:  2; Name: 'Simple Runge'),
         (Number:  3; Name: 'Simple Heum'),
         (Number:  4; Name: 'Classical RK4'),
         (Number:  5; Name: 'Helix explicit Euler'),
         (Number:  6; Name: 'Helix implicit Euler'),
         (Number:  7; Name: 'Helix simple Runge'),
         (Number:  8; Name: 'Cash-Karp RKF45'),
         (Number:  9; Name: 'RK G3'),
         (Number: 10; Name: 'Exact helix'),
         (Number: 11; Name: 'Helix mixed'),
         (Number: 12; Name: 'Constant RK4'),
         (Number: 13; Name: 'Nystrom RK4'),
         (Number: 14; Name: 'Bogacki-Shampine 23'),
         (Number: 15; Name: 'Bogacki-Shampine 45'));

  // Columns of the layer grid
  colLayerIndex = 0;
  colLayerThickness = 1;
  colLayerMaterial = 2;
  colLayerDensity = 3;

  colDmgMaterial = 0;
  colDmgEd = 1;
  colDmgB = 2;
  colDmgC = 3;

  colVoxIndex = 0;
  colVoxSizeX = 1;
  colVoxSizeY = 2;
  colVoxSizeZ = 3;
  colVoxPosX = 4;
  colVoxPosY = 5;
  colVoxPosZ = 6;

// The backend reports thicknesses in millimetres
function LengthFactor(const AUnit: String): Double;
begin
  Result := StrataUnitFactor(sqLength, AUnit);
end;

procedure ReadableLength(AMillimetres: Double; out AValue: Double; out AUnit: String);
begin
  if AMillimetres = 0 then
  begin
    AValue := 0;
    AUnit := 'um';
  end
  else if Abs(AMillimetres) < 1e-3 then
  begin
    AValue := AMillimetres*1e6;
    AUnit := 'nm';
  end
  else if Abs(AMillimetres) < 1 then
  begin
    AValue := AMillimetres*1e3;
    AUnit := 'um';
  end
  else if Abs(AMillimetres) < 100 then
  begin
    AValue := AMillimetres;
    AUnit := 'mm';
  end
  else
  begin
    AValue := AMillimetres/10;
    AUnit := 'cm';
  end;
end;

function RowLengthUnit(const ACurrentZ: String; AMillimetres: Double): String;
var
  v: Double;
  u: String;
begin
  if StrataParseQuantity(ACurrentZ, ufLength, v, u) and (LengthFactor(u) > 0) then
    Result := u
  else
    ReadableLength(AMillimetres, v, Result);
end;

function LengthCellText(const ACurrent: String; AMillimetres: Double): String;
var
  shown: Double;
  units: String;
begin
  if StrataParseQuantity(ACurrent, ufLength, shown, units) and (LengthFactor(units) > 0) then
    Result := StrataQuantityText(AMillimetres/LengthFactor(units), units)
  else
  begin
    ReadableLength(AMillimetres, shown, units);
    Result := StrataQuantityText(shown, units);
  end;
end;

{ TPanelsFrame }

constructor TPanelsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfig := TStrataConfig.Create;
  FMaterialNames := TStringList.Create;
  FMaterialNames.Sorted := True;
  FMaterialNames.Duplicates := dupIgnore;
  FDefinedMaterials := TStringList.Create;
  FElementNames := TStringList.Create;
  FH1Units := TStringList.Create;
  FH1Fcns := TStringList.Create;
  FH1Commands := TStringList.Create;
end;

destructor TPanelsFrame.Destroy;
begin
  FreeAndNil(FConfig);
  FreeAndNil(FMaterialNames);
  FreeAndNil(FDefinedMaterials);
  FreeAndNil(FElementNames);
  FreeAndNil(FH1Units);
  FreeAndNil(FH1Fcns);
  FreeAndNil(FH1Commands);
  inherited Destroy;
end;

procedure TPanelsFrame.DoStatus(const AText: String);
begin
  if Assigned(FOnStatus) then FOnStatus(AText);
end;

procedure TPanelsFrame.DoLog(const AText: String);
begin
  if Assigned(FOnLog) then FOnLog(AText);
end;

procedure TPanelsFrame.DoStage(const AText: String);
begin
  if Assigned(FOnStage) then FOnStage(AText);
end;

procedure TPanelsFrame.DoStateChanged;
begin
  if Assigned(FOnStateChanged) then FOnStateChanged(Self);
end;

procedure TPanelsFrame.DoDocumentChanged;
begin
  if Assigned(FOnDocumentChanged) then FOnDocumentChanged(Self);
end;

procedure TPanelsFrame.DoRunStarting;
begin
  if Assigned(FOnRunStarting) then FOnRunStarting(Self);
end;

// Once the window has handed over the engine, the application and the boxes
procedure TPanelsFrame.Start;
var
  i: Integer;
begin
  sgLayers.ColCount := 4;
  sgLayers.FixedRows := 1;
  sgLayers.Cells[colLayerIndex, 0] := 'Layer';
  sgLayers.Cells[colLayerThickness, 0] := 'Thickness';
  sgLayers.Cells[colLayerDensity, 0] := 'Density';
  sgLayers.Cells[colLayerMaterial, 0] := 'Material';

  sgVoxelDefs.ColCount := 7;
  sgVoxelDefs.FixedRows := 1;
  sgVoxelDefs.RowCount := 1;
  sgVoxelDefs.Cells[colVoxIndex, 0] := 'Volume';
  sgVoxelDefs.Cells[colVoxSizeX, 0] := 'Size X';
  sgVoxelDefs.Cells[colVoxSizeY, 0] := 'Size Y';
  sgVoxelDefs.Cells[colVoxSizeZ, 0] := 'Size Z';
  sgVoxelDefs.Cells[colVoxPosX, 0] := 'Position X';
  sgVoxelDefs.Cells[colVoxPosY, 0] := 'Position Y';
  sgVoxelDefs.Cells[colVoxPosZ, 0] := 'Position Z';
  sgVoxelDefs.ColWidths[colVoxIndex] := 60;
  ResizeLayerGrid(1);

  sgConstituents.ColCount := 3;
  sgConstituents.FixedRows := 1;
  ResizeConstituentGrid(2);
  UpdateConstituentSum;
  FillStepperList;
  FillEStepperList;
  lbDefinedMaterials.Style := lbOwnerDrawFixed;
  lbDefinedMaterials.OnDrawItem := @lbDefinedMaterialsDrawItem;
  lbHistogram.Style := lbOwnerDrawFixed;
  lbHistogram.OnDrawItem := @lbHistogramDrawItem;

  sgSummary.ColCount := 2;
  sgSummary.FixedRows := 1;
  sgSummary.Cells[0, 0] := 'Quantity';
  sgSummary.Cells[1, 0] := 'Value';

  sgVoxels.ColCount := 5;
  sgVoxels.FixedRows := 1;
  sgVoxels.Cells[0, 0] := 'Voxel';
  sgVoxels.Cells[1, 0] := 'Edep (MeV)';
  sgVoxels.Cells[2, 0] := 'Fraction (%)';
  sgVoxels.Cells[3, 0] := 'Dose (Gy)';
  sgVoxels.Cells[4, 0] := 'Mass (g)';

  PopulateCatalogues;

  FConfigFile := '';
  MarkConfigSaved;
end;

// The images live with the window, so the frame is handed them
procedure TPanelsFrame.SetImages(AValue: TCustomImageList);
begin
  PanelsActions.Images := AValue;
  btnH1Apply.Images := AValue;
  btnH1Off.Images := AValue;
  btnRefreshHistograms.Images := AValue;
  btnExportHistogram.Images := AValue;
  btnApplyGeometry.Images := AValue;
  btnWorldMaterial.Images := AValue;
  btnApplyBeam.Images := AValue;
  btnSelectIon.Images := AValue;
  btnFieldApply.Images := AValue;
  btnEFieldApply.Images := AValue;
  btnApplyPhysics.Images := AValue;
  btnMatRefresh.Images := AValue;
  btnMatPrint.Images := AValue;
  btnMatAddRow.Images := AValue;
  btnMatDelRow.Images := AValue;
  btnMatCreate.Images := AValue;
  btnUseLastSeeds.Images := AValue;
  btnSendCommand.Images := AValue;
  btnRunMacro.Images := AValue;
  btnClearLog.Images := AValue;
  btnSaveLog.Images := AValue;
end;

procedure TPanelsFrame.UpdateState(AOpen, AReady, ARunning: Boolean);
var
  open, ready, running, ion, magnetic, electric: Boolean;
begin
  open := AOpen;
  ready := AReady;
  running := ARunning;
  ion := IonSelected and (not running);

  actInitialize.Enabled := open and (not ready) and (not running);
  // Starting again, or reading a configuration or a macro, rewrites the pages
  actNewConfig.Enabled := not running;
  actImportMacro.Enabled := not running;

  actBeamOn.Enabled := ready and (not running);

  // Geometry
  // The grid keeps working after the kernel is built
  actApplyGeometry.Enabled := open and (not running);
  sgLayers.Enabled := not running;
  actSelectMaterial.Enabled := open and (not running);
  seSizeYZ.Enabled := (not ready) and (not running);
  // A material carries its temperature, so changing it rebuilds them, which
  // the geometry can only do before it is built
  seTemperature.Enabled := (not ready) and (not running);
  seLayerCount.Enabled := (not ready) and (not running);
  // Test volumes are placed by DetectorConstruction, so PreInit only
  seVoxelCount.Enabled := (not ready) and (not running);
  sgVoxelDefs.Enabled := (not ready) and (not running);

  // Materials
  edMatName.Enabled := not running;
  seMatDensity.Enabled := not running;

  // /strata/BField/ is only available in Idle, because BFieldSetup is created
  // in ConstructSDandField, so there is nothing to send before Initialise
  magnetic := ready and (not running) and (not ElectricFieldWanted);
  electric := ready and (not running) and (not MagneticFieldWanted);
  // The detector is independent of the fields and of the kernel state: its
  // commands are legal before and after Initialise alike
  // The de-excitation switches are read when the physics list is built and
  // standard_opt4 never looks again, so after Initialize they would be
  // accepted and ignored.  They close rather than lie about that.
  chkEmFluo.Enabled := (not ready) and (not running);
  chkEmAuger.Enabled := (not ready) and (not running);
  chkEmAugerCascade.Enabled := (not ready) and (not running);
  chkEmPixe.Enabled := (not ready) and (not running);
  chkEmDeexIgnoreCut.Enabled := (not ready) and (not running);
  // The cuts are not like that: Geant4 recomputes them for the next run
  gbDeexcitation.Caption := 'Atomic de-excitation';
  if ready then
    gbDeexcitation.Caption := 'Atomic de-excitation (fixed once the tables are built)';
  chkCut.Enabled := not running;
  seCut.Enabled := chkCut.Checked and (not running);
  // Named one by one rather than through ParticleCutEdit
  seCutGamma.Enabled := chkCut.Checked and (not running);
  seCutElectron.Enabled := chkCut.Checked and (not running);
  seCutPositron.Enabled := chkCut.Checked and (not running);
  seCutProton.Enabled := chkCut.Checked and (not running);
  chkStepMax.Enabled := ready and (not running);
  seStepMax.Enabled := chkStepMax.Checked and ready and (not running);
  cbKillSecondaries.Enabled := ready and (not running);

  chkRBS.Enabled := not running;
  seRBSAngle.Enabled := chkRBS.Checked and (not running);
  seRBSSolidAngle.Enabled := chkRBS.Checked and (not running);
  seRBSResolution.Enabled := chkRBS.Checked and (not running);
  seRBSTilt.Enabled := chkRBS.Checked and (not running);
  chkRBSScreening.Enabled := chkRBS.Checked and (not running);
  chkDamage.Enabled := not running;
  sgDamage.Enabled := chkDamage.Checked and (not running);

  seFieldBx.Enabled := magnetic;
  seFieldBy.Enabled := magnetic;
  seFieldBz.Enabled := magnetic;
  seFieldMinStep.Enabled := magnetic;
  cbFieldStepper.Enabled := magnetic;
  actApplyField.Enabled := magnetic;

  // The same for the electric field, and never both: see MagneticFieldWanted
  seEFieldEx.Enabled := electric;
  seEFieldEy.Enabled := electric;
  seEFieldEz.Enabled := electric;
  seEFieldMinStep.Enabled := electric;
  cbEFieldStepper.Enabled := electric;
  actApplyEField.Enabled := electric;
  if ElectricFieldWanted then
    gbField.Caption := 'Magnetic field (an electric field is set)'
  else
    gbField.Caption := 'Magnetic field';
  if MagneticFieldWanted then
    gbEField.Caption := 'Electric field (a magnetic field is set)'
  else
    gbEField.Caption := 'Electric field';
  sgConstituents.Enabled := not running;
  actAddElement.Enabled := not running;
  actSelectElement.Enabled := not running;
  actRemoveElement.Enabled := not running;
  actCreateMaterial.Enabled := open and (not running);
  actPrintMaterials.Enabled := open and (not running);
  actRefreshMaterials.Enabled := open and (not running);

  // Beam
  // The particle list is read out of the particle table, which Geant4 only
  // fills when the physics is built, so none of this is offered before then
  actApplyBeam.Enabled := ready and (not running);
  cbParticle.Enabled := ready and (not running);
  seEnergy.Enabled := ready and (not running);
  seBeamRadius.Enabled := ready and (not running);
  seBeamAngle.Enabled := ready and (not running);
  seIonZ.Enabled := ion and ready;
  seIonA.Enabled := seIonZ.Enabled;
  seIonQ.Enabled := seIonZ.Enabled;
  actSelectIon.Enabled := seIonZ.Enabled;

  // Where the results go is applied before every run, so it stays open
  edOutputBase.Enabled := not running;

  // The hand-written commands are sent when the pages are applied, so they
  // are typed before a run, not during one
  memCmdGeometry.Enabled := not running;
  memCmdPreInit.Enabled := not running;
  memCmdBeam.Enabled := not running;
  memCmdRun.Enabled := not running;

  // Track files: a name is only worth typing for a file that is wanted
  chkSavePrimaries.Enabled := not running;
  chkSaveCascades.Enabled := not running;
  edPrimariesName.Enabled := chkSavePrimaries.Checked and (not running);
  edCascadesName.Enabled := chkSaveCascades.Checked and (not running);

  // Physics
  actApplyPhysics.Enabled := open and (not ready) and (not running) and (not FPhysicsApplied);
  cbPhysicsList.Enabled := (not ready) and (not running) and (not FPhysicsApplied);
  clbOptionalPhysics.Enabled := cbPhysicsList.Enabled;
  if FPhysicsApplied then
    gbOptionalPhysics.Caption := 'Optional physics (applied, a new session is '
                                 + 'needed to change it)'
  else
    gbOptionalPhysics.Caption := 'Optional physics';

  // The generator is fixed once the kernel is built, but the seeds can be
  // changed at any time
  cbRndEngine.Enabled := (not ready) and (not running);
  chkRandomize.Enabled := not running;
  seRndSeed1.Enabled := (not running) and (not chkRandomize.Checked);
  seRndSeed2.Enabled := seRndSeed1.Enabled;
  btnUseLastSeeds.Enabled := open and (not running);

  // Spectra/histograms
  lbHistogram.Enabled := ready;
  chkOnlyActiveHistograms.Enabled := ready and (not running);
  seH1Bins.Enabled := ready and (not running);
  seH1Min.Enabled := ready and (not running);
  seH1Max.Enabled := ready and (not running);
  chbH1Log.Enabled := ready and (not running);
  actActivateHistogram.Enabled := ready and (not running);
  actDeactivateHistogram.Enabled := ready and (not running);
  actRefreshHistograms.Enabled := ready and (not running);
  actExportHistogram.Enabled := ready and (not running);

  // The command box
  actSendCommand.Enabled := open and (not running);
  edCommand.Enabled := open and (not running);
  actRunMacro.Enabled := open and (not running);

  // What the button for Apply geometry is called
  if ready then
  begin
    actApplyGeometry.Caption := 'Apply materials';
    actApplyGeometry.Hint := 'Apply materials|Update materials in current geometry';
  end
  else
  begin
    actApplyGeometry.Caption := 'Apply geometry';
    actApplyGeometry.Hint := 'Apply geometry|Apply current geometry';
  end;
end;

procedure TPanelsFrame.ShowLog;
begin
  pcMain.ActivePage := tabLog;
end;

procedure TPanelsFrame.AppendLog(ALines: TStrings);
const
  MaxMemoLines = 20000;
begin
  mLog.Lines.BeginUpdate;
  try
    mLog.Lines.AddStrings(ALines);
    // Keep the memo bounded: Geant4 emits tens of thousands of lines at initialisation
    while mLog.Lines.Count > MaxMemoLines do
      mLog.Lines.Delete(0);
  finally
    mLog.Lines.EndUpdate;
  end;
  mLog.SelStart := Length(mLog.Text);
end;

// The spectrum being watched, as far as the run has got
procedure TPanelsFrame.LivePoll;
begin
  if pcMain.ActivePage <> tabHistograms then Exit;
  Inc(FLivePolls);
  if FLivePolls >= 2 then
  begin
    FLivePolls := 0;
    ShowHistogram(CurrentHistogramId, True);
  end;
end;

procedure TPanelsFrame.EngineStarting;
begin
  FPhysicsApplied := False;
end;

procedure TPanelsFrame.EngineStarted;
begin
  RefreshMaterialCatalogue;
  PopulateCatalogues;
end;

// The next start sends the physics again
procedure TPanelsFrame.EngineStopped;
begin
  FPhysicsApplied := False;
  RefreshHistogramList;
end;

procedure TPanelsFrame.RunFinished;
begin
  DoStage('Refreshing the results page');
  RefreshResults;
  DoStage('Refreshing the histogram list');
  RefreshHistogramList;
  DoStage('Plotting histogram ' + IntToStr(CurrentHistogramId));
  ShowHistogram(CurrentHistogramId);
  DoStage('');
end;

// The set-up as a macro, with its results sent somewhere else
procedure TPanelsFrame.WriteViewerSetup(const AMacro, AFolder, ABase: String);
var
  keptFolder, keptBase: String;
begin
  ConfigFromWidgets;
  keptFolder := FConfig.OutputFolder;
  keptBase := FConfig.OutputBase;
  FConfig.OutputFolder := AFolder;
  FConfig.OutputBase := ABase;
  try
    FConfig.SaveToMacro(AMacro, False);
  finally
    FConfig.OutputFolder := keptFolder;
    FConfig.OutputBase := keptBase;
  end;
end;

function TPanelsFrame.DocumentCaption: String;
begin
  if FConfigFile = '' then
    Result := 'Untitled'
  else
    Result := ExtractFileName(FConfigFile);
  if ConfigModified then Result := '*' + Result;
end;

// Puts a selection back after the list behind it has been refilled
function TPanelsFrame.RestoreSelection(ACombo: TComboBox; const AWanted, ADefault: String): Boolean;

  function TryFill(const AValue: String): Boolean;
  var
    i: Integer;
  begin
    Result := False;
    if AValue = '' then Exit;
    i := ACombo.Items.IndexOf(AValue);
    if i < 0 then Exit;
    ACombo.ItemIndex := i;
    Result := True;
  end;

begin
  Result := TryFill(AWanted) or TryFill(ADefault);
end;

procedure TPanelsFrame.PopulateCatalogues;
var
  base: TStringList;
  physics: String;
begin
  if cbRndEngine.Items.Count = 0 then
  begin
    // The names RandomSetup accepts, in its order; the first is the default
    cbRndEngine.Items.CommaText := 'ranecu,mixmax,mtwist,ranlux64,ranluxpp,james';
    RestoreSelection(cbRndEngine, '', 'ranecu');
  end;

  base := TStringList.Create;
  try
    physics := cbPhysicsList.Text;
    FEngine.FillPhysicsNames(base, clbOptionalPhysics.Items);
    cbPhysicsList.Items.Assign(base);
    RestoreSelection(cbPhysicsList, physics, 'local');
  finally
    base.Free;
  end;

  // The names exist only now, so anything a configuration asked for before
  // the session was open is ticked here -- the same reason the particle is
  // restored after the particle table is built
  ShowOptionalPhysics;
end;

// Ticks whatever the configuration asks for, as far as the names allow
procedure TPanelsFrame.ShowOptionalPhysics;
var
  i: Integer;
begin
  for i := 0 to clbOptionalPhysics.Items.Count - 1 do
    clbOptionalPhysics.Checked[i] :=
      FConfig.OptionalPhysics.IndexOf(clbOptionalPhysics.Items[i]) >= 0;
end;

procedure TPanelsFrame.ResizeLayerGrid(ACount: Integer);
var
  r: Integer;
begin
  if ACount < 1 then ACount := 1;
  sgLayers.RowCount := ACount + 1;
  for r := 1 to ACount do
  begin
    sgLayers.Cells[colLayerIndex, r] := IntToStr(r - 1);
    if sgLayers.Cells[colLayerThickness, r] = '' then
      sgLayers.Cells[colLayerThickness, r] := '20 um';
    // The density is left empty on purpose: empty means the material's own
    if sgLayers.Cells[colLayerMaterial, r] = '' then
      sgLayers.Cells[colLayerMaterial, r] := 'G4_SILICON_DIOXIDE';
  end;
end;

procedure TPanelsFrame.seLayerCountChange(Sender: TObject);
begin
  ResizeLayerGrid(seLayerCount.Value);
end;

procedure TPanelsFrame.SetVoxelCount(ACount: Integer);
var
  r: Integer;
begin
  if ACount < 0 then ACount := 0;
  sgVoxelDefs.RowCount := ACount + 1;
  for r := 1 to ACount do
  begin
    sgVoxelDefs.Cells[colVoxIndex, r] := IntToStr(r - 1);
    if sgVoxelDefs.Cells[colVoxSizeX, r] = '' then
      sgVoxelDefs.Cells[colVoxSizeX, r] := '1 um';
    if sgVoxelDefs.Cells[colVoxSizeY, r] = '' then
      sgVoxelDefs.Cells[colVoxSizeY, r] := '1 um';
    if sgVoxelDefs.Cells[colVoxSizeZ, r] = '' then
      sgVoxelDefs.Cells[colVoxSizeZ, r] := '1 um';
    if sgVoxelDefs.Cells[colVoxPosX, r] = '' then
      sgVoxelDefs.Cells[colVoxPosX, r] := '0 um';
    if sgVoxelDefs.Cells[colVoxPosY, r] = '' then
      sgVoxelDefs.Cells[colVoxPosY, r] := '0 um';
    if sgVoxelDefs.Cells[colVoxPosZ, r] = '' then
      sgVoxelDefs.Cells[colVoxPosZ, r] := '0 um';
  end;
end;

procedure TPanelsFrame.seVoxelCountChange(Sender: TObject);
begin
  SetVoxelCount(seVoxelCount.Value);
end;

procedure TPanelsFrame.sgVoxelDefsSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
begin
  if aRow < 1 then Exit;
  // Every column but the index holds a length with its unit
  if aCol <> colVoxIndex then
    Editor := SciEditorFor(FVoxelEditor, Self, ufLength);
end;

// Reads back the volumes the kernel actually built
procedure TPanelsFrame.RefreshVoxelGrid;
var
  vox: TStrataVoxelArray;
  i: Integer;
  su, pu: String;
  sf, pf: Double;

  function Biggest(a, b, c: Double): Double;
  begin
    Result := Abs(a);
    if Abs(b) > Result then Result := Abs(b);
    if Abs(c) > Result then Result := Abs(c);
  end;

begin
  vox := FEngine.Voxels;
  seVoxelCount.OnChange := nil;
  try
    seVoxelCount.Value := Length(vox);
    SetVoxelCount(Length(vox));
  finally
    seVoxelCount.OnChange := @seVoxelCountChange;
  end;

  for i := 0 to High(vox) do
  begin
    su := RowLengthUnit(sgVoxelDefs.Cells[colVoxSizeZ, i + 1], Biggest(vox[i].SizeX, vox[i].SizeY, vox[i].SizeZ));
    pu := RowLengthUnit(sgVoxelDefs.Cells[colVoxPosZ, i + 1], Biggest(vox[i].PosX, vox[i].PosY, vox[i].PosZ));
    sf := LengthFactor(su);
    pf := LengthFactor(pu);
    sgVoxelDefs.Cells[colVoxIndex, i + 1] := IntToStr(i);
    sgVoxelDefs.Cells[colVoxSizeX, i + 1] := StrataQuantityText(vox[i].SizeX/sf, su);
    sgVoxelDefs.Cells[colVoxSizeY, i + 1] := StrataQuantityText(vox[i].SizeY/sf, su);
    sgVoxelDefs.Cells[colVoxSizeZ, i + 1] := StrataQuantityText(vox[i].SizeZ/sf, su);
    sgVoxelDefs.Cells[colVoxPosX, i + 1] := StrataQuantityText(vox[i].PosX/pf, pu);
    sgVoxelDefs.Cells[colVoxPosY, i + 1] := StrataQuantityText(vox[i].PosY/pf, pu);
    sgVoxelDefs.Cells[colVoxPosZ, i + 1] := StrataQuantityText(vox[i].PosZ/pf, pu);
  end;
end;

procedure TPanelsFrame.RefreshGeometryGrid;
var
  layers: TStrataLayerArray;
  i: Integer;
  sizeX, sizeYZ: Double;
begin
  layers := FEngine.Layers;
  if Length(layers) = 0 then Exit;

  seLayerCount.OnChange := nil;
  try
    seLayerCount.Value := Length(layers);
    ResizeLayerGrid(Length(layers));
  finally
    seLayerCount.OnChange := @seLayerCountChange;
  end;

  for i := 0 to High(layers) do
  begin
    sgLayers.Cells[colLayerIndex, i + 1] := IntToStr(i);
    sgLayers.Cells[colLayerThickness, i + 1] := LengthCellText(sgLayers.Cells[colLayerThickness, i + 1], layers[i].Thickness);
    sgLayers.Cells[colLayerMaterial, i + 1] := layers[i].Material;
  end;

  FEngine.WorldSize(sizeX, sizeYZ);
  DoStatus(Format('Target %d layer(s), world %.1f x %.1f mm, %s', [Length(layers), sizeX, sizeYZ, FEngine.WorldMaterial]));
end;

function TPanelsFrame.IonSelected: Boolean;
begin
  Result := SameText(Trim(cbParticle.Text), 'ion');
end;

procedure TPanelsFrame.cbParticleChange(Sender: TObject);
begin
  DoStateChanged;
end;

// Sends one block of hand-written commands
procedure TPanelsFrame.SendStageCommands(AStage: TStrataStage);
var
  i, refused: Integer;
  line: String;
  lines: TStrings;
begin
  refused := 0;
  lines := CommandEditor(AStage).Lines;
  for i := 0 to lines.Count - 1 do
  begin
    line := Trim(lines[i]);
    if (line = '') or (line[1] = '#') then Continue;
    try
      FEngine.Apply(line);
    except
      on E: Exception do
      begin
        Inc(refused);
        DoLog(Format('%s: "%s" was refused, %s', [StrataStageCaption[AStage], line, E.Message]));
      end;
    end;
  end;
  if refused > 0 then
    DoStatus(Format('%d command(s) under "%s" were refused, see the Log tab',
                  [refused, StrataStageCaption[AStage]]));
end;

// The editor each block of hand-written commands is typed into
function TPanelsFrame.CommandEditor(AStage: TStrataStage): TMemo;
begin
  case AStage of
    stGeometry: Result := memCmdGeometry;
    stPreInit: Result := memCmdPreInit;
    stBeam: Result := memCmdBeam;
  else
    Result := memCmdRun;
  end;
end;

procedure TPanelsFrame.ConfigFromWidgets;
var
  i, n: Integer;
  stage: TStrataStage;
begin
  FConfig.Threads := FThreads.Value;

  // Kelvin whatever the box was typed in; Geant4 knows no other temperature
  FConfig.Temperature := ReadInUnit(seTemperature, 'K', 293.15);
  if not ReadAsTyped(seSizeYZ, sqLength, FConfig.SizeYZ, FConfig.SizeUnit) then
    FConfig.SizeYZ := 0;
  FConfig.WorldMaterial := edWorldMaterial.Caption;
  FConfig.SetLayerCount(seLayerCount.Value);
  for i := 0 to High(FConfig.Layers) do
  begin
    if not CellAsTyped(sgLayers.Cells[colLayerThickness, i + 1], ufLength,
         sqLength, FConfig.Layers[i].Thickness, FConfig.Layers[i].Units) then
      FConfig.Layers[i].Thickness := 0;
    FConfig.Layers[i].Material := Trim(sgLayers.Cells[colLayerMaterial, i + 1]);
    // An empty or unreadable density cell is no override
    if not CellAsTyped(sgLayers.Cells[colLayerDensity, i + 1], ufDensity,
                       sqDensity, FConfig.Layers[i].Density, FConfig.Layers[i].DensityUnit) then
      FConfig.Layers[i].Density := 0;
  end;

  SetLength(FConfig.Voxels, 0);
  for i := 0 to seVoxelCount.Value - 1 do
  begin
    FConfig.AddVoxel;
    ReadVoxelTriple(i + 1, colVoxSizeX, colVoxSizeY, colVoxSizeZ,
                    FConfig.Voxels[i].SizeX, FConfig.Voxels[i].SizeY,
                    FConfig.Voxels[i].SizeZ, FConfig.Voxels[i].SizeUnit);
    ReadVoxelTriple(i + 1, colVoxPosX, colVoxPosY, colVoxPosZ,
                    FConfig.Voxels[i].PosX, FConfig.Voxels[i].PosY,
                    FConfig.Voxels[i].PosZ, FConfig.Voxels[i].PosUnit);
  end;

  FConfig.SavePrimaries := chkSavePrimaries.Checked;
  FConfig.SaveCascades := chkSaveCascades.Checked;
  FConfig.PrimariesName := Trim(edPrimariesName.Text);
  FConfig.CascadesName := Trim(edCascadesName.Text);

  FConfig.RandomEngine := Trim(cbRndEngine.Text);
  FConfig.RandomRandomize := chkRandomize.Checked;
  FConfig.RandomSeed1 := seRndSeed1.Value;
  FConfig.RandomSeed2 := seRndSeed2.Value;

  // The z box decides the unit for all three, as /strata/BField/setValue
  // takes only one
  if ReadAsTyped(seFieldBz, sqField, FConfig.FieldBz, FConfig.FieldUnit) then
  begin
    FConfig.FieldBx := ReadRef(seFieldBx, sqField, 0);
    FConfig.FieldBy := ReadRef(seFieldBy, sqField, 0);
    FConfig.FieldOn := (FConfig.FieldBx <> 0) or (FConfig.FieldBy <> 0) or (FConfig.FieldBz <> 0);
  end
  else
    FConfig.FieldOn := False;

  if not ReadAsTyped(seFieldMinStep, sqLength, FConfig.FieldMinStep, FConfig.FieldMinStepUnit) then
    FConfig.FieldMinStep := 1.0;
  FConfig.FieldStepper := CurrentStepper;

  // Likewise for the electric field, and only one of the two can be on
  if ReadAsTyped(seEFieldEz, sqEField, FConfig.EFieldEz, FConfig.EFieldUnit) then
  begin
    FConfig.EFieldEx := ReadRef(seEFieldEx, sqEField, 0);
    FConfig.EFieldEy := ReadRef(seEFieldEy, sqEField, 0);
    FConfig.EFieldOn := (not FConfig.FieldOn)
      and ((FConfig.EFieldEx <> 0) or (FConfig.EFieldEy <> 0) or (FConfig.EFieldEz <> 0));
  end
  else
    FConfig.EFieldOn := False;

  if not ReadAsTyped(seEFieldMinStep, sqLength, FConfig.EFieldMinStep, FConfig.EFieldMinStepUnit) then
    FConfig.EFieldMinStep := 1.0;
  FConfig.EFieldStepper := CurrentEStepper;

  // The detector
  FConfig.RBSOn := chkRBS.Checked;
  FConfig.DamageOn := chkDamage.Checked;
  DamageFromGrid;
  FConfig.RBSAngle := ReadRef(seRBSAngle, sqAngle, 165);
  if not ReadAsTyped(seRBSSolidAngle, sqSolidAngle, FConfig.RBSSolidAngle,
                     FConfig.RBSSolidAngleUnit) then
    FConfig.RBSSolidAngle := 1;
  if not ReadAsTyped(seRBSResolution, sqEnergy, FConfig.RBSResolution,
                     FConfig.RBSResolutionUnit) then
    FConfig.RBSResolution := 0;
  FConfig.RBSTilt := ReadRef(seRBSTilt, sqAngle, 0);
  FConfig.RBSScreening := chkRBSScreening.Checked;

  FConfig.EmFluo := chkEmFluo.Checked;
  FConfig.EmAuger := chkEmAuger.Checked;
  FConfig.EmAugerCascade := chkEmAugerCascade.Checked;
  FConfig.EmPixe := chkEmPixe.Checked;
  FConfig.EmDeexIgnoreCut := chkEmDeexIgnoreCut.Checked;

  FConfig.CutOn := chkCut.Checked;
  if FConfig.CutOn
     and not ReadAsTyped(seCut, sqLength, FConfig.Cut, FConfig.CutUnit) then
    FConfig.CutOn := False;
  // An empty box is a particle with no cut of its own
  for i := 0 to High(FConfig.ParticleCut) do
    if not ReadAsTyped(ParticleCutEdit(i), sqLength,
                       FConfig.ParticleCut[i], FConfig.ParticleCutUnit[i]) then
      FConfig.ParticleCutUnit[i] := '';

  FConfig.StepMaxOn := chkStepMax.Checked;
  if FConfig.StepMaxOn
     and not ReadAsTyped(seStepMax, sqLength, FConfig.StepMax, FConfig.StepMaxUnit) then
    FConfig.StepMaxOn := False;
  FConfig.KillSecondaries := cbKillSecondaries.ItemIndex;
  if FConfig.KillSecondaries < 0 then FConfig.KillSecondaries := 0;

  FConfig.Particle := Trim(cbParticle.Text);
  FConfig.IonZ := seIonZ.Value;
  FConfig.IonA := seIonA.Value;
  FConfig.IonQ := seIonQ.Value;
  if not ReadAsTyped(seEnergy, sqEnergy, FConfig.Energy, FConfig.EnergyUnit) then
    FConfig.Energy := 0;
  FConfig.BeamRadius := ReadRef(seBeamRadius, sqLength, 0);
  FConfig.BeamAngle := ReadRef(seBeamAngle, sqAngle, 0);
  FConfig.Events := FEvents.Value;

  FConfig.PhysicsList := cbPhysicsList.Text;
  // Only when the names are known.  The list is filled from the backend by
  // PopulateCatalogues, so before a session is open it is empty -- and
  // rebuilding from an empty list would throw away what a configuration
  // just loaded, which is what used to happen on every keystroke, since
  // ConfigModified comes through here.
  if clbOptionalPhysics.Items.Count > 0 then
  begin
    FConfig.OptionalPhysics.Clear;
    for i := 0 to clbOptionalPhysics.Items.Count - 1 do
      if clbOptionalPhysics.Checked[i] then
        FConfig.OptionalPhysics.Add(clbOptionalPhysics.Items[i]);
  end;

  for stage := Low(TStrataStage) to High(TStrataStage) do
    FConfig.Commands[stage].Text := CommandEditor(stage).Lines.Text;

  // The spectra in force are the /analysis/h1/set commands that were sent
  SetLength(FConfig.Spectra, 0);
  for i := 0 to FH1Commands.Count - 1 do
  begin
    if FH1Commands.ValueFromIndex[i] = '' then Continue;
    n := FConfig.AddSpectrum;
    with TStringList.Create do
    try
      Delimiter := ' ';
      DelimitedText := FH1Commands.ValueFromIndex[i];
      // /analysis/h1/set <id> <bins> <min> <max> [unit]
      if Count > 4 then
      begin
        FConfig.Spectra[n].Id := StrToIntDef(Strings[1], 0);
        FConfig.Spectra[n].Bins := StrToIntDef(Strings[2], 100);
        FConfig.Spectra[n].Min := StrataTextToNum(Strings[3], 0);
        FConfig.Spectra[n].Max := StrataTextToNum(Strings[4], 1);
        if Count > 5 then FConfig.Spectra[n].Units := Strings[5];
        if Count > 6 then FConfig.Spectra[n].Fcn := Strings[6];
        if SameText(FConfig.Spectra[n].Units, 'none') then FConfig.Spectra[n].Units := '';
      end;
    finally
      Free;
    end;
  end;

  FConfig.OutputFolder := OutputFolder;
  FConfig.OutputBase := Trim(edOutputBase.Text);
end;

procedure TPanelsFrame.ConfigToWidgets;
var
  i: Integer;
  stage: TStrataStage;
begin
  FThreads.Value := FConfig.Threads;

  SetQuantity(seSizeYZ, FConfig.SizeYZ, FConfig.SizeUnit, 'mm');
  SetQuantity(seTemperature, FConfig.Temperature, 'K', 'K');
  edWorldMaterial.Caption := FConfig.WorldMaterial;
  seLayerCount.OnChange := nil;
  try
    seLayerCount.Value := Length(FConfig.Layers);
    ResizeLayerGrid(Length(FConfig.Layers));
  finally
    seLayerCount.OnChange := @seLayerCountChange;
  end;
  for i := 0 to High(FConfig.Layers) do
  begin
    sgLayers.Cells[colLayerIndex, i + 1] := IntToStr(i);
    sgLayers.Cells[colLayerThickness, i + 1] := StrataQuantityText(FConfig.Layers[i].Thickness, FConfig.Layers[i].Units);
    sgLayers.Cells[colLayerMaterial, i + 1] := FConfig.Layers[i].Material;
    if FConfig.Layers[i].Density > 0 then
      sgLayers.Cells[colLayerDensity, i + 1] := StrataQuantityText(FConfig.Layers[i].Density, FConfig.Layers[i].DensityUnit)
    else
      sgLayers.Cells[colLayerDensity, i + 1] := '';
  end;

  seVoxelCount.OnChange := nil;
  try
    seVoxelCount.Value := Length(FConfig.Voxels);
    SetVoxelCount(Length(FConfig.Voxels));
  finally
    seVoxelCount.OnChange := @seVoxelCountChange;
  end;
  for i := 0 to High(FConfig.Voxels) do
  begin
    sgVoxelDefs.Cells[colVoxIndex, i + 1] := IntToStr(i);
    // The configuration keeps one unit per row, so every cell in it is
    // written with that unit
    sgVoxelDefs.Cells[colVoxSizeX, i + 1] := StrataQuantityText(FConfig.Voxels[i].SizeX, FConfig.Voxels[i].SizeUnit);
    sgVoxelDefs.Cells[colVoxSizeY, i + 1] := StrataQuantityText(FConfig.Voxels[i].SizeY, FConfig.Voxels[i].SizeUnit);
    sgVoxelDefs.Cells[colVoxSizeZ, i + 1] := StrataQuantityText(FConfig.Voxels[i].SizeZ, FConfig.Voxels[i].SizeUnit);
    sgVoxelDefs.Cells[colVoxPosX, i + 1] := StrataQuantityText(FConfig.Voxels[i].PosX, FConfig.Voxels[i].PosUnit);
    sgVoxelDefs.Cells[colVoxPosY, i + 1] := StrataQuantityText(FConfig.Voxels[i].PosY, FConfig.Voxels[i].PosUnit);
    sgVoxelDefs.Cells[colVoxPosZ, i + 1] := StrataQuantityText(FConfig.Voxels[i].PosZ, FConfig.Voxels[i].PosUnit);
  end;

  chkSavePrimaries.Checked := FConfig.SavePrimaries;
  chkSaveCascades.Checked := FConfig.SaveCascades;
  if FConfig.PrimariesName <> '' then
    edPrimariesName.Text := FConfig.PrimariesName;
  if FConfig.CascadesName <> '' then
    edCascadesName.Text := FConfig.CascadesName;

  if cbRndEngine.Items.IndexOf(FConfig.RandomEngine) < 0 then
    cbRndEngine.Items.Add(FConfig.RandomEngine);
  RestoreSelection(cbRndEngine, FConfig.RandomEngine, '');
  chkRandomize.Checked := FConfig.RandomRandomize;
  if (FConfig.RandomSeed1 >= seRndSeed1.MinValue) and (FConfig.RandomSeed1 <= seRndSeed1.MaxValue) then
    seRndSeed1.Value := FConfig.RandomSeed1;
  if (FConfig.RandomSeed2 >= seRndSeed2.MinValue) and (FConfig.RandomSeed2 <= seRndSeed2.MaxValue) then
    seRndSeed2.Value := FConfig.RandomSeed2;

  SetQuantity(seFieldBx, FConfig.FieldBx, FConfig.FieldUnit, 'T');
  SetQuantity(seFieldBy, FConfig.FieldBy, FConfig.FieldUnit, 'T');
  SetQuantity(seFieldBz, FConfig.FieldBz, FConfig.FieldUnit, 'T');
  SetQuantity(seFieldMinStep, FConfig.FieldMinStep, FConfig.FieldMinStepUnit, 'mm');
  SelectStepper(FConfig.FieldStepper);

  SetQuantity(seEFieldEx, FConfig.EFieldEx, FConfig.EFieldUnit, 'kV/m');
  SetQuantity(seEFieldEy, FConfig.EFieldEy, FConfig.EFieldUnit, 'kV/m');
  SetQuantity(seEFieldEz, FConfig.EFieldEz, FConfig.EFieldUnit, 'kV/m');
  SetQuantity(seEFieldMinStep, FConfig.EFieldMinStep, FConfig.EFieldMinStepUnit, 'mm');
  SelectEStepper(FConfig.EFieldStepper);

  if cbParticle.Items.IndexOf(FConfig.Particle) < 0 then
    cbParticle.Items.Add(FConfig.Particle);
  RestoreSelection(cbParticle, FConfig.Particle, '');
  seIonZ.Value := FConfig.IonZ;
  seIonA.Value := FConfig.IonA;
  seIonQ.Value := FConfig.IonQ;
  SetQuantity(seEnergy, FConfig.Energy, FConfig.EnergyUnit, 'MeV');
  chkRBS.Checked := FConfig.RBSOn;
  chkDamage.Checked := FConfig.DamageOn;
  RefreshDamageGrid;
  SetQuantity(seRBSAngle, FConfig.RBSAngle, 'deg', 'deg');
  SetQuantity(seRBSSolidAngle, FConfig.RBSSolidAngle, FConfig.RBSSolidAngleUnit, 'msr');
  SetQuantity(seRBSResolution, FConfig.RBSResolution, FConfig.RBSResolutionUnit, 'keV');
  SetQuantity(seRBSTilt, FConfig.RBSTilt, 'deg', 'deg');
  chkRBSScreening.Checked := FConfig.RBSScreening;

  chkEmFluo.Checked := FConfig.EmFluo;
  chkEmAuger.Checked := FConfig.EmAuger;
  chkEmAugerCascade.Checked := FConfig.EmAugerCascade;
  chkEmPixe.Checked := FConfig.EmPixe;
  chkEmDeexIgnoreCut.Checked := FConfig.EmDeexIgnoreCut;

  chkCut.Checked := FConfig.CutOn;
  SetQuantity(seCut, FConfig.Cut, FConfig.CutUnit, 'nm');
  for i := 0 to High(FConfig.ParticleCut) do
    if FConfig.ParticleCutUnit[i] = '' then
      ParticleCutEdit(i).Text := ''
    else
      SetQuantity(ParticleCutEdit(i), FConfig.ParticleCut[i],
                  FConfig.ParticleCutUnit[i], 'mm');

  chkStepMax.Checked := FConfig.StepMaxOn;
  SetQuantity(seStepMax, FConfig.StepMax, FConfig.StepMaxUnit, 'um');
  cbKillSecondaries.ItemIndex := FConfig.KillSecondaries;
  SetQuantity(seBeamRadius, FConfig.BeamRadius, 'mm', 'mm');
  SetQuantity(seBeamAngle, FConfig.BeamAngle, 'deg', 'deg');
  if FConfig.Events > 0 then FEvents.Value := FConfig.Events;

  if cbPhysicsList.Items.IndexOf(FConfig.PhysicsList) < 0 then
    cbPhysicsList.Items.Add(FConfig.PhysicsList);
  RestoreSelection(cbPhysicsList, FConfig.PhysicsList, '');
  ShowOptionalPhysics;

  // Spectra are re-sent rather than only shown, so that what the window
  // says is switched on is also what the backend has
  for stage := Low(TStrataStage) to High(TStrataStage) do
    CommandEditor(stage).Lines.Text := FConfig.Commands[stage].Text;

  FH1Commands.Clear;
  FH1Units.Clear;
  FH1Fcns.Clear;
  for i := 0 to High(FConfig.Spectra) do
  begin
    FH1Commands.Values[IntToStr(FConfig.Spectra[i].Id)] :=
      StrataSpectrumCommand(FConfig.Spectra[i]);
    FH1Units.Values[IntToStr(FConfig.Spectra[i].Id)] := FConfig.Spectra[i].Units;
    FH1Fcns.Values[IntToStr(FConfig.Spectra[i].Id)] := FConfig.Spectra[i].Fcn;
  end;

  if FConfig.OutputFolder <> '' then
    FApp.Options.OutputDir := FConfig.OutputFolder;
  if FConfig.OutputBase <> '' then
    edOutputBase.Text := FConfig.OutputBase;

  DoStateChanged;
end;

// Defines in the backend any stored material it does not have yet
procedure TPanelsFrame.ReplayMaterials;
var
  cmds: TStringList;
  i: Integer;
begin
  if (FEngine = nil) or (not FEngine.IsOpen) then Exit;
  if Length(FConfig.Materials) = 0 then Exit;

  RefreshMaterialCatalogue;
  cmds := TStringList.Create;
  try
    FConfig.MaterialCommands(cmds, FDefinedMaterials);
    for i := 0 to cmds.Count - 1 do
      FEngine.Apply(cmds[i]);
    if cmds.Count > 0 then
    begin
      RefreshMaterialCatalogue;
      DoLog(Format('replayed %d material command(s)', [cmds.Count]));
    end;
  finally
    cmds.Free;
  end;
end;

// When the GUI opens a file, the input and output live in that directory
procedure TPanelsFrame.WorkInDirectoryOf(const AFileName: String);
var
  dir: String;
begin
  dir := ExtractFilePath(AFileName);
  if dir = '' then Exit;
  dir := ExcludeTrailingPathDelimiter(dir);
  FApp.Options.OutputDir := dir;
  SetCurrentDir(dir);
  actSaveConfigAs.Dialog.InitialDir := dir;
  actImportMacro.Dialog.InitialDir := dir;
  actExportMacro.Dialog.InitialDir := dir;
  DoStatus('Working in ' + dir);
end;

const
  colPartKind   = 0;
  colPartName   = 1;
  colPartAmount = 2;

function TPanelsFrame.MaterialByAtoms: Boolean;
begin
  Result := rgMatMode.ItemIndex = 1;
end;

procedure TPanelsFrame.ResizeConstituentGrid(ACount: Integer);
var
  r: Integer;
begin
  if ACount < 1 then ACount := 1;
  sgConstituents.RowCount := ACount + 1;
  sgConstituents.Cells[colPartKind, 0] := 'Kind';
  sgConstituents.Cells[colPartName, 0] := 'Material or element';
  if MaterialByAtoms then
    sgConstituents.Cells[colPartAmount, 0] := 'Atoms'
  else
    sgConstituents.Cells[colPartAmount, 0] := 'Mass fraction';
  for r := 1 to ACount do
    if sgConstituents.Cells[colPartKind, r] = '' then
      sgConstituents.Cells[colPartKind, r] := 'material';
end;

procedure TPanelsFrame.UpdateConstituentSum;
var
  r: Integer;
  sum: Double;
begin
  if MaterialByAtoms then
  begin
    lblMatSum.Caption := 'atom counts need no total';
    Exit;
  end;
  sum := 0;
  for r := 1 to sgConstituents.RowCount - 1 do
    sum := sum + StrToFloatDef(Trim(sgConstituents.Cells[colPartAmount, r]),
                               0, G4Fmt);
  if Abs(sum - 1.0) <= 1.0e-4 then
    lblMatSum.Caption := Format('sum %.6g  (ok)', [sum])
  else
    lblMatSum.Caption := Format('sum %.6g  (has to be 1)', [sum]);
end;

procedure TPanelsFrame.sgConstituentsEditingDone(Sender: TObject);
begin
  UpdateConstituentSum;
end;

procedure TPanelsFrame.rgMatModeClick(Sender: TObject);
var
  r: Integer;
begin
  // Atom counts only make sense for elements
  if MaterialByAtoms then
    for r := 1 to sgConstituents.RowCount - 1 do
      sgConstituents.Cells[colPartKind, r] := 'element';
  ResizeConstituentGrid(sgConstituents.RowCount - 1);
  UpdateConstituentSum;
end;

// Reads the catalogue back from the backend and feeds everything that shows
// a material name
procedure TPanelsFrame.RefreshMaterialCatalogue;
var
  nist: TStringList;
  keep: String;
begin
  if (FEngine = nil) or (not FEngine.IsOpen) then Exit;

  if lbDefinedMaterials.ItemIndex >= 0 then
    keep := lbDefinedMaterials.Items[lbDefinedMaterials.ItemIndex]
  else
    keep := '';

  FEngine.FillDefinedMaterialNames(FDefinedMaterials);
  FDefinedMaterials.Sort;
  lbDefinedMaterials.Items.Assign(FDefinedMaterials);
  if keep <> '' then
    lbDefinedMaterials.ItemIndex := lbDefinedMaterials.Items.IndexOf(keep);

  nist := TStringList.Create;
  try
    FEngine.FillMaterialNames(nist);
    FMaterialNames.Clear;          // Sorted + dupIgnore makes this a union
    FMaterialNames.AddStrings(FDefinedMaterials);
    FMaterialNames.AddStrings(nist);

    // The picker gets the catalogue with Geant4's own grouping, and the
    // built materials separately
    MaterialsDlg.SetCatalogue(FEngine, FEngine.Materials, FDefinedMaterials);
  finally
    nist.Free;
  end;

  if FElementNames.Count = 0 then
  begin
    FEngine.FillElementNames(FElementNames);
    FElementNames.Sort;
  end;
end;

procedure TPanelsFrame.sgConstituentsSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
var
  combo: TCustomComboBox;
begin
  if aRow < 1 then Exit;
  if aCol = colPartKind then
  begin
    Editor := sgConstituents.EditorByStyle(cbsPickList);
    combo := Editor as TCustomComboBox;
    combo.Style := csDropDownList;
    combo.Items.Clear;
    if not MaterialByAtoms then combo.Items.Add('material');
    combo.Items.Add('element');
  end
  else if aCol = colPartName then
    // A button in the cell rather than a list of three hundred
    if StrataLibraryLoaded and FEngine.IsOpen then
      Editor := sgConstituents.EditorByStyle(cbsEllipsis);
end;

// The button in the name cell of the constituents grid
procedure TPanelsFrame.sgConstituentsButtonClick(Sender: TObject; aCol, aRow: Integer);
begin
  if (aRow < 1) or (aCol <> colPartName) then Exit;
  sgConstituents.Row := aRow;
  if MaterialByAtoms
     or SameText(Trim(sgConstituents.Cells[colPartKind, aRow]), 'element') then
    actSelectElementExecute(nil)
  else
    PickMaterialInto(sgConstituents, colPartName, aRow);
end;

// The button in the material cell of the layer grid
procedure TPanelsFrame.sgLayersButtonClick(Sender: TObject; aCol, aRow: Integer);
begin
  if (aRow < 1) or (aCol <> colLayerMaterial) then Exit;
  sgLayers.Row := aRow;
  PickMaterialInto(sgLayers, colLayerMaterial, aRow);
end;

// The catalogue, grouped the way Geant4 groups it, writing back into a cell
procedure TPanelsFrame.PickMaterialInto(AGrid: TStringGrid; ACol, ARow: Integer);
var
  chosen: String;
begin
  if (FEngine = nil) or (not FEngine.IsOpen) then
  begin
    DoStatus('Start the engine first: the catalogue comes from Geant4');
    Exit;
  end;
  if MaterialsDlg.Execute(Trim(AGrid.Cells[ACol, ARow]), chosen) then
    AGrid.Cells[ACol, ARow] := chosen;
end;

procedure TPanelsFrame.sgLayersSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
begin
  if aRow < 1 then Exit;
  // A button in the cell, which opens the material catalogue
  if aCol = colLayerMaterial then
    if StrataLibraryLoaded and FEngine.IsOpen then
      Editor := sgLayers.EditorByStyle(cbsEllipsis)
  // The value and its unit are one field now, so the cell is edited by the
  // same kind of box as the rest of the window
  else if aCol = colLayerThickness then
    Editor := SciEditorFor(FLayerThicknessEditor, Self, ufLength)
  else if aCol = colLayerDensity then
    Editor := SciEditorFor(FLayerDensityEditor, Self, ufDensity);
end;

function TPanelsFrame.OutputFolder: String;
begin
  Result := Trim(FConfig.OutputFolder);
end;

// Points Geant4 at the chosen folder and reports whether it is usable
function TPanelsFrame.ApplyOutputSettings: Boolean;
var
  dir, base: String;
begin
  dir := OutputFolder;
  base := Trim(edOutputBase.Text);
  if base = '' then base := 'strata';

  Result := True;

  // Geant4 runs in an engine process with a working directory of its own,
  // so every name it is given must be absolute
  if dir <> '' then
  begin
    SetCurrentDir(dir);
    FEngine.ApplyFmt('/analysis/setFileName %s',
      [IncludeTrailingPathDelimiter(dir) + base]);
  end
  else
    FEngine.ApplyFmt('/analysis/setFileName %s', [ExpandFileName(base)]);
  ApplyTrackFiles;
  lblOutputHint.Caption := 'Writing to ' + base;
end;

procedure TPanelsFrame.actPrintMaterialsExecute(Sender: TObject);
begin
  if lbDefinedMaterials.ItemIndex < 0 then
  begin
    DoStatus('Select a material first');
    Exit;
  end;
  FEngine.ApplyFmt('/strata/material/print %s', [lbDefinedMaterials.Items[lbDefinedMaterials.ItemIndex]]);
  pcMain.ActivePage := tabLog;
end;

procedure TPanelsFrame.actRefreshMaterialsExecute(Sender: TObject);
begin
  RefreshMaterialCatalogue;
  DoStatus(Format('%d material(s) defined, %d offered for picking', [FDefinedMaterials.Count, FMaterialNames.Count]));
end;

procedure TPanelsFrame.actRemoveElementExecute(Sender: TObject);
begin
  if sgConstituents.RowCount > 2 then
    sgConstituents.RowCount := sgConstituents.RowCount - 1;
  UpdateConstituentSum;
end;

procedure TPanelsFrame.actRunMacroAccept(Sender: TObject);
begin
  DoLog('> /control/execute ' + actRunMacro.Dialog.FileName);
  FEngine.ExecuteMacro(actRunMacro.Dialog.FileName);
  RefreshGeometryGrid;
  RefreshVoxelGrid;
  RefreshHistogramList;
end;

procedure TPanelsFrame.actRunMacroBeforeExecute(Sender: TObject);
begin
  actRunMacro.Dialog.Filter := 'Geant4 macros|*.mac|All files|*';
end;

procedure TPanelsFrame.actInitializeExecute(Sender: TObject);
var
  wanted: String;
begin
  if FEngine.State = STRATA_STATE_IDLE then
  begin
    ReplayMaterials;
    actApplyGeometryExecute(nil);
    actApplyPhysicsExecute(nil);
  end;

  wanted := Trim(cbParticle.Text);

  // Cuts and the EM options have to be in force before the tables are built
  ApplyRunOptions(False);
  SendStageCommands(stPreInit);

  Screen.Cursor := crHourGlass;
  try
    FEngine.Initialize;
  finally
    Screen.Cursor := crDefault;
  end;
  RefreshMaterialCatalogue;
  RefreshGeometryGrid;
  RefreshVoxelGrid;
  RefreshHistogramList;
  if Assigned(FOnKernelBuilt) then FOnKernelBuilt(Self);

  // The particle table only exists once the physics list has been built
  FEngine.FillParticleNames(cbParticle.Items);
  // "ion" has to be offered explicitly
  if cbParticle.Items.IndexOf('ion') < 0 then
    cbParticle.Items.Insert(0, 'ion');
  // Whatever was selected wins; then what a configuration asked for and
  // could not have until this moment, because the table did not exist
  RestoreSelection(cbParticle, wanted, 'proton');

  // The gun and the histograms exist only now, so the beam and the spectra
  // are sent here rather than when the configuration was read
  actApplyBeamExecute(nil);
  ApplyStoredSpectra;
  // Same for the field: /strata/BField/ is Idle-only, and a configuration
  // that carried one asked for it to be in force
  if FConfig.FieldOn then
    actApplyBFieldExecute(nil)
  else if FConfig.EFieldOn then
    actApplyEFieldExecute(nil);
  ApplyRBS;
  ApplyDamage;
  // Only the step limit and the stacking choice are left: the rest went in
  // before Initialize and would be ignored now
  ApplyRunOptions(True);

  DoStatus('Geometry and physics tables built');
  DoStateChanged;
end;

// Reads a configuration and takes that file as the document
function TPanelsFrame.OpenConfigFile(const AFileName: String; AAskFirst: Boolean): Boolean;
begin
  Result := False;
  if AAskFirst and (not MayReplaceConfig) then Exit;
  if Assigned(FOnNewDocument) and (not FOnNewDocument()) then Exit;
  try
    FConfig.LoadFromXML(AFileName);
  except
    on E: Exception do
    begin
      MessageDlg('Strata', 'The configuration could not be read:'
                 + LineEnding + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  ConfigToWidgets;
  WorkInDirectoryOf(AFileName);
  ReplayMaterials;
  FConfigFile := AFileName;
  actSaveConfigAs.Dialog.FileName := FConfigFile;
  MarkConfigSaved;
  DoStatus('Loaded ' + ExtractFileName(AFileName)
         + '; apply the pages, or start a new session, to put it into effect');
  Result := True;
end;

procedure TPanelsFrame.actImportMacroAccept(Sender: TObject);
begin
  ImportMacro(actImportMacro.Dialog.FileName,
              ChangeFileExt(actImportMacro.Dialog.FileName, '.scf'));
end;

// Reads a macro into the pages; ADocument is the configuration it becomes,
// empty for one with no file yet
function TPanelsFrame.ImportMacro(const AFileName, ADocument: String; AAskFirst: Boolean): Boolean;
var
  unknown, lines: TStringList;
  linesRead, beams, i: Integer;
  shown: String;
  cmds: TStrataMacroCommands;
begin
  Result := False;
  if AAskFirst and (not MayReplaceConfig) then Exit;
  if Assigned(FOnNewDocument) and (not FOnNewDocument()) then Exit;
  // The panels hold one beam; a macro may run several
  beams := 0;
  lines := TStringList.Create;
  try
    try
      lines.LoadFromFile(AFileName);
      cmds := StrataParseMacro(lines);
      for i := 0 to High(cmds) do
        if cmds[i].Kind = mkBeamOn then Inc(beams);
    except
      beams := 0;
    end;
  finally
    lines.Free;
  end;
  if ADocument <> '' then
    shown := ExtractFileName(ChangeFileExt(ADocument, '.mac'))
  else
    shown := 'the macro';
  unknown := TStringList.Create;
  try
    try
      linesRead := FConfig.LoadFromMacro(AFileName, unknown);
    except
      on E: Exception do
      begin
        MessageDlg('Strata', 'The macro could not be read:' + LineEnding + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
    ConfigToWidgets;
    if ADocument <> '' then WorkInDirectoryOf(ADocument);
    ReplayMaterials;
    FConfigFile := ADocument;
    // Say what was dropped rather than pretending the whole file was understood
    if unknown.Count > 0 then
    begin
      DoLog(Format('%d line(s) of %s do not map onto a panel and were kept '
                      + 'in the command boxes on the Options tab:',
                      [unknown.Count, shown]));
      DoLog(unknown.Text);
      DoStatus(Format('Imported %d setting(s); %d line(s) kept in the command '
                    + 'boxes on the Options tab', [linesRead, unknown.Count]));
    end
    else
      DoStatus(Format('Imported %d setting(s) from %s', [linesRead, shown]));
    DoDocumentChanged;
    if beams > 1 then
    begin
      DoLog(Format('%s runs %d beams; the panels keep the settings in force at '
                   + 'the last one', [shown, beams]));
      MessageDlg('Strata', Format('%s runs %d beams (/run/beamOn), but the panels '
        + 'hold only one: they now show the settings in force at the last run, '
        + 'and the earlier beams were dropped.' + LineEnding + LineEnding
        + 'Open the macro in the macro editor to run all of them.',
        [shown, beams]), mtWarning, [mbOK], 0);
    end;
    Result := True;
  finally
    unknown.Free;
  end;
end;

// The pages as the macro Export would write
function TPanelsFrame.ConfigAsMacro: String;
var
  path: String;
  macro: TStringList;
begin
  ConfigFromWidgets;
  path := GetTempFileName(GetTempDir, 'strata');
  macro := TStringList.Create;
  try
    FConfig.SaveToMacro(path);
    macro.LoadFromFile(path);
    Result := macro.Text;
  finally
    macro.Free;
    DeleteFile(path);
  end;
end;

function TPanelsFrame.ConfigFileName: String;
begin
  Result := FConfigFile;
end;

procedure TPanelsFrame.actExportMacroBeforeExecute(Sender: TObject);
begin
  actExportMacro.Dialog.FileName := 'strata-config.mac';
end;

procedure TPanelsFrame.actExportMacroAccept(Sender: TObject);
begin
  ConfigFromWidgets;
  try
    FConfig.SaveToMacro(actExportMacro.Dialog.FileName);
  except
    on E: Exception do
    begin
      MessageDlg('Strata', 'The macro could not be written:' + LineEnding + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  WorkInDirectoryOf(actExportMacro.Dialog.FileName);
  DoStatus('Exported ' + ExtractFileName(actExportMacro.Dialog.FileName)
         + ', it runs as it stands: Strata ' + ExtractFileName(actExportMacro.Dialog.FileName));
end;

procedure TPanelsFrame.actBeamOnExecute(Sender: TObject);
begin
  if not TrackOutputAccepted then Exit;
  if not ApplyOutputSettings then Exit;
  ApplyRBS;
  ApplyDamage;
  ApplyRunOptions(True);
  SendStageCommands(stRun);
  DoRunStarting;
  FEngine.BeamOn(FEvents.Value);
  DoStatus(Format('Running %d events...', [FEvents.Value]));
  DoStateChanged;
end;

procedure TPanelsFrame.actClearLogExecute(Sender: TObject);
begin
  mLog.Clear;
end;

procedure TPanelsFrame.actCreateMaterialExecute(Sender: TObject);
var
  r, rows, parts, i, editing: Integer;
  density: Double;
  matName, kind, part, amount: String;
  value, sum: Double;
begin
  matName := Trim(edMatName.Text);
  if matName = '' then
  begin
    MessageDlg('Materials', 'Give the material a name.', mtWarning, [mbOK], 0);
    Exit;
  end;
  editing := FConfig.IndexOfMaterial(matName);
  if (editing < 0) and (FDefinedMaterials.IndexOf(matName) >= 0) then
  begin
    MessageDlg('Materials', 'A material called ' + matName
               + ' already exists.  Pick another name.', mtWarning, [mbOK], 0);
    Exit;
  end;
  density := ReadRef(seMatDensity, sqDensity, 0);
  if density <= 0 then
  begin
    MessageDlg('Materials', 'The density has to be greater than zero.', mtWarning, [mbOK], 0);
    Exit;
  end;

  // Check the whole grid before sending anything
  rows := sgConstituents.RowCount - 1;
  parts := 0;
  sum := 0;
  for r := 1 to rows do
  begin
    part := Trim(sgConstituents.Cells[colPartName, r]);
    amount := Trim(sgConstituents.Cells[colPartAmount, r]);
    if (part = '') and (amount = '') then Continue;
    if part = '' then
    begin
      MessageDlg('Materials', Format('Row %d has an amount but no name.', [r]), mtWarning, [mbOK], 0);
      Exit;
    end;
    value := StrToFloatDef(amount, -1, G4Fmt);
    if value <= 0 then
    begin
      MessageDlg('Materials', Format('Row %d (%s) needs an amount greater '
                 + 'than zero.', [r, part]), mtWarning, [mbOK], 0);
      Exit;
    end;
    if MaterialByAtoms and (Frac(value) <> 0) then
    begin
      MessageDlg('Materials', Format('Row %d (%s): a number of atoms has to '
                 + 'be a whole number.', [r, part]), mtWarning, [mbOK], 0);
      Exit;
    end;
    Inc(parts);
    sum := sum + value;
  end;

  if parts = 0 then
  begin
    MessageDlg('Materials', 'Add at least one constituent.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if (not MaterialByAtoms) and (Abs(sum - 1.0) > 1.0e-4) then
  begin
    MessageDlg('Materials', Format('The mass fractions add up to %.6g '
               + 'instead of 1.', [sum]), mtWarning, [mbOK], 0);
    Exit;
  end;

  // An edited recipe only reaches the backend at the next start: Geant4
  // keeps a material for the life of the process
  if editing >= 0 then
  begin
    RecordMaterialRecipe(editing, matName, density);
    ConfigModified;
    RefreshGeometryGrid;
    if FDefinedMaterials.IndexOf(matName) >= 0 then
      DoStatus(matName + ' updated, restart the engine to rebuild it')
    else
      DoStatus(matName + ' updated');
    Exit;
  end;

  FEngine.ApplyFmt('/strata/material/create %s %s %s',
    [matName, NumToG4(density), StrataReferenceUnit(sqDensity)]);
  for r := 1 to rows do
  begin
    part := Trim(sgConstituents.Cells[colPartName, r]);
    amount := Trim(sgConstituents.Cells[colPartAmount, r]);
    if (part = '') or (amount = '') then Continue;
    value := StrToFloatDef(amount, 0, G4Fmt);
    kind := Trim(sgConstituents.Cells[colPartKind, r]);
    if MaterialByAtoms then
      FEngine.ApplyFmt('/strata/material/addElementByAtoms %s %d', [part, Round(value)])
    else if SameText(kind, 'element') then
      FEngine.ApplyFmt('/strata/material/addElement %s %s', [part, NumToG4(value)])
    else
      FEngine.ApplyFmt('/strata/material/addMaterial %s %s', [part, NumToG4(value)]);
  end;
  FEngine.Apply('/strata/material/build');

  // The backend reports a rejected definition in the log rather than in the
  // command status, so confirm by asking whether the material now exists
  RefreshMaterialCatalogue;
  if FDefinedMaterials.IndexOf(matName) >= 0 then
  begin
    // The backend can say that a material exists but not how it was created
    if FConfig.IndexOfMaterial(matName) < 0 then
    begin
      i := FConfig.AddMaterial;
      RecordMaterialRecipe(i, matName, density);
    end;
    RefreshGeometryGrid;
    DoStatus(matName + ' created');
    edMatName.Text := '';
  end
  else
  begin
    FEngine.Apply('/strata/material/cancel');
    pcMain.ActivePage := tabLog;
    DoStatus('The material was refused, see the Log tab');
  end;
end;

// The recipe as the grid now reads it
procedure TPanelsFrame.RecordMaterialRecipe(AIndex: Integer; const AName: String;
  ADensity: Double);
var
  r, p: Integer;
  part, amount: String;
begin
  FConfig.Materials[AIndex].Name := AName;
  FConfig.Materials[AIndex].Density := ADensity;
  FConfig.Materials[AIndex].DensityUnit := 'g/cm3';
  FConfig.Materials[AIndex].ByAtoms := MaterialByAtoms;
  SetLength(FConfig.Materials[AIndex].Parts, 0);
  for r := 1 to sgConstituents.RowCount - 1 do
  begin
    part := Trim(sgConstituents.Cells[colPartName, r]);
    amount := Trim(sgConstituents.Cells[colPartAmount, r]);
    if (part = '') or (amount = '') then Continue;
    p := Length(FConfig.Materials[AIndex].Parts);
    SetLength(FConfig.Materials[AIndex].Parts, p + 1);
    if MaterialByAtoms then
      FConfig.Materials[AIndex].Parts[p].Kind := 'element'
    else
      FConfig.Materials[AIndex].Parts[p].Kind :=
        Trim(sgConstituents.Cells[colPartKind, r]);
    FConfig.Materials[AIndex].Parts[p].Name := part;
    FConfig.Materials[AIndex].Parts[p].Amount := StrataTextToNum(amount, 0);
  end;
end;

// Put a recipe back in the editor, to be changed and created again
procedure TPanelsFrame.LoadMaterialIntoEditor(const AName: String);
var
  i, p: Integer;
begin
  i := FConfig.IndexOfMaterial(AName);
  if i < 0 then
  begin
    MessageDlg('Materials', AName + ' has no recipe here, it is one of '
               + 'Strata''s own or comes from the Geant4 catalogue.',
               mtInformation, [mbOK], 0);
    Exit;
  end;

  edMatName.Text := FConfig.Materials[i].Name;
  SetQuantity(seMatDensity, FConfig.Materials[i].Density,
              StrataSciUnitSpelling(FConfig.Materials[i].DensityUnit),
              StrataSciUnitSpelling('g/cm3'));
  // Before the grid, the mode rewrites the Kind column
  if FConfig.Materials[i].ByAtoms then
    rgMatMode.ItemIndex := 1
  else
    rgMatMode.ItemIndex := 0;

  sgConstituents.RowCount := 1;
  ResizeConstituentGrid(Length(FConfig.Materials[i].Parts));
  for p := 0 to High(FConfig.Materials[i].Parts) do
  begin
    sgConstituents.Cells[colPartKind, p + 1] := FConfig.Materials[i].Parts[p].Kind;
    sgConstituents.Cells[colPartName, p + 1] := FConfig.Materials[i].Parts[p].Name;
    sgConstituents.Cells[colPartAmount, p + 1] :=
      StrataNumToText(FConfig.Materials[i].Parts[p].Amount);
  end;
  UpdateConstituentSum;
  DoStatus('Editing ' + AName);
end;

// Green for the ones with a recipe, which are the ones that can be edited
procedure TPanelsFrame.lbDefinedMaterialsDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  box: TListBox;
begin
  box := Control as TListBox;
  box.Canvas.FillRect(ARect);
  if not (odSelected in State) then
    if FConfig.IndexOfMaterial(box.Items[Index]) >= 0 then
      box.Canvas.Font.Color := clGreen
    else
      box.Canvas.Font.Color := clWindowText;
  box.Canvas.TextOut(ARect.Left + 2, ARect.Top, box.Items[Index]);
end;

procedure TPanelsFrame.lbDefinedMaterialsDblClick(Sender: TObject);
begin
  if lbDefinedMaterials.ItemIndex >= 0 then
    LoadMaterialIntoEditor(lbDefinedMaterials.Items[lbDefinedMaterials.ItemIndex]);
end;

procedure TPanelsFrame.actAddElementExecute(Sender: TObject);
begin
  ResizeConstituentGrid(sgConstituents.RowCount);
  UpdateConstituentSum;
end;

procedure TPanelsFrame.actApplyBeamExecute(Sender: TObject);
var
  qv: Double;
  qu: String;
begin
  SendStageCommands(stBeam);

  if IonSelected then
  begin
    // Charge -1 means the default, a bare nucleus
    FEngine.Apply('/gun/particle ion');
    FEngine.ApplyFmt('/gun/ion %d %d %d', [seIonZ.Value, seIonA.Value, seIonQ.Value]);
  end
  else if cbParticle.Text <> '' then
    FEngine.ApplyFmt('/gun/particle %s', [cbParticle.Text]);
  if SciValid(seEnergy) then
  begin
    qv := ReadRef(seEnergy, sqEnergy, 0);
    qu := StrataProblemUnit(sqEnergy, [qv]);
    FEngine.ApplyFmt('/gun/energy %s %s', [InProblemUnit(qv, sqEnergy, qu), qu]);
  end
  else
    DoLog('The beam energy is not a valid energy; it was not sent');

  if ReadAsTyped(seBeamRadius, sqLength, qv, qu) and (qv > 0) then
    FEngine.ApplyFmt('/strata/gun/rndBeam %s %s', [NumToG4(qv), qu]);
  // Always sent: going back to a straight beam is as much a change as
  // tilting it, and the gun keeps the last angle it was given
  FEngine.ApplyFmt('/strata/gun/angle %s deg',
                   [NumToG4(ReadRef(seBeamAngle, sqAngle, 0))]);
  DoStatus('Beam applied');
end;

procedure TPanelsFrame.actApplyGeometryExecute(Sender: TObject);
var
  r: Integer;
  shapeFixed: Boolean;
  layerValue, vx, vy, vz: Double;
  lengthUnit: String;
begin
  // After kernel initialiation, only the materials can be changed
  shapeFixed := FEngine.State <> STRATA_STATE_IDLE;

  // Each length, or group of lengths sharing a command, goes in its own unit
  if not shapeFixed then
    if ReadAsTyped(seSizeYZ, sqLength, layerValue, lengthUnit) then
      FEngine.ApplyFmt('/strata/geometry/setSizeYZ %s %s', [NumToG4(layerValue), lengthUnit])
    else
      DoLog('The transverse size is not a valid length; it was not sent');
  // Before the shape is fixed, like the size: the command rebuilds the
  // layer materials, and once the volumes exist they are already placed
  if not shapeFixed then
    FEngine.ApplyFmt('/strata/geometry/setTemperature %s kelvin',
                     [NumToG4(ReadInUnit(seTemperature, 'K', 293.15))]);
  if edWorldMaterial.Caption <> '' then
    FEngine.ApplyFmt('/strata/geometry/setWorldMat %s', [edWorldMaterial.Caption]);
  if not shapeFixed then
    FEngine.ApplyFmt('/strata/geometry/layerNumber %d', [seLayerCount.Value]);

  for r := 1 to seLayerCount.Value do
  begin
    if not shapeFixed then
    begin
      if CellAsTyped(sgLayers.Cells[colLayerThickness, r], ufLength, sqLength, layerValue, lengthUnit) then
        FEngine.ApplyFmt('/strata/geometry/layerThickness %d %s %s', [r - 1, NumToG4(layerValue), StrataG4UnitSpelling(lengthUnit)])
      else
        DoLog(Format('Layer %d: "%s" is not a length; the thickness was '
                        + 'not sent', [r - 1, Trim(sgLayers.Cells[colLayerThickness, r])]));
    end;
    if Trim(sgLayers.Cells[colLayerMaterial, r]) <> '' then
      // A density only goes with the material when the cell holds one; the
      // command reads a density of zero as "leave the material alone"
      if CellRef(sgLayers.Cells[colLayerDensity, r], ufDensity, sqDensity, layerValue) then
        FEngine.ApplyFmt('/strata/geometry/layerMaterial %d %s %s %s',
                         [r - 1, Trim(sgLayers.Cells[colLayerMaterial, r]),
                         NumToG4(layerValue), StrataReferenceUnit(sqDensity)])
      else
        FEngine.ApplyFmt('/strata/geometry/layerMaterial %d %s', [r - 1, Trim(sgLayers.Cells[colLayerMaterial, r])]);
  end;

  // Voxels can only be declared before the kernel is initialized
  if not shapeFixed then
  begin
    FEngine.ApplyFmt('/strata/geometry/voxelNumber %d', [seVoxelCount.Value]);
    for r := 1 to seVoxelCount.Value do
    begin
      if ReadVoxelTriple(r, colVoxSizeX, colVoxSizeY, colVoxSizeZ, vx, vy, vz, lengthUnit) then
        FEngine.ApplyFmt('/strata/geometry/voxelDefinition %d %s %s %s %s',
                         [r - 1, NumToG4(vx), NumToG4(vy), NumToG4(vz), lengthUnit])
      else
        DoLog(Format('Volume %d: the size is not three lengths; it was not sent', [r - 1]));
      if ReadVoxelTriple(r, colVoxPosX, colVoxPosY, colVoxPosZ, vx, vy, vz, lengthUnit) then
        FEngine.ApplyFmt('/strata/geometry/voxelPosition %d %s %s %s %s',
                         [r - 1, NumToG4(vx), NumToG4(vy), NumToG4(vz), lengthUnit])
      else
        DoLog(Format('Volume %d: the position is not three lengths; it was not sent', [r - 1]));
    end;
  end;

  SendStageCommands(stGeometry);

  if shapeFixed then
  begin
    // A material change is picked up by the next run
    RefreshGeometryGrid;
    RefreshVoxelGrid;
    DoStatus('Materials applied; layer count, thickness and transverse size need a new session');
  end
  else
    DoStatus('Geometry applied');
end;

// Reads one row of three value-and-unit cells
function TPanelsFrame.ReadVoxelTriple(ARow, AColX, AColY, AColZ: Integer; out AX, AY, AZ: Double; out AUnit: String): Boolean;
begin
  // Set before the parses, because each one leaves its output alone when it
  // fails and the three are chained with short-circuiting and
  AX := 0;
  AY := 0;
  AZ := 0;
  Result := CellAsTyped(sgVoxelDefs.Cells[AColZ, ARow], ufLength, sqLength, AZ, AUnit);
  AUnit := StrataG4UnitSpelling(AUnit);
  Result := Result
            and StrataParseQuantityAs(sgVoxelDefs.Cells[AColX, ARow], ufLength, StrataSciUnitSpelling(AUnit), AX)
            and StrataParseQuantityAs(sgVoxelDefs.Cells[AColY, ARow], ufLength, StrataSciUnitSpelling(AUnit), AY);
end;

// The stepper list is fixed, so it is filled once and never refreshed
procedure TPanelsFrame.FillStepperList;
var
  i: Integer;
begin
  cbFieldStepper.Items.BeginUpdate;
  try
    cbFieldStepper.Items.Clear;
    for i := Low(kFieldSteppers) to High(kFieldSteppers) do
      cbFieldStepper.Items.Add(Format('%d - %s', [kFieldSteppers[i].Number, kFieldSteppers[i].Name]));
  finally
    cbFieldStepper.Items.EndUpdate;
  end;
  cbFieldStepper.ItemIndex := 0;
end;

function TPanelsFrame.CurrentStepper: Integer;
begin
  Result := kFieldSteppers[Low(kFieldSteppers)].Number;
  if (cbFieldStepper.ItemIndex >= Low(kFieldSteppers)) and (cbFieldStepper.ItemIndex <= High(kFieldSteppers)) then
    Result := kFieldSteppers[cbFieldStepper.ItemIndex].Number;
end;

// Selected by index, never by assigning Text: the list is a csDropDownList
procedure TPanelsFrame.SelectStepper(ANumber: Integer);
var
  i: Integer;
begin
  for i := Low(kFieldSteppers) to High(kFieldSteppers) do
    if kFieldSteppers[i].Number = ANumber then
    begin
      cbFieldStepper.ItemIndex := i;
      Exit;
    end;
  cbFieldStepper.ItemIndex := 0;
end;

procedure TPanelsFrame.FillEStepperList;
var
  i: Integer;
begin
  cbEFieldStepper.Items.BeginUpdate;
  try
    cbEFieldStepper.Items.Clear;
    for i := Low(kEFieldSteppers) to High(kEFieldSteppers) do
      cbEFieldStepper.Items.Add(Format('%d - %s',
        [kEFieldSteppers[i].Number, kEFieldSteppers[i].Name]));
  finally
    cbEFieldStepper.Items.EndUpdate;
  end;
  cbEFieldStepper.ItemIndex := 0;
end;

function TPanelsFrame.CurrentEStepper: Integer;
begin
  Result := kEFieldSteppers[Low(kEFieldSteppers)].Number;
  if (cbEFieldStepper.ItemIndex >= Low(kEFieldSteppers))
  and (cbEFieldStepper.ItemIndex <= High(kEFieldSteppers)) then
    Result := kEFieldSteppers[cbEFieldStepper.ItemIndex].Number;
end;

procedure TPanelsFrame.SelectEStepper(ANumber: Integer);
var
  i: Integer;
begin
  for i := Low(kEFieldSteppers) to High(kEFieldSteppers) do
    if kEFieldSteppers[i].Number = ANumber then
    begin
      cbEFieldStepper.ItemIndex := i;
      Exit;
    end;
  cbEFieldStepper.ItemIndex := 0;
end;

// Only one field can be in force
function TPanelsFrame.MagneticFieldWanted: Boolean;
begin
  Result := (ReadRef(seFieldBx, sqField, 0) <> 0)
         or (ReadRef(seFieldBy, sqField, 0) <> 0)
         or (ReadRef(seFieldBz, sqField, 0) <> 0);
end;

function TPanelsFrame.ElectricFieldWanted: Boolean;
begin
  Result := (ReadRef(seEFieldEx, sqEField, 0) <> 0)
         or (ReadRef(seEFieldEy, sqEField, 0) <> 0)
         or (ReadRef(seEFieldEz, sqEField, 0) <> 0);
end;

// Typing a component into one box closes the other
procedure TPanelsFrame.FieldValueChange(Sender: TObject; NewValue: Double);
begin
  DoStateChanged;
end;

function TPanelsFrame.ParticleCutEdit(AIndex: Integer): TSciEdit;
begin
  // In the order kCutParticles lists them
  case AIndex of
    0: Result := seCutGamma;
    1: Result := seCutElectron;
    2: Result := seCutPositron;
  else
    Result := seCutProton;
  end;
end;

// De-excitation, cuts and the tracking limits
procedure TPanelsFrame.ApplyRunOptions(AIdleOnly: Boolean);
var
  i: Integer;
  v: Double;
  u: String;
begin
  if not FEngine.IsOpen then Exit;

  if not AIdleOnly then
  begin
    FEngine.ApplyFmt('/process/em/fluo %s', [G4Bool(chkEmFluo.Checked)]);
    FEngine.ApplyFmt('/process/em/auger %s', [G4Bool(chkEmAuger.Checked)]);
    FEngine.ApplyFmt('/process/em/augerCascade %s', [G4Bool(chkEmAugerCascade.Checked)]);
    FEngine.ApplyFmt('/process/em/pixe %s', [G4Bool(chkEmPixe.Checked)]);
    FEngine.ApplyFmt('/process/em/deexcitationIgnoreCut %s',
                     [G4Bool(chkEmDeexIgnoreCut.Checked)]);

    if chkCut.Checked and ReadAsTyped(seCut, sqLength, v, u) then
      FEngine.ApplyFmt('/run/setCut %s %s', [NumToG4(v), StrataG4UnitSpelling(u)]);
    for i := 0 to High(kCutParticles) do
      if ReadAsTyped(ParticleCutEdit(i), sqLength, v, u) then
        FEngine.ApplyFmt('/run/setCutForAGivenParticle %s %s %s',
                         [kCutParticles[i], NumToG4(v), StrataG4UnitSpelling(u)]);
  end;

  // The step limit and the stacking choice need the kernel
  if FEngine.State = STRATA_STATE_IDLE then Exit;
  if chkStepMax.Checked and ReadAsTyped(seStepMax, sqLength, v, u) then
    FEngine.ApplyFmt('/strata/stepMax %s %s', [NumToG4(v), StrataG4UnitSpelling(u)]);
  if cbKillSecondaries.ItemIndex > 0 then
    FEngine.ApplyFmt('/strata/stack/killSecondaries %d', [cbKillSecondaries.ItemIndex]);
end;

// A box that is only meaningful when its switch is ticked
procedure TPanelsFrame.OptionToggled(Sender: TObject);
begin
  DoStateChanged;
end;

// The detector settings, sent whenever they could have changed
procedure TPanelsFrame.ApplyRBS;
begin
  if not FEngine.IsOpen then Exit;
  FEngine.ApplyFmt('/strata/rbs/enable %s', [G4Bool(chkRBS.Checked)]);
  if not chkRBS.Checked then Exit;
  FEngine.ApplyFmt('/strata/rbs/angle %s deg',
                   [NumToG4(ReadRef(seRBSAngle, sqAngle, 165))]);
  FEngine.ApplyFmt('/strata/rbs/solidAngle %s msr',
                   [NumToG4(ReadRef(seRBSSolidAngle, sqSolidAngle, 1))]);
  FEngine.ApplyFmt('/strata/rbs/resolution %s MeV',
                   [NumToG4(ReadRef(seRBSResolution, sqEnergy, 0))]);
  FEngine.ApplyFmt('/strata/rbs/tilt %s deg',
                   [NumToG4(ReadRef(seRBSTilt, sqAngle, 0))]);
  FEngine.ApplyFmt('/strata/rbs/screening %s', [G4Bool(chkRBSScreening.Checked)]);
end;

// Ticking the box closes or opens the four settings beside it
procedure TPanelsFrame.RBSEnabledChange(Sender: TObject);
begin
  ApplyRBS;
  DoStateChanged;
end;

// Only what differs from the built-in table is kept, so showing the
// defaults does not modify the configuration
procedure TPanelsFrame.DamageFromGrid;
var
  r, i, j: Integer;
  mat: String;
  ed, b, c, dEd, dB, dC: Double;
  hasArc, known, same: Boolean;
begin
  for r := 1 to sgDamage.RowCount - 1 do
  begin
    mat := Trim(sgDamage.Cells[colDmgMaterial, r]);
    if mat = '' then Continue;
    ed := StrataTextToNum(Trim(sgDamage.Cells[colDmgEd, r]), 0);
    hasArc := (Trim(sgDamage.Cells[colDmgB, r]) <> '') and (Trim(sgDamage.Cells[colDmgC, r]) <> '');
    b := StrataTextToNum(Trim(sgDamage.Cells[colDmgB, r]), 0);
    c := StrataTextToNum(Trim(sgDamage.Cells[colDmgC, r]), 1);

    known := FEngine.DamageDefaults(mat, dEd, dB, dC);
    // An empty Ed is the table's; empty b and c on a tabulated material have
    // to be said out loud, or its built-in correction stays in force
    if known and (Trim(sgDamage.Cells[colDmgEd, r]) = '') then ed := dEd;
    if known and (not hasArc) then
    begin
      hasArc := True;
      b := 0;
      c := 1;
    end;
    if known then
      same := SameValue(ed, dEd) and hasArc and SameValue(b, dB) and SameValue(c, dC)
    else
      same := (ed <= 0) and (not hasArc);

    if same then
    begin
      // Back to the table, or never set: no entry
      for i := 0 to High(FConfig.Damage) do
        if FConfig.Damage[i].Material = mat then
        begin
          for j := i to High(FConfig.Damage) - 1 do
            FConfig.Damage[j] := FConfig.Damage[j + 1];
          SetLength(FConfig.Damage, Length(FConfig.Damage) - 1);
          Break;
        end;
      Continue;
    end;

    i := FConfig.DamageFor(mat);
    FConfig.Damage[i].Ed := ed;
    FConfig.Damage[i].HasArc := hasArc;
    FConfig.Damage[i].ArcB := b;
    FConfig.Damage[i].ArcC := c;
  end;
end;

// One row per material in the layers, and per material set before
procedure TPanelsFrame.RefreshDamageGrid;
var
  mats: TStringList;
  i, r: Integer;
  ed, b, c: Double;
  have: Boolean;
begin
  mats := TStringList.Create;
  try
    mats.Duplicates := dupIgnore;
    mats.Sorted := False;
    for i := 1 to sgLayers.RowCount - 1 do
      if (Trim(sgLayers.Cells[colLayerMaterial, i]) <> '')
         and (mats.IndexOf(Trim(sgLayers.Cells[colLayerMaterial, i])) < 0) then
        mats.Add(Trim(sgLayers.Cells[colLayerMaterial, i]));
    for i := 0 to High(FConfig.Damage) do
      if mats.IndexOf(FConfig.Damage[i].Material) < 0 then
        mats.Add(FConfig.Damage[i].Material);

    sgDamage.BeginUpdate;
    try
      sgDamage.RowCount := mats.Count + 1;
      sgDamage.Cells[colDmgMaterial, 0] := 'Material';
      sgDamage.Cells[colDmgEd, 0] := 'Ed (eV)';
      sgDamage.Cells[colDmgB, 0] := 'arc b';
      sgDamage.Cells[colDmgC, 0] := 'arc c';
      for r := 1 to mats.Count do
      begin
        sgDamage.Cells[colDmgMaterial, r] := mats[r - 1];
        sgDamage.Cells[colDmgEd, r] := '';
        sgDamage.Cells[colDmgB, r] := '';
        sgDamage.Cells[colDmgC, r] := '';

        have := False;
        for i := 0 to High(FConfig.Damage) do
          if FConfig.Damage[i].Material = mats[r - 1] then
          begin
            have := True;
            if FConfig.Damage[i].Ed > 0 then
              sgDamage.Cells[colDmgEd, r] := StrataNumToText(FConfig.Damage[i].Ed);
            if FConfig.Damage[i].HasArc then
            begin
              sgDamage.Cells[colDmgB, r] := StrataNumToText(FConfig.Damage[i].ArcB);
              sgDamage.Cells[colDmgC, r] := StrataNumToText(FConfig.Damage[i].ArcC);
            end;
            Break;
          end;

        if (not have) and FEngine.DamageDefaults(mats[r - 1], ed, b, c) then
        begin
          sgDamage.Cells[colDmgEd, r] := StrataNumToText(ed);
          sgDamage.Cells[colDmgB, r] := StrataNumToText(b);
          sgDamage.Cells[colDmgC, r] := StrataNumToText(c);
        end;
      end;
    finally
      sgDamage.EndUpdate;
    end;
  finally
    mats.Free;
  end;
end;

// The constants first, so that nothing is counted with the wrong ones
procedure TPanelsFrame.ApplyDamage;
var
  i: Integer;
begin
  if not FEngine.IsOpen then Exit;
  DamageFromGrid;
  for i := 0 to High(FConfig.Damage) do
  begin
    if FConfig.Damage[i].Ed > 0 then
      FEngine.ApplyFmt('/strata/damage/setEd %s %s eV',
                       [FConfig.Damage[i].Material, NumToG4(FConfig.Damage[i].Ed)]);
    if FConfig.Damage[i].HasArc then
      FEngine.ApplyFmt('/strata/damage/setArc %s %s %s',
                       [FConfig.Damage[i].Material, NumToG4(FConfig.Damage[i].ArcB),
                        NumToG4(FConfig.Damage[i].ArcC)]);
  end;
  FEngine.ApplyFmt('/strata/damage/enable %s', [G4Bool(chkDamage.Checked)]);
end;

procedure TPanelsFrame.DamageEnabledChange(Sender: TObject);
begin
  ApplyDamage;
  DoStateChanged;
end;

// The layers may have changed since the table was last built
procedure TPanelsFrame.pcMainChange(Sender: TObject);
begin
  if pcMain.ActivePage <> tabBeamPhysics then Exit;
  DamageFromGrid;
  RefreshDamageGrid;
end;

// The material names come from the layers
procedure TPanelsFrame.sgDamageSelectEditor(Sender: TObject; aCol, aRow: Integer; var Editor: TWinControl);
begin
  if aCol = colDmgMaterial then Editor := nil;
end;

procedure TPanelsFrame.actApplyEFieldExecute(Sender: TObject);
var
  ex, ey, ez, step: Double;
  u, stepUnit: String;
begin
  if not SciValid(seEFieldEz) then
  begin
    MessageDlg('Electric field', 'Ez is not an electric field strength.',
               mtWarning, [mbOK], 0);
    Exit;
  end;
  u := StrataReferenceUnit(sqEField);
  ex := ReadRef(seEFieldEx, sqEField, 0);
  ey := ReadRef(seEFieldEy, sqEField, 0);
  ez := ReadRef(seEFieldEz, sqEField, 0);

  if not ReadAsTyped(seEFieldMinStep, sqLength, step, stepUnit) then
  begin
    MessageDlg('Electric field', 'The minimum step is not a length.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if step <= 0 then
  begin
    MessageDlg('Electric field', 'The minimum step has to be greater than zero.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FEngine.ApplyFmt('/strata/EField/setStepperType %d', [CurrentEStepper]);
  FEngine.ApplyFmt('/strata/EField/setMinStep %s %s', [NumToG4(step), stepUnit]);
  FEngine.ApplyFmt('/strata/EField/setValue %s %s %s %s',
                   [NumToG4(ex), NumToG4(ey), NumToG4(ez), u]);
  FEngine.Apply('/strata/EField/update');

  DoStatus(Format('Electric field (%s, %s, %s) %s, minimum step %s %s',
                [NumToG4(ex), NumToG4(ey), NumToG4(ez), u, NumToG4(step), stepUnit]));
end;

procedure TPanelsFrame.actApplyBFieldExecute(Sender: TObject);
var
  bz, bx, by, step: Double;
  u, stepUnit: String;
begin
  // Tesla serves every field anyone will type here, so all three components
  // are simply read in it
  if not SciValid(seFieldBz) then
  begin
    MessageDlg('Magnetic field', 'Bz is not a magnetic flux density.', mtWarning, [mbOK], 0);
    Exit;
  end;
  u := StrataReferenceUnit(sqField);
  bz := ReadRef(seFieldBz, sqField, 0);
  bx := ReadRef(seFieldBx, sqField, 0);
  by := ReadRef(seFieldBy, sqField, 0);

  // The minimum step is a parameter of the stepper
  if not ReadAsTyped(seFieldMinStep, sqLength, step, stepUnit) then
  begin
    MessageDlg('Magnetic field', 'The minimum step is not a length.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if step <= 0 then
  begin
    MessageDlg('Magnetic field', 'The minimum step has to be greater than zero.', mtWarning, [mbOK], 0);
    Exit;
  end;

  // The stepper has to be in place before the chord finder is built
  FEngine.ApplyFmt('/strata/BField/setStepperType %d', [CurrentStepper]);
  FEngine.ApplyFmt('/strata/BField/setMinStep %s %s', [NumToG4(step), stepUnit]);
  FEngine.ApplyFmt('/strata/BField/setValue %s %s %s %s', [NumToG4(bx), NumToG4(by), NumToG4(bz), u]);
  FEngine.Apply('/strata/BField/update');

  DoStatus(Format('Field (%s, %s, %s) %s, minimum step %s %s',
                [NumToG4(bx), NumToG4(by), NumToG4(bz), u, NumToG4(step), stepUnit]));
end;

procedure TPanelsFrame.actApplyPhysicsExecute(Sender: TObject);
var
  i: Integer;
begin
  if cbPhysicsList.Text <> '' then
    FEngine.ApplyFmt('/strata/physics/addPhysics %s', [cbPhysicsList.Text]);
  for i := 0 to clbOptionalPhysics.Items.Count - 1 do
    if clbOptionalPhysics.Checked[i] then
      FEngine.ApplyFmt('/strata/physics/addPhysics %s', [clbOptionalPhysics.Items[i]]);
  ApplyRandomSetup;
  FPhysicsApplied := True;
  DoStatus('Physics list applied; it is fixed until a new session '
         + '(initialise to build the tables)');
end;

// The pages as they would be written, which is what a saved file is compared against
function TPanelsFrame.ConfigText: String;
begin
  ConfigFromWidgets;
  Result := FConfig.ToText;
end;

// Nothing watches every box, so the question is answered by serialising
function TPanelsFrame.ConfigModified: Boolean;
begin
  Result := ConfigText <> FConfigSaved;
end;

// Takes AFileName as the document, and compares the pages with what is in it
procedure TPanelsFrame.AdoptConfigFile(const AFileName: String);
var
  onDisk: TStrataConfig;
begin
  FConfigFile := AFileName;
  actSaveConfigAs.Dialog.FileName := AFileName;
  FConfigSaved := '';
  if (AFileName <> '') and FileExists(AFileName) then
  begin
    onDisk := TStrataConfig.Create;
    try
      try
        onDisk.LoadFromXML(AFileName);
        FConfigSaved := onDisk.ToText;
      except
        // Unreadable now, so the pages count as unsaved work
      end;
    finally
      onDisk.Free;
    end;
  end;
  DoDocumentChanged;
end;

// The pages and the file agree from here on
procedure TPanelsFrame.MarkConfigSaved;
begin
  FConfigSaved := ConfigText;
  DoDocumentChanged;
end;

// Offers to write the configuration before it is replaced; False means stop
function TPanelsFrame.MayReplaceConfig: Boolean;
begin
  Result := True;
  if not ConfigModified then Exit;

  case MessageDlg('Strata', 'The configuration has been modified. Save it?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      begin
        actSaveConfig.Execute;
        // A cancelled Save as leaves it modified, and then so is the answer
        Result := not ConfigModified;
      end;
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

// Writes the configuration and takes that file as the document
procedure TPanelsFrame.WriteConfig(const AFileName: String);
begin
  ConfigFromWidgets;
  try
    FConfig.SaveToXML(AFileName);
  except
    on E: Exception do
    begin
      MessageDlg('Strata', 'The configuration could not be written:'
                 + LineEnding + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  WorkInDirectoryOf(AFileName);
  FConfigFile := AFileName;
  actSaveConfigAs.Dialog.FileName := AFileName;
  MarkConfigSaved;
  DoStatus('Saved ' + ExtractFileName(AFileName));
end;

procedure TPanelsFrame.actNewConfigExecute(Sender: TObject);
begin
  if not MayReplaceConfig then Exit;
  if Assigned(FOnNewDocument) and (not FOnNewDocument()) then Exit;

  FreeAndNil(FConfig);
  FConfig := TStrataConfig.Create;
  ConfigToWidgets;
  FConfigFile := '';
  actSaveConfigAs.Dialog.FileName := '';
  MarkConfigSaved;
  DoStatus('New configuration created');
end;

procedure TPanelsFrame.actSaveConfigExecute(Sender: TObject);
begin
  if FConfigFile = '' then
    actSaveConfigAs.Execute
  else
    WriteConfig(FConfigFile);
end;

procedure TPanelsFrame.actSelectMaterialExecute(Sender: TObject);
var
  chosen: String;
begin
  if MaterialsDlg.Execute(Trim(edWorldMaterial.Caption), chosen) then
    edWorldMaterial.Caption := chosen;
end;

// The generator and the seeds
procedure TPanelsFrame.ApplyRandomSetup;
begin
  if (cbRndEngine.Text <> '') and (FEngine.State = STRATA_STATE_IDLE) then
    FEngine.ApplyFmt('/strata/random/engine %s', [cbRndEngine.Text]);

  if chkRandomize.Checked then
    FEngine.Apply('/strata/random/randomize true')
  else
    FEngine.ApplyFmt('/strata/random/seeds %d %d', [seRndSeed1.Value, seRndSeed2.Value]);
end;

function TPanelsFrame.SavingTracks: Boolean;
begin
  Result := chkSavePrimaries.Checked or chkSaveCascades.Checked;
end;

// Both files are written by RunAction
procedure TPanelsFrame.ApplyTrackFiles;

  // The engine's working directory is not this process's: a relative name
  // goes into the output folder, or else into this process's directory
  function EngineFileName(const AName: String): String;
  begin
    Result := Trim(AName);
    if (OutputFolder <> '')
       and (not ((Result[1] in AllowDirectorySeparators) or (ExtractFileDrive(Result) <> ''))) then
      Result := IncludeTrailingPathDelimiter(OutputFolder) + Result;
    Result := ExpandFileName(Result);
  end;

begin
  if Trim(edPrimariesName.Text) <> '' then
    FEngine.ApplyFmt('/strata/files/setPrimariesName %s', [EngineFileName(edPrimariesName.Text)]);
  if Trim(edCascadesName.Text) <> '' then
    FEngine.ApplyFmt('/strata/files/setCascadesName %s', [EngineFileName(edCascadesName.Text)]);
  FEngine.ApplyFmt('/strata/files/savePrimaries %s', [BoolToStr(chkSavePrimaries.Checked, 'true', 'false')]);
  FEngine.ApplyFmt('/strata/files/saveCascades %s', [BoolToStr(chkSaveCascades.Checked, 'true', 'false')]);
end;

function TPanelsFrame.TrackOutputAccepted: Boolean;
const
  kBytesPerEvent = 10*1024;
  kManyEvents = 1000;
var
  mb: Double;
begin
  Result := True;
  if not SavingTracks then Exit;

  if FEvents.Value >= kManyEvents then
  begin
    mb := FEvents.Value*kBytesPerEvent/(1024*1024);
    Result := MessageDlg('Track output',
          Format('Every step of every track is written as a line, which comes '
                 + 'to roughly 10 kB an event.  %d events would therefore produce '
                 + 'something like %.0f MB.', [FEvents.Value, mb])
             + LineEnding + LineEnding
             + 'Track files are meant for a few events at a time; lower the event '
             + 'count, or turn the files off on the Beam page.' + LineEnding
             + LineEnding + 'Run anyway?', mtWarning, [mbYes, mbNo], 0) = mrYes;
  end;
end;

procedure TPanelsFrame.chkSaveTracksChange(Sender: TObject);
begin
  DoStateChanged;
end;

procedure TPanelsFrame.chkRandomizeChange(Sender: TObject);
begin
  DoStateChanged;
end;

// After a run the backend still holds the seeds that produced it
procedure TPanelsFrame.btnUseLastSeedsClick(Sender: TObject);
var
  r: TStrataRandom;
begin
  if not FEngine.IsOpen then
  begin
    DoStatus('Start the engine first; the seeds come from the backend');
    Exit;
  end;
  r := FEngine.RandomState;
  if cbRndEngine.Items.IndexOf(r.Engine) >= 0 then
    cbRndEngine.ItemIndex := cbRndEngine.Items.IndexOf(r.Engine);
  if (r.Seed1 >= seRndSeed1.MinValue) and (r.Seed1 <= seRndSeed1.MaxValue) then
    seRndSeed1.Value := r.Seed1;
  if (r.Seed2 >= seRndSeed2.MinValue) and (r.Seed2 <= seRndSeed2.MaxValue) then
    seRndSeed2.Value := r.Seed2;
  chkRandomize.Checked := False;
  ApplyRandomSetup;
  DoStatus(Format('Seeds %d %d will be used from now on', [seRndSeed1.Value, seRndSeed2.Value]));
end;

procedure TPanelsFrame.actSaveConfigAsAccept(Sender: TObject);
begin
  WriteConfig(actSaveConfigAs.Dialog.FileName);
end;

procedure TPanelsFrame.actSaveConfigAsBeforeExecute(Sender: TObject);
begin
  // Propose what is being worked on, and a name only when there is none
  if FConfigFile <> '' then
    actSaveConfigAs.Dialog.FileName := FConfigFile
  else if actSaveConfigAs.Dialog.FileName = '' then
    actSaveConfigAs.Dialog.FileName := 'strata-config.scf';
end;

procedure TPanelsFrame.actSaveLogAccept(Sender: TObject);
begin
  mLog.Lines.SaveToFile(actSaveLog.Dialog.FileName);
  DoStatus('Log written to ' + actSaveLog.Dialog.FileName);
end;

procedure TPanelsFrame.actSaveLogBeforeExecute(Sender: TObject);
begin
  actSaveLog.Dialog.FileName := 'strata-log.txt';
  actSaveLog.Dialog.Filter := 'Text files|*.txt|All files|*';
end;

// The same table the projectile is picked from
procedure TPanelsFrame.actSelectElementExecute(Sender: TObject);
var
  r: Integer;
  sym: String;
begin
  r := sgConstituents.Row;
  if r < 1 then
  begin
    DoStatus('Select a constituent row first');
    Exit;
  end;
  if not StrataTableDlg.Execute then Exit;

  sym := StrataTableDlg.Element.Symbol;
  if (FElementNames.Count > 0) and (FElementNames.IndexOf(sym) < 0) then
  begin
    DoStatus(Format('Geant4 has no NIST data for %s', [sym]));
    Exit;
  end;

  // Atom counts only make sense for elements, and the row has to say so
  if not MaterialByAtoms then
    sgConstituents.Cells[colPartKind, r] := 'element';
  sgConstituents.Cells[colPartName, r] := 'G4_' + sym;
  DoStatus(Format('%s, Z = %d, %.4g u', [StrataTableDlg.Element.Name, StrataTableDlg.Element.Number, StrataTableDlg.Element.Weight]));
end;

procedure TPanelsFrame.actSelectIonExecute(Sender: TObject);
begin
  if StrataTableDlg.Execute then
  begin
    seIonZ.Value := StrataTableDlg.Element.Number;
    seIonA.Value := Round(StrataTableDlg.Element.Weight);
  end;
end;

procedure TPanelsFrame.actSendCommandExecute(Sender: TObject);
var
  err: String;
begin
  if Trim(edCommand.Text) = '' then Exit;
  DoLog('> ' + edCommand.Text);
  if FEngine.TryApply(Trim(edCommand.Text), err) then
    edCommand.Text := ''
  else
    DoLog('  ' + err);
end;

// A range worth starting from, in the unit returned
function TPanelsFrame.ProposeH1Range(const AHistogram: TStrataHistogram; out ALow, AHigh: Double; out AUnit: String): Boolean;
var
  thickness, energy: Double;
  r: Integer;
  v: Double;
  mm: array of Double;
begin
  Result := True;
  ALow := 0;
  AHigh := 1;
  AUnit := '';
  case AHistogram.Axis of
    akLength:
      begin
        // The depth axis spans the target, and takes the unit the layers
        // themselves are written in
        thickness := 0;
        SetLength(mm, 0);
        for r := 1 to seLayerCount.Value do
          if CellRef(sgLayers.Cells[colLayerThickness, r], ufLength, sqLength, v) then
          begin
            thickness := thickness + v;
            SetLength(mm, Length(mm) + 1);
            mm[High(mm)] := v;
          end;
        if thickness <= 0 then Exit(False);
        AUnit := StrataProblemUnit(sqLength, mm);
        AHigh := thickness/StrataUnitFactor(sqLength, AUnit);
      end;
    akEnergy:
      begin
        energy := ReadRef(seEnergy, sqEnergy, 0);
        if energy <= 0 then Exit(False);
        AUnit := StrataProblemUnit(sqEnergy, [energy]);
        AHigh := energy/StrataUnitFactor(sqEnergy, AUnit);
        // Logarithmic bins cannot start at zero
        if FH1Fcns.Values[IntToStr(AHistogram.Id)] <> '' then
          ALow := AHigh*1e-6;
      end;
    akFwdAngle:
      begin
        AUnit := StrataReferenceUnit(sqAngle);
        ALow := 0;
        AHigh := 90;
      end;
    akBackAngle:
      begin
        AUnit := StrataReferenceUnit(sqAngle);
        ALow := 90;
        AHigh := 180;
      end;
  else
    Result := False;
  end;
end;

procedure TPanelsFrame.edCommandKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    actSendCommandExecute(Sender);
  end;
end;

function TPanelsFrame.PhysicsListName: String;
begin
  Result := Trim(cbPhysicsList.Text);
end;

procedure TPanelsFrame.RefreshHistogramList;
var
  i, n, keep: Integer;
  h: TStrataHistogram;
begin
  keep := lbHistogram.ItemIndex;
  n := FEngine.HistogramCount;
  SetLength(FHistogramCache, n);
  SetLength(FHistogramIds, 0);
  SetLength(FHistogramActive, 0);
  lbHistogram.Items.BeginUpdate;
  try
    lbHistogram.Items.Clear;
    for i := 0 to n - 1 do
    begin
      h := HistogramFor(i, False);
      if chkOnlyActiveHistograms.Checked and (not h.Active) then Continue;
      if h.Title = 'dummy' then Continue;
      SetLength(FHistogramIds, Length(FHistogramIds) + 1);
      FHistogramIds[High(FHistogramIds)] := i;
      SetLength(FHistogramActive, Length(FHistogramIds));
      FHistogramActive[High(FHistogramActive)] := h.Active;
      // Active and inactive are told apart by colour, so the text stays clean
      lbHistogram.Items.Add(Format('%d - %s', [i, h.Title]));
    end;
  finally
    lbHistogram.Items.EndUpdate;
  end;
  if (keep >= 0) and (keep < lbHistogram.Items.Count) then
    lbHistogram.ItemIndex := keep
  else if lbHistogram.Items.Count > 0 then
    lbHistogram.ItemIndex := 0;
end;

function TPanelsFrame.HistogramFor(AId: Integer; AWithData: Boolean): TStrataHistogram;
begin
  Result := Default(TStrataHistogram);
  Result.Id := AId;
  if AId < 0 then Exit;

  if not RunningOrAborting then
  begin
    Result := FEngine.Histogram(AId, AWithData);
    if AId <= High(FHistogramCache) then
    begin
      FHistogramCache[AId] := Result;
      // Only the description is kept; the points go stale at once
      SetLength(FHistogramCache[AId].X, 0);
      SetLength(FHistogramCache[AId].Y, 0);
    end;
    Exit;
  end;

  if AId <= High(FHistogramCache) then Result := FHistogramCache[AId];
  Result.Id := AId;
  if AWithData and Result.Active then FEngine.LiveHistogram(AId, Result);
end;

function TPanelsFrame.CurrentHistogramId: Integer;
begin
  Result := -1;
  if (lbHistogram.ItemIndex >= 0) and (lbHistogram.ItemIndex <= High(FHistogramIds)) then
    Result := FHistogramIds[lbHistogram.ItemIndex];
end;

procedure TPanelsFrame.SelectHistogram(AId: Integer);
var
  i: Integer;
begin
  for i := 0 to High(FHistogramIds) do
    if FHistogramIds[i] = AId then
    begin
      lbHistogram.ItemIndex := i;
      Exit;
    end;
end;

procedure TPanelsFrame.FillH1Setup(AId: Integer);
var
  h: TStrataHistogram;
  axisUnit: String;
  lo, hi: Double;
begin
  if (AId < 0) or (not FEngine.IsOpen) then Exit;
  h := HistogramFor(AId, False);

  // The boxes take the dimension of the axis
  seH1Min.UnitFamily := AxisFamily(h.Axis);
  seH1Max.UnitFamily := AxisFamily(h.Axis);

  if h.Active and (h.NBins > 0) then
  begin
    seH1Bins.Value := h.NBins;
    // The unit is part of the two boxes, so it is put back into both
    axisUnit := FH1Units.Values[IntToStr(AId)];
    SetQuantity(seH1Min, h.XMin, axisUnit, '');
    SetQuantity(seH1Max, h.XMax, axisUnit, '');
    chbH1Log.Checked := FH1Fcns.Values[IntToStr(AId)] = 'log10';
    Exit;
  end;

  // An inactive histogram has no axis yet, so one is proposed
  if not ProposeH1Range(h, lo, hi, axisUnit) then Exit;
  seH1Bins.Value := 100;
  SetQuantity(seH1Min, lo, axisUnit, '');
  SetQuantity(seH1Max, hi, axisUnit, '');
  chbH1Log.Checked := False;
end;

procedure TPanelsFrame.ShowHistogram(AId: Integer; AQuiet: Boolean);
var
  h: TStrataHistogram;
  i: Integer;
  why: String;
begin
  chtHistogramSeries.Clear;
  if AId < 0 then Exit;

  DoStage(Format('reading histogram %d', [AId]));
  h := HistogramFor(AId, True);
  DoStage(Format('drawing histogram %d (%d points)', [AId, Length(h.Y)]));
  chtHistogram.Title.Text.Text := Format('h1[%d]  %s', [h.Id, h.Title]);
  if h.XAxisTitle <> '' then
    chtHistogram.BottomAxis.Title.Caption := h.XAxisTitle
  else
    chtHistogram.BottomAxis.Title.Caption := '';
  if h.YAxisTitle <> '' then
    chtHistogram.LeftAxis.Title.Caption := h.YAxisTitle
  else
    chtHistogram.LeftAxis.Title.Caption := '';

  // Every bin, on a plain linear axis
  for i := 0 to High(h.Y) do
    chtHistogramSeries.AddXY(h.X[i], h.Y[i]);

  if Length(h.Y) = 0 then
  begin
    if not AQuiet then DoStatus(Format('h1[%d] has no data yet', [AId]));
    Exit;
  end;

  if AQuiet then
  begin
    DoStatus(Format('h1[%d]: %d bins, %.6g entries so far', [AId, h.NBins, h.Entries]));
    Exit;
  end;

  why := StrataEmptySpectrumReason(h.Id, h.Entries, h.Y, PhysicsListName);
  if why = '' then
    DoStatus(Format('h1[%d]: %d bins, %.6g entries', [AId, h.NBins, h.Entries]))
  else
  begin
    DoStatus(Format('h1[%d]: %s', [AId, why]));
    DoLog(Format('h1[%d] "%s" -- %s', [AId, h.Title, why]));
  end;
end;

// Sends the /analysis/h1/set commands a configuration brought with it
procedure TPanelsFrame.ApplyStoredSpectra;
var
  i, sent: Integer;
begin
  if (FEngine = nil) or (not FEngine.IsOpen) then Exit;
  if FEngine.State = STRATA_STATE_IDLE then Exit;
  sent := 0;
  for i := 0 to FH1Commands.Count - 1 do
    if FH1Commands.ValueFromIndex[i] <> '' then
    begin
      FEngine.Apply(FH1Commands.ValueFromIndex[i]);
      Inc(sent);
    end;
  if sent > 0 then
  begin
    RefreshHistogramList;
    FillH1Setup(CurrentHistogramId);
    DoLog(Format('Activated %d spectrum/spectra from the configuration', [sent]));
  end;
end;

// Green for a spectrum that is being filled, the default colour for others
procedure TPanelsFrame.lbHistogramDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  box: TListBox;
begin
  box := Control as TListBox;
  box.Canvas.FillRect(ARect);
  if not (odSelected in State) then
    if (Index >= 0) and (Index <= High(FHistogramActive))
       and FHistogramActive[Index] then
      box.Canvas.Font.Color := clGreen
    else
      box.Canvas.Font.Color := clWindowText;
  box.Canvas.TextOut(ARect.Left + 2, ARect.Top, box.Items[Index]);
end;

procedure TPanelsFrame.lbHistogramSelectionChange(Sender: TObject; User: boolean);
begin
  // Spectrum that is selected and the chart draws it as far as it has got
  FillH1Setup(CurrentHistogramId);
  ShowHistogram(CurrentHistogramId, RunningOrAborting);
end;

procedure TPanelsFrame.actRefreshHistogramsExecute(Sender: TObject);
begin
  RefreshHistogramList;
  ShowHistogram(CurrentHistogramId);
end;

procedure TPanelsFrame.actDeactivateHistogramExecute(Sender: TObject);
var
  id: Integer;
begin
  id := CurrentHistogramId;
  if id < 0 then Exit;
  FEngine.ApplyFmt('/analysis/h1/setActivation %d false', [id]);
  FH1Commands.Values[IntToStr(id)] := '';
  RefreshHistogramList;
  SelectHistogram(id);
  ShowHistogram(CurrentHistogramId);
  DoStatus(Format('h1[%d] deactivated', [id]));
end;

procedure TPanelsFrame.actActivateHistogramExecute(Sender: TObject);
var
  id: Integer;
  u, cmd, fcn: String;
  lo, hi: Double;
  h: TStrataHistogram;
begin
  id := CurrentHistogramId;
  if id < 0 then
  begin
    DoStatus('Select a histogram first');
    Exit;
  end;

  h := HistogramFor(id, False);

  if not SciValid(seH1Max) then
  begin
    MessageDlg('Histogram', 'The upper edge is not a valid number.', mtWarning, [mbOK], 0);
    Exit;
  end;

  // The histogram says what its axis measures, check that the boxes have the right units
  if seH1Max.UnitFamily <> AxisFamily(h.Axis) then
  begin
    MessageDlg('Histogram', Format('h1[%d] measures %s, but the edges are '
      + 'set up for something else. Select the histogram again to put that '
      + 'right.', [id, AxisName(h.Axis)]), mtWarning, [mbOK], 0);
    Exit;
  end;

  if AxisHasUnit(h.Axis) then
  begin
    // Whatever the user typed, the command carries the unit chosen for this
    // dimension, the same rule the rest of the window follows
    u := StrataProblemUnit(AxisQuantity(h.Axis), [ReadRef(seH1Max, AxisQuantity(h.Axis), 0)]);
    hi := ReadInUnit(seH1Max, StrataSciUnitSpelling(u), 0);
    lo := ReadInUnit(seH1Min, StrataSciUnitSpelling(u), 0);
  end
  else
  begin
    // A log10 axis is a bare number and carries no unit at all
    u := '';
    hi := seH1Max.Value;
    lo := seH1Min.Value;
  end;

  if hi <= lo then
  begin
    MessageDlg('Histogram', 'The upper edge has to be greater than the lower edge.', mtWarning, [mbOK], 0);
    Exit;
  end;

  cmd := Format('/analysis/h1/set %d %d %s %s', [id, seH1Bins.Value, NumToG4(lo), NumToG4(hi)]);
  // Set the proper function for a logarithmic spectrum
  if chbH1Log.Checked then
    fcn := 'log10'
  else
    fcn := '';

  if u <> '' then cmd := cmd + ' ' + u
  else if fcn <> '' then cmd := cmd + ' none';
  if fcn <> '' then cmd := cmd + ' ' + fcn;

  FEngine.Apply(cmd);
  FH1Units.Values[IntToStr(id)] := u;
  FH1Fcns.Values[IntToStr(id)] := fcn;
  FH1Commands.Values[IntToStr(id)] := cmd;

  RefreshHistogramList;
  SelectHistogram(id);
  ShowHistogram(id);
  DoStatus(Format('h1[%d] active: %d bins over [%s, %s] %s', [id, seH1Bins.Value, NumToG4(lo), NumToG4(hi), u]));
end;

procedure TPanelsFrame.actExportHistogramExecute(Sender: TObject);
var
  h: TStrataHistogram;
  f: TStringList;
  i: Integer;
begin
  if CurrentHistogramId < 0 then Exit;
  h := HistogramFor(CurrentHistogramId, True);
  if Length(h.Y) = 0 then
  begin
    MessageDlg('Strata', 'That histogram has no data to export.', mtInformation,
      [mbOK], 0);
    Exit;
  end;

  dlgExportHistogram.FileName := Format('h1_%d.csv', [h.Id]);
  dlgExportHistogram.Filter := 'Comma-separated values|*.csv|All files|*';
  if not dlgExportHistogram.Execute then Exit;

  f := TStringList.Create;
  try
    f.Add(Format('# h1[%d] %s', [h.Id, h.Title]));
    f.Add(Format('# bins=%d range=[%.17g,%.17g] width=%.17g entries=%.17g',
      [h.NBins, h.XMin, h.XMax, h.Width, h.Entries]));
    f.Add('bin_centre,height');
    for i := 0 to High(h.Y) do
      f.Add(Format('%.17g,%.17g', [h.X[i], h.Y[i]]));
    f.SaveToFile(dlgExportHistogram.FileName);
    DoStatus('exported ' + dlgExportHistogram.FileName);
  finally
    f.Free;
  end;
end;

function TPanelsFrame.RunningOrAborting: Boolean;
begin
  Result := Assigned(FEngine) and (FEngine.State in [STRATA_STATE_RUNNING, STRATA_STATE_ABORTING]);
end;

procedure TPanelsFrame.RefreshResults;
var
  s: TStrataRunStatsC;
  v: TStrataVoxelDoseArray;
  i: Integer;

  procedure Put(ARow: Integer; const AName, AValue: String);
  begin
    sgSummary.Cells[0, ARow] := AName;
    sgSummary.Cells[1, ARow] := AValue;
  end;

  function Pm(AValue, ARms: Double; const AUnit: String): String;
  begin
    Result := Format('%.5g +- %.3g %s', [AValue, ARms, AUnit]);
  end;

begin
  if not FEngine.HasResults then Exit;
  s := FEngine.Stats;

  sgSummary.RowCount := 19;
  Put(1, 'Primary', FEngine.ParticleName);
  Put(2, 'Beam energy', Format('%.5g MeV', [s.beamEnergy]));
  Put(3, 'Events', IntToStr(s.events));
  Put(4, 'Target thickness', Format('%.5g mm', [s.targetThickness]));
  Put(5, 'Energy deposited/event', Pm(s.edep, s.edepRms, 'MeV'));
  Put(6, 'NIEL/event', Pm(s.niel, s.nielRms, 'MeV'));
  Put(7, 'Energy balance', Format('%.5g MeV', [s.energyBalance]));
  Put(8, 'Projected range', Pm(s.projRange, s.projRangeRms, 'mm'));
  Put(9, 'Primary steps/event', Format('%.4g', [s.meanPrimarySteps]));
  Put(10, 'Track length (charged)', Pm(s.trakLenCharged, s.trakLenChargedRms, 'mm'));
  Put(11, 'Track length (neutral)', Pm(s.trakLenNeutral, s.trakLenNeutralRms, 'mm'));
  Put(12, 'Secondaries/event', Format('%.4g e-, %.4g gamma, %.4g e+', [s.electronPerEvent, s.gammaPerEvent, s.positronPerEvent]));
  Put(13, 'Transmitted',Format('%.4g %% primary, %.4g %% any', [s.transmitPrimary, s.transmitAny]));
  Put(14, 'Reflected', Format('%.4g %% primary, %.4g %% any', [s.reflectPrimary, s.reflectAny]));
  Put(15, 'Mean dE/dx (simulated)', Format('%.5g MeV/mm', [s.meanDEdx]));
  Put(16, 'dE/dx restricted (table)', Format('%.5g MeV/mm', [s.dedxRestricted]));
  Put(17, 'dE/dx full (table)', Format('%.5g MeV/mm', [s.dedxFull]));
  Put(18, 'MSC theta0 (Highland)', Format('%.5g mrad', [s.mscHighland*1000.0]));

  v := FEngine.VoxelDoses;
  sgVoxels.RowCount := Max(2, Length(v) + 1);
  for i := 0 to High(v) do
  begin
    sgVoxels.Cells[0, i + 1] := IntToStr(i);
    sgVoxels.Cells[1, i + 1] := Format('%.6g', [v[i].Edep]);
    sgVoxels.Cells[2, i + 1] := Format('%.4g', [v[i].Ratio]);
    sgVoxels.Cells[3, i + 1] := Format('%.6g', [v[i].Dose]);
    sgVoxels.Cells[4, i + 1] := Format('%.6g', [v[i].Mass]);
  end;
end;

end.
