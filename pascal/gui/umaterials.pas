{==============================================================================
  uMaterials.pas: Picking a Geant4 material from the catalogue.

  The grouping is Geant4's own, read out of the order it builds them in and
  reported by the backend, rather than guessed from the names: every material
  lands in exactly one group, nothing has to be maintained when Geant4 adds
  one, and there is no "other" heap for everything the guesses missed.
==============================================================================}

unit uMaterials;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, ComCtrls, ExtCtrls, StdCtrls,
  Grids, ButtonPanel, StrUtils, uStrataEngine;

type

  { TMaterialsDlg }

  TMaterialsDlg = class(TForm)
    ButtonPanel: TButtonPanel;
    EditSearch: TEdit;
    GroupBoxDetails: TGroupBox;
    LabelAtoms: TLabel;
    LabelDensity: TLabel;
    LabelMatName: TLabel;
    LabelSearch: TLabel;
    PanelData: TPanel;
    PanelDetails: TPanel;
    PanelTop: TPanel;
    sgComposition: TStringGrid;
    SplitterData: TSplitter;
    TreeViewMaterials: TTreeView;
    procedure EditSearchChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TreeViewMaterialsDblClick(Sender: TObject);
    procedure TreeViewMaterialsSelectionChanged(Sender: TObject);
  private
    FEngine: TStrataEngine;             // asked what a material is made of
    FMaterials: TStrataMaterialArray;   // the catalogue, as Geant4 groups it
    FDefined: TStringList;              // what this session has defined
    function GroupCaption(AGroup: TStrataMaterialGroup): String;
  procedure ShowComposition(const AName: String);
    function GetSelectedMaterial: String;
    procedure Describe(ANode: TTreeNode);
    procedure Select(const AName: String);
  public
    // The catalogue to offer
    procedure SetCatalogue(AEngine: TStrataEngine;
      const AMaterials: TStrataMaterialArray; ADefined: TStrings);
    procedure LoadAndClassifyMaterials(const AFilter: String = '');
    // ACurrent is selected when the dialog opens, if it is still there
    function Execute(const ACurrent: String; out ASelected: String): Boolean;
  end;

var
  MaterialsDlg: TMaterialsDlg;

implementation

{$R *.lfm}

uses
  uMain, uSciRestorer;

const
  // Shown in this order, which is Geant4's own organization
  kGroupOrder: array[0..6] of TStrataMaterialGroup =
    (mgUnknown, mgElement, mgNist, mgHep, mgSpace, mgBio, mgUnknown);

{ TMaterialsDlg }

procedure TMaterialsDlg.FormCreate(Sender: TObject);
begin
  // Set up before the restorer runs, so a layout the user has sized wins
  sgComposition.FixedRows := 1;
  sgComposition.RowCount := 1;
  sgComposition.Cells[0, 0] := 'Element';
  sgComposition.Cells[1, 0] := 'Z';
  sgComposition.Cells[2, 0] := 'Mass %';
  sgComposition.Cells[3, 0] := 'Atom %';
  sgComposition.ColWidths[0] := 74;
  sgComposition.ColWidths[1] := 26;
  sgComposition.ColWidths[2] := 56;
  sgComposition.ColWidths[3] := 56;

  MainForm.StrataRestorer.RestoreForm(Self, 'MaterialsDlg', [svSize,svLocation,svState,svPanels,svGrids]);

  FDefined := TStringList.Create;
  FDefined.Sorted := True;
  FDefined.Duplicates := dupIgnore;
  Describe(nil);
end;

procedure TMaterialsDlg.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FDefined);
end;

function TMaterialsDlg.GroupCaption(AGroup: TStrataMaterialGroup): String;
begin
  case AGroup of
    mgElement: Result := 'Elements';
    mgNist: Result := 'NIST compounds';
    mgHep: Result := 'High energy physics and nuclear';
    mgSpace: Result := 'Space';
    mgBio: Result := 'Bio-chemical';
    else Result := 'Not grouped';
  end;
end;

procedure TMaterialsDlg.SetCatalogue(AEngine: TStrataEngine;
  const AMaterials: TStrataMaterialArray; ADefined: TStrings);
begin
  FEngine := AEngine;
  FMaterials := AMaterials;
  FDefined.Clear;
  if ADefined <> nil then FDefined.AddStrings(ADefined);
end;

// One node per material, under the group Geant4 puts it in
procedure TMaterialsDlg.LoadAndClassifyMaterials(const AFilter: String);
var
  group: array[0..High(kGroupOrder)] of TTreeNode;
  filter, matName: String;
  i, slot: Integer;
  known: TStringList;
begin
  filter := AnsiUpperCase(Trim(AFilter));
  known := TStringList.Create;
  TreeViewMaterials.Items.BeginUpdate;
  try
    known.Sorted := True;
    known.Duplicates := dupIgnore;
    TreeViewMaterials.Items.Clear;
    for i := 0 to High(kGroupOrder) do
      group[i] := nil;

    // Geant4's catalogue
    for i := 0 to High(FMaterials) do
    begin
      matName := FMaterials[i].Name;
      known.Add(matName);
      if (filter <> '') and (not ContainsText(matName, filter)) then Continue;

      slot := Ord(FMaterials[i].Group);
      if (slot < 1) or (slot > High(kGroupOrder) - 1) then slot := High(kGroupOrder);
      if group[slot] = nil then
        group[slot] := TreeViewMaterials.Items.Add(nil, GroupCaption(FMaterials[i].Group));
      TreeViewMaterials.Items.AddChild(group[slot], matName);
    end;

    // And what the session has built that Geant4 has never heard of
    for i := 0 to FDefined.Count - 1 do
    begin
      matName := FDefined[i];
      if known.IndexOf(matName) >= 0 then Continue;
      if (filter <> '') and (not ContainsText(matName, filter)) then Continue;
      if group[0] = nil then
        group[0] := TreeViewMaterials.Items.Add(nil, 'Defined in this session');
      TreeViewMaterials.Items.AddChild(group[0], matName);
    end;

    // Searching wants everything open; browsing wants the headings only
    for i := 0 to High(kGroupOrder) do
      if group[i] <> nil then group[i].Expanded := filter <> '';

    // The group nodes are built in display order, except Defined, at the top
    if (group[0] <> nil) and (group[0].Index <> 0) then group[0].Index := 0;
  finally
    TreeViewMaterials.Items.EndUpdate;
    known.Free;
  end;
  Describe(TreeViewMaterials.Selected);
end;

procedure TMaterialsDlg.Select(const AName: String);
var
  node: TTreeNode;
begin
  if Trim(AName) = '' then Exit;
  node := TreeViewMaterials.Items.FindNodeWithText(AName);
  if (node = nil) or (node.Parent = nil) then Exit;
  node.Parent.Expanded := True;
  TreeViewMaterials.Selected := node;
  node.MakeVisible;
end;

function TMaterialsDlg.Execute(const ACurrent: String; out ASelected: String): Boolean;
begin
  Result := False;
  ASelected := '';
  EditSearch.Text := '';
  LoadAndClassifyMaterials;
  Select(ACurrent);
  if ShowModal <> mrOk then Exit;

  ASelected := GetSelectedMaterial;
  Result := ASelected <> '';
end;

procedure TMaterialsDlg.EditSearchChange(Sender: TObject);
begin
  LoadAndClassifyMaterials(EditSearch.Text);
end;

procedure TMaterialsDlg.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MainForm.StrataRestorer.SaveForm(Self, 'MaterialsDlg', [svSize,svLocation,svState,svPanels,svGrids]);
end;

// A heading is not an answer, so only a material under one counts
function TMaterialsDlg.GetSelectedMaterial: String;
begin
  Result := '';
  if (TreeViewMaterials.Selected <> nil) and (TreeViewMaterials.Selected.Parent <> nil) then
    Result := TreeViewMaterials.Selected.Text;
end;

procedure TMaterialsDlg.Describe(ANode: TTreeNode);
var
  i: Integer;
  matName: String;
begin
  ButtonPanel.OKButton.Enabled := (ANode <> nil) and (ANode.Parent <> nil);
  if not ButtonPanel.OKButton.Enabled then
  begin
    LabelMatName.Caption := 'Material: -';
    LabelDensity.Caption := 'Density: -';
    ShowComposition('');
    Exit;
  end;

  matName := ANode.Text;
  LabelMatName.Caption := 'Material: ' + matName;
  LabelDensity.Caption := 'Density: -';
  if FDefined.IndexOf(matName) >= 0 then
    LabelDensity.Caption := 'Density: built in this session';

  // The density Geant4 would build it with
  for i := 0 to High(FMaterials) do
    if FMaterials[i].Name = matName then
    begin
      if FMaterials[i].Density > 0 then
        LabelDensity.Caption := Format('Density: %.6g g/cm3', [FMaterials[i].Density]);
      Break;
    end;

  ShowComposition(matName);
end;

// What the material is made of.  Reading a catalogue material builds it,
// which is what Geant4 does the moment it is used in a geometry, so
// looking through the list costs a little memory and nothing else
procedure TMaterialsDlg.ShowComposition(const AName: String);
var
  elements: TStrataElementArray;
  i: Integer;
  atoms: Double;
begin
  sgComposition.RowCount := 1;
  LabelAtoms.Caption := 'Atoms: -';
  if (FEngine = nil) or (AName = '') then Exit;

  elements := FEngine.MaterialComposition(AName);
  if Length(elements) = 0 then Exit;

  atoms := 0;
  sgComposition.RowCount := Length(elements) + 1;
  for i := 0 to High(elements) do
  begin
    // Geant4 names a NIST element by its symbol, so there is nothing to add
    if SameText(elements[i].Name, elements[i].Symbol) then
      sgComposition.Cells[0, i + 1] := elements[i].Symbol
    else
      sgComposition.Cells[0, i + 1] := Format('%s, %s', [elements[i].Symbol, elements[i].Name]);
    sgComposition.Cells[1, i + 1] := IntToStr(elements[i].Z);
    sgComposition.Cells[2, i + 1] := Format('%.4g', [100*elements[i].MassFraction]);
    sgComposition.Cells[3, i + 1] := Format('%.4g', [100*elements[i].AtomFraction]);
    atoms := atoms + elements[i].AtomDensity;
  end;
  LabelAtoms.Caption := Format('Atoms: %.4g per cm3', [atoms]);
end;

procedure TMaterialsDlg.TreeViewMaterialsSelectionChanged(Sender: TObject);
begin
  Describe(TreeViewMaterials.Selected);
end;

procedure TMaterialsDlg.TreeViewMaterialsDblClick(Sender: TObject);
begin
  if GetSelectedMaterial <> '' then ModalResult := mrOk;
end;

end.
