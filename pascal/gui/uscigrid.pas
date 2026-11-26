unit uSciGrid;

//==============================================================================
//  A TSciEdit that a TStringGrid can use as its cell editor
//
//  A grid does not read its editor's Text. It dispatches GM_SETVALUE and
//  GM_GETVALUE to it and reads the value back out of the message, so a control
//  that does not answer those is shown, typed into, and then ignored. This is
//  the same protocol TStringCellEditor implements, with only the parts a
//  value-and-unit box needs
//==============================================================================

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLType, Controls, Grids, uUnitParser, uSciEdit,
  uStrataConfig;

type

  { TSciGridEditor }

  TSciGridEditor = class(TSciEdit)
  private
    FGrid: TCustomGrid;
    FCol, FRow: Integer;
  protected
    procedure msg_SetGrid(var Msg: TGridMessage); message GM_SETGRID;
    procedure msg_GetGrid(var Msg: TGridMessage); message GM_GETGRID;
    procedure msg_SetValue(var Msg: TGridMessage); message GM_SETVALUE;
    procedure msg_GetValue(var Msg: TGridMessage); message GM_GETVALUE;
    procedure msg_SetPos(var Msg: TGridMessage); message GM_SETPOS;
    procedure msg_SelectAll(var Msg: TGridMessage); message GM_SELECTALL;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Grid: TCustomGrid read FGrid;
  end;

// Hands a grid the editor for one column, creating it on first use
function SciEditorFor(var AEditor: TSciGridEditor; AOwner: TComponent; AFamily: TUnitFamily): TSciGridEditor;

// Reads a cell that holds a value and a unit together, as '20 um'
function StrataParseQuantity(const AText: String; AFamily: TUnitFamily; out AValue: Double; out AUnit: String): Boolean;

// The same, but expressed in AUnit whatever unit the cell itself is written in
function StrataParseQuantityAs(const AText: String; AFamily: TUnitFamily; const AUnit: String; out AValue: Double): Boolean;

// The text to put in such a cell
function StrataQuantityText(AValue: Double; const AUnit: String): String;

// Frees the box StrataParseQuantity parses with
procedure StrataDoneParsing;

implementation

// The grid's key handling is protected, and the editor has to reach it for
// Return, Escape and the arrow keys to still move the selection
type
  TGridAccess = class(TCustomGrid);

// One box does all the parsing
var
  gParser: TSciEdit = nil;

constructor TSciGridEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // The same options every value-and-unit box in the window uses: the unit the
  // user typed is the unit that is kept. StrataLfmCheck enforces this for the
  // boxes on the form; this one is not on the form, so it is set here
  Options := [seoScientificNotation, seoKeepTypedUnits];
  BorderStyle := bsNone;
  AutoSize := False;
end;

procedure TSciGridEditor.msg_SetGrid(var Msg: TGridMessage);
begin
  FGrid := Msg.Grid;
  Msg.Options := EO_AUTOSIZE or EO_SELECTALL or EO_HOOKKEYPRESS or EO_HOOKKEYUP;
end;

procedure TSciGridEditor.msg_GetGrid(var Msg: TGridMessage);
begin
  Msg.Grid := FGrid;
  Msg.Options := EO_IMPLEMENTED;
end;

procedure TSciGridEditor.msg_SetValue(var Msg: TGridMessage);
begin
  // Whatever the cell holds, in the spelling the parser wants
  Text := StrataSciUnitSpelling(Msg.Value);
  SelStart := Length(Text);
end;

procedure TSciGridEditor.msg_GetValue(var Msg: TGridMessage);
begin
  Msg.Col := FCol;
  Msg.Row := FRow;
  // What goes back into the cell is what the box shows, so the unit the user
  // typed is the unit the cell keeps
  Msg.Value := Text;
end;

procedure TSciGridEditor.msg_SetPos(var Msg: TGridMessage);
begin
  FCol := Msg.Col;
  FRow := Msg.Row;
end;

procedure TSciGridEditor.msg_SelectAll(var Msg: TGridMessage);
begin
  SelectAll;
end;

procedure TSciGridEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FGrid = nil then Exit;
  // Only the keys that move or end the edit go to the grid. Everything else,
  // the unit text included, belongs to the box
  case Key of
    VK_UP, VK_DOWN, VK_RETURN, VK_ESCAPE, VK_TAB, VK_PRIOR, VK_NEXT:
      TGridAccess(FGrid).EditorKeyDown(Self, Key, Shift);
  end;
end;

function SciEditorFor(var AEditor: TSciGridEditor; AOwner: TComponent; AFamily: TUnitFamily): TSciGridEditor;
begin
  if AEditor = nil then
  begin
    AEditor := TSciGridEditor.Create(AOwner);
    AEditor.UnitFamily := AFamily;
  end;
  Result := AEditor;
end;

function StrataParseQuantity(const AText: String; AFamily: TUnitFamily;
  out AValue: Double; out AUnit: String): Boolean;
begin
  Result := False;
  if Trim(AText) = '' then Exit;

  if gParser = nil then
  begin
    gParser := TSciEdit.Create(nil);
    gParser.Options := [seoScientificNotation, seoKeepTypedUnits];
  end;

  gParser.UnitFamily := AFamily;
  gParser.Text := StrataSciUnitSpelling(AText);
  if (gParser.State <> sesValid) or (not gParser.HasValue) then Exit;

  AValue := gParser.Value;
  AUnit := StrataG4UnitSpelling(gParser.Units);
  Result := True;
end;

function StrataParseQuantityAs(const AText: String; AFamily: TUnitFamily; const AUnit: String; out AValue: Double): Boolean;
var
  ignoredUnit: String;
  dummy: Double;
begin
  Result := False;
  // Parsing first leaves gParser holding the cell, so the conversion below is
  // the editor's own and knows every unit it knows
  if not StrataParseQuantity(AText, AFamily, dummy, ignoredUnit) then Exit;
  try
    AValue := gParser.ValueAs[StrataSciUnitSpelling(Trim(AUnit))];
    Result := True;
  except
    on ESciEditError do Result := False;
  end;
end;


function StrataQuantityText(AValue: Double; const AUnit: String): String;
begin
  Result := Trim(StrataNumToText(AValue) + ' ' + StrataSciUnitSpelling(Trim(AUnit)));
end;

procedure StrataDoneParsing;
begin
  FreeAndNil(gParser);
end;

end.
