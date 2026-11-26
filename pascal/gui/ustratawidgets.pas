unit uStrataWidgets;

// Value-and-unit helpers shared by every page that reads or writes a quantity

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uSciEdit, uUnitParser, uStrataConfig, uStrataEngine, uSciGrid;

var
  // Geant4 parses numbers with a '.' whatever the user's locale is
  G4Fmt: TFormatSettings;

function SciValid(AEdit: TSciEdit): Boolean;

// The value in one particular unit
function ReadInUnit(AEdit: TSciEdit; const AUnit: String; ADefault: Double): Double;

// A box in the quantity's reference unit, which is the common scale the
// problem's own unit is chosen on
function ReadRef(AEdit: TSciEdit; AQuantity: TStrataQuantity; ADefault: Double): Double;

// The same for a grid cell
function CellRef(const AText: String; AFamily: TUnitFamily; AQuantity: TStrataQuantity; out AValue: Double): Boolean;

// The unit that the backend knows
function OfferedUnit(AQuantity: TStrataQuantity; const ATyped: String; ATypedValue, AReferenceValue: Double): String;

// A spectrum axis is whatever its histogram measures, and the backend says which is
function AxisQuantity(AAxis: TStrataAxisKind): TStrataQuantity;

function AxisFamily(AAxis: TStrataAxisKind): TUnitFamily;

function AxisHasUnit(AAxis: TStrataAxisKind): Boolean;

// What the user would have to read to know what to type
function AxisName(AAxis: TStrataAxisKind): String;

// What the saved configuration keeps
function ReadAsTyped(AEdit: TSciEdit; AQuantity: TStrataQuantity; out AValue: Double; out AUnit: String): Boolean;

// The same for a grid cell
function CellAsTyped(const AText: String; AFamily: TUnitFamily; AQuantity: TStrataQuantity; out AValue: Double; out AUnit: String): Boolean;

// Puts a value into an editor, preferring the unit it was stored with
procedure SetQuantity(AEdit: TSciEdit; AValue: Double; const AUnit, AFallbackUnit: String);

// The two words a Geant4 boolean command takes
function G4Bool(AValue: Boolean): String;

// Format a number the way the Geant4 command line expects it
function NumToG4(AValue: Double): String;

// A reference value written out in the problem's unit
function InProblemUnit(AReference: Double; AQuantity: TStrataQuantity; const AUnit: String): String;

implementation

function SciValid(AEdit: TSciEdit): Boolean;
begin
  Result := (AEdit <> nil) and AEdit.HasValue and (AEdit.State = sesValid);
end;

// The value in one particular unit
function ReadInUnit(AEdit: TSciEdit; const AUnit: String; ADefault: Double): Double;
begin
  Result := ADefault;
  if not SciValid(AEdit) then Exit;
  try
    Result := AEdit.ValueAs[AUnit];
  except
    on ESciEditError do Result := ADefault;
  end;
end;

// A box in the quantity's reference unit, which is the common scale the
// problem's own unit is chosen on
function ReadRef(AEdit: TSciEdit; AQuantity: TStrataQuantity; ADefault: Double): Double;
begin
  Result := ReadInUnit(AEdit,
              StrataSciUnitSpelling(StrataReferenceUnit(AQuantity)), ADefault);
end;

// The same for a grid cell
function CellRef(const AText: String; AFamily: TUnitFamily; AQuantity: TStrataQuantity; out AValue: Double): Boolean;
begin
  Result := StrataParseQuantityAs(AText, AFamily,
              StrataReferenceUnit(AQuantity), AValue);
end;


// The unit that the backend knows
function OfferedUnit(AQuantity: TStrataQuantity; const ATyped: String; ATypedValue, AReferenceValue: Double): String;
begin
  Result := StrataG4UnitSpelling(ATyped);
  if StrataUnitFactor(AQuantity, Result) > 0 then Exit;
  if (ATypedValue <> 0) and (AReferenceValue <> 0) then
    Result := StrataProblemUnit(AQuantity, [AReferenceValue/ATypedValue])
  else
    Result := StrataReferenceUnit(AQuantity);
end;

// A spectrum axis is whatever its histogram measures, and the backend says which is
function AxisQuantity(AAxis: TStrataAxisKind): TStrataQuantity;
begin
  case AAxis of
    akLength: Result := sqLength;
    akEnergy: Result := sqEnergy;
    akFwdAngle, akBackAngle: Result := sqAngle;
  else
    Result := sqLength;          // akNone carries no unit at all
  end;
end;

function AxisFamily(AAxis: TStrataAxisKind): TUnitFamily;
begin
  case AAxis of
    akLength: Result := ufLength;
    akEnergy: Result := ufEnergy;
    akFwdAngle, akBackAngle: Result := ufAngle;
  else
    Result := ufNone;            // a dimensionless axis is a bare number
  end;
end;

function AxisHasUnit(AAxis: TStrataAxisKind): Boolean;
begin
  Result := AAxis in [akLength, akEnergy, akFwdAngle, akBackAngle];
end;

// What the user would have to read to know what to type
function AxisName(AAxis: TStrataAxisKind): String;
begin
  case AAxis of
    akLength: Result := 'a length';
    akEnergy: Result := 'an energy';
    akFwdAngle, akBackAngle: Result := 'an angle';
  else
    Result := 'a plain number';
  end;
end;

// What the saved configuration keeps
function ReadAsTyped(AEdit: TSciEdit; AQuantity: TStrataQuantity; out AValue: Double; out AUnit: String): Boolean;
begin
  Result := False;
  AValue := 0;
  AUnit := StrataReferenceUnit(AQuantity);
  if not SciValid(AEdit) then Exit;

  try
    AUnit := OfferedUnit(AQuantity, AEdit.Units, AEdit.Value,
               AEdit.ValueAs[StrataSciUnitSpelling(StrataReferenceUnit(AQuantity))]);
    AValue := AEdit.ValueAs[StrataSciUnitSpelling(AUnit)];
    Result := True;
  except
    on ESciEditError do Result := False;
  end;
end;

// The same for a grid cell
function CellAsTyped(const AText: String; AFamily: TUnitFamily; AQuantity: TStrataQuantity; out AValue: Double; out AUnit: String): Boolean;
var
  typed: String;
  reference: Double;
begin
  AUnit := StrataReferenceUnit(AQuantity);
  Result := StrataParseQuantity(AText, AFamily, AValue, typed);
  if not Result then Exit;
  if StrataUnitFactor(AQuantity, typed) > 0 then
    AUnit := typed
  else
  begin
    Result := StrataParseQuantityAs(AText, AFamily, AUnit, reference);
    if not Result then Exit;
    AUnit := OfferedUnit(AQuantity, typed, AValue, reference);
    Result := StrataParseQuantityAs(AText, AFamily, AUnit, AValue);
  end;
end;

// Puts a value into an editor, preferring the unit it was stored with
procedure SetQuantity(AEdit: TSciEdit; AValue: Double; const AUnit, AFallbackUnit: String);
var
  u: String;
begin
  if AEdit = nil then Exit;
  u := Trim(AUnit);
  if u = '' then u := AFallbackUnit;
  if u <> '' then
    try
      AEdit.ValueAs[u] := AValue;
      Exit;
    except
      on ESciEditError do ;
    end;
  if AFallbackUnit <> '' then
    try
      AEdit.ValueAs[AFallbackUnit] := AValue;
      Exit;
    except
      on ESciEditError do ;
    end;
  AEdit.Text := FloatToStrF(AValue, ffGeneral, 7, 0, G4Fmt);
end;

// The two words a Geant4 boolean command takes
function G4Bool(AValue: Boolean): String;
begin
  if AValue then Result := 'true' else Result := 'false';
end;

// Format a number the way the Geant4 command line expects it
function NumToG4(AValue: Double): String;
begin
  Result := FloatToStrF(AValue, ffGeneral, 7, 0, G4Fmt);
end;

// A reference value written out in the problem's unit
function InProblemUnit(AReference: Double; AQuantity: TStrataQuantity; const AUnit: String): String;
var
  factor: Double;
begin
  factor := StrataUnitFactor(AQuantity, AUnit);
  if factor <= 0 then factor := 1;
  Result := NumToG4(AReference/factor);
end;

initialization
  G4Fmt := DefaultFormatSettings;
  G4Fmt.DecimalSeparator := '.';
  G4Fmt.ThousandSeparator := #0;

end.
