program StrataUnitsCheck;

//==============================================================================
//  What a value-and-unit box does to the unit the user typed
//
//  A TSciEdit can be created without a parent and still parse and format, so
//  this runs with no window and no window server, which is the only reason
//  the rule it checks can be tested at all. Build it with the LCL unit paths
//  and -k-framework -kUserNotifications.
//
//  The rule: a box must redisplay a value in the unit the user typed, whatever
//  the magnitude. seoAutoUnits breaks it in two ways that both reached the
//  saved configuration, so both are checked here as well as in StrataLfmCheck
//==============================================================================

{$mode objfpc}{$H+}

uses
  Interfaces, Classes, Math, SysUtils, TypInfo, CheckLst,
  uUnitParser, uSciEdit, uStrataConfig, uSciGrid;

var
  Failures: Integer = 0;
  gScratch: Double = 0;

procedure Check(ACondition: Boolean; const AWhat: String);
begin
  if ACondition then
    WriteLn(Format('%-52s ok', [AWhat]))
  else
  begin
    WriteLn(Format('%-52s FAILED', [AWhat]));
    Inc(Failures);
  end;
end;

// A box set up the way the GUI sets them up
function MakeEdit(AFamily: TUnitFamily): TSciEdit;
begin
  Result := TSciEdit.Create(nil);
  Result.UnitFamily := AFamily;
  Result.Options := [seoScientificNotation, seoKeepTypedUnits];
end;

// The same box with the option that caused the bug, to prove the check is
// testing something real rather than passing for its own reasons
function MakeAutoEdit(AFamily: TUnitFamily): TSciEdit;
begin
  Result := TSciEdit.Create(nil);
  Result.UnitFamily := AFamily;
  Result.Options := [seoAutoUnits, seoScientificNotation, seoKeepTypedUnits];
end;

procedure TypedUnitSurvives;
var
  e: TSciEdit;
begin
  e := MakeEdit(ufLength);
  try
    e.Text := '20 um';
    Check(e.Units = 'um', 'typing "20 um" leaves the unit as um');
    Check(Abs(e.Value - 20) < 1e-12, '  and the value as 20');

    // Zero is the case that bit the lower edge of every spectrum: with
    // auto-prefixing a zero has no magnitude to choose a prefix from
    e.Text := '0 um';
    Check(e.Units = 'um', 'typing "0 um" leaves the unit as um');

    // And the case that bit the upper edge: a value large enough in the typed
    // unit that a prefix step looks tidier
    e.Text := '20000 um';
    Check(e.Units = 'um', 'typing "20000 um" leaves the unit as um');
    Check(Abs(e.Value - 20000) < 1e-9, '  and the value as 20000');
  finally
    e.Free;
  end;
end;

procedure WritingBackKeepsTheUnit;
var
  e: TSciEdit;
begin
  // This is what FillH1Setup does after a run or after Apply: it puts the
  // backend's number back into the box. It must not change the unit
  e := MakeEdit(ufLength);
  try
    e.Text := '20 um';
    e.ValueAs['um'] := 20000;
    Check(e.Units = 'um', 'writing 20000 um back leaves the unit as um');
    Check(Abs(e.ValueAs['um'] - 20000) < 1e-9, '  and reads back as 20000 um');

    e.ValueAs['um'] := 0;
    Check(e.Units = 'um', 'writing 0 um back leaves the unit as um');
  finally
    e.Free;
  end;
end;

procedure AutoUnitsIsWhatBroke;
var
  e: TSciEdit;
begin
  e := MakeAutoEdit(ufLength);
  try
    e.Text := '0 um';
    Check(e.Units <> 'um',
      'seoAutoUnits does lose the unit of a zero (so the rule is needed)');
    e.Text := '20 um';
    e.ValueAs['um'] := 20000;
    Check(e.Units <> 'um',
      'seoAutoUnits does change um to mm on write (so the rule is needed)');
  finally
    e.Free;
  end;
end;

// Every family the GUI uses, entered the way the user would type it
//
// The two vocabularies differ: the editor's parser wants the caret in a
// compound unit and Geant4 does not, so text going in is passed through
// StrataSciUnitSpelling and the unit coming out through StrataG4UnitSpelling.
// Anything typed in either spelling therefore has to work
procedure FamiliesAcceptBothSpellings;

  procedure One(AFamily: TUnitFamily; const ATyped, AG4Unit: String);
  var
    e: TSciEdit;
  begin
    e := MakeEdit(AFamily);
    try
      e.Text := StrataSciUnitSpelling(ATyped);
      Check((e.State = sesValid)
            and (StrataG4UnitSpelling(e.Units) = AG4Unit),
        Format('"%s" parses and reaches a command as %s', [ATyped, AG4Unit]));
    finally
      e.Free;
    end;
  end;

begin
  One(ufLength,        '500 nm',       'nm');
  One(ufLength,        '2.5 cm',       'cm');
  One(ufEnergy,        '1 MeV',        'MeV');
  One(ufEnergy,        '10 keV',       'keV');
  // Both spellings of the one compound unit the window uses
  One(ufDensity,       '2.32 g/cm3',   'g/cm3');
  One(ufDensity,       '2.32 g/cm^3',  'g/cm3');
  One(ufDensity,       '2320 kg/m3',   'kg/m3');
  One(ufMagneticField, '1.5 T',        'T');
  One(ufMagneticField, '50 G',         'G');
  // The detector: a scattering angle in degrees, and a solid angle whose
  // family the parser has none of, so it goes in as a custom unit
  One(ufAngle,         '165 deg',      'deg');
  One(ufAngle,         '0 deg',        'deg');
end;

// The detector boxes read back in the unit the command wants, which is not
// always the one they were typed in
procedure DetectorBoxesConvert;

  procedure One(const AText, AReadAs: String; AFamily: TUnitFamily;
                const ACustom: String; AExpected: Double);
  var
    e: TSciEdit;
    v: Double;
    ok: Boolean;
  begin
    e := TSciEdit.Create(nil);
    try
      e.UnitFamily := AFamily;
      if ACustom <> '' then e.CustomUnits := ACustom;
      e.Text := AText;
      ok := False;
      v := 0;
      try
        v := e.ValueAs[AReadAs];
        ok := True;
      except
        on ESciEditError do ;
      end;
      Check(ok and (Abs(v - AExpected) <= 1e-9*Abs(AExpected) + 1e-12),
        Format('"%s" read as %s is %.10g', [AText, AReadAs, v]));
    finally
      e.Free;
    end;
  end;

begin
  One('165 deg', 'deg', ufAngle, '', 165);
  One('165 deg', 'rad', ufAngle, '', 165*Pi/180);
  One('0 deg',   'deg', ufAngle, '', 0);
  One('-7 deg',  'deg', ufAngle, '', -7);
  // The steradian is dimensionless, so the family is ufCustom and the
  // millisteradian is the SI prefix doing the work
  One('1 msr',   'msr', ufCustom, 'sr', 1);
  One('1 msr',   'sr',  ufCustom, 'sr', 1e-3);
  One('2.4 msr', 'sr',  ufCustom, 'sr', 2.4e-3);
  One('1 sr',    'msr', ufCustom, 'sr', 1000);
  One('15 keV',  'keV', ufEnergy, '', 15);
  One('15 keV',  'MeV', ufEnergy, '', 0.015);
end;

{ Refilling a TCheckListBox loses every tick

  This is the behaviour the optional-physics bug rested on.  The window
  fills clbOptionalPhysics from the backend with FillPhysicsNames, which
  clears the list first, and clearing resets the check state -- so every
  time the catalogue is rebuilt, which happens when a session opens, the
  user's selection silently empties.  ConfigFromForm then rebuilt
  TStrataConfig.OptionalPhysics from the unticked list and the selection
  was gone from the configuration too.

  TMainForm.ShowOptionalPhysics exists to put the ticks back, and is
  called at the end of PopulateCatalogues for that reason.  If a future
  LCL preserved the ticks across a refill this check would start failing,
  which is the right moment to find out. }
procedure RefillingAChecklistLosesTicks;
var
  box: TCheckListBox;
begin
  box := TCheckListBox.Create(nil);
  try
    box.Items.CommaText := 'elastic,binary,stopping';
    box.Checked[1] := True;
    Check(box.Checked[1], 'a ticked entry reads back as ticked');
    // What FillPhysicsNames does: clear, then add the names again
    box.Items.Clear;
    box.Items.CommaText := 'elastic,binary,stopping';
    Check(not box.Checked[1],
      'and refilling the list clears it, which is why the window has to '
      + 'tick them again from the configuration');
  finally
    box.Free;
  end;
end;

// Every property a .lfm sets on a TSciEdit has to exist
//
// A .lfm is read at run time, so a property the designer never had (or
// one borrowed from a component that does have it) compiles cleanly and
// then throws on first launch.  TSciEdit has no MinValue and no MaxValue,
// which is the mistake this catches.  Only TSciEdit is checked here,
// because it is the component whose published list is not common knowledge.
// The window and every frame are read, since the boxes live in all of them.
procedure SciEditPropertiesExist;
const
  kCandidates: array[0..3] of String = (
    '../gui/', 'pascal/gui/', '../../gui/', 'gui/');
var
  lfm: TStringList;
  i, j, c, files: Integer;
  line, name, head, dir: String;
  inSci: Boolean;
  found: TSearchRec;
begin
  dir := '';
  for i := Low(kCandidates) to High(kCandidates) do
    if FileExists(kCandidates[i] + 'umain.lfm') then
    begin
      dir := kCandidates[i];
      Break;
    end;
  if dir = '' then
  begin
    Check(False, 'cannot find the gui directory to read');
    Exit;
  end;

  c := 0;
  files := 0;
  lfm := TStringList.Create;
  try
    if FindFirst(dir + '*.lfm', faAnyFile, found) = 0 then
    try
      repeat
        Inc(files);
        lfm.LoadFromFile(dir + found.Name);
        inSci := False;
        for i := 0 to lfm.Count - 1 do
        begin
          line := Trim(lfm[i]);
          if Copy(line, 1, 7) = 'object ' then
            inSci := Pos(': TSciEdit', line) > 0
          else if (line = 'end') and inSci then
            inSci := False
          else if inSci then
          begin
            j := Pos(' = ', line);
            if j > 0 then
            begin
              name := Copy(line, 1, j - 1);
              // A sub-property is reached through the one named first
              head := name;
              j := Pos('.', head);
              if j > 0 then head := Copy(head, 1, j - 1);
              if GetPropInfo(TSciEdit, head) = nil then
                Check(False, Format('%s line %d sets %s, which TSciEdit '
                  + 'has no published property for', [found.Name, i + 1, name]))
              else
                Inc(c);
            end;
          end;
        end;
      until FindNext(found) <> 0;
    finally
      FindClose(found);
    end;
  finally
    lfm.Free;
  end;
  Check(c > 0, Format('%d TSciEdit properties in %d .lfm files all exist', [c, files]));
end;

// The two spellings have to be inverses of each other, and applying either
// twice has to change nothing
procedure SpellingRoundTrips;

  procedure One(const ATyped, AExpectedG4: String);
  var
    sci: String;
  begin
    sci := StrataSciUnitSpelling(ATyped);
    Check(StrataG4UnitSpelling(sci) = AExpectedG4,
      Format('"%s" -> "%s" -> "%s"', [ATyped, sci, AExpectedG4]));
    Check(StrataSciUnitSpelling(sci) = sci,
      Format('  and "%s" is already in editor spelling', [sci]));
  end;

begin
  One('2.32 g/cm3', '2.32 g/cm3');
  One('20 um', '20 um');
  // Scientific notation must survive: the e has a digit after it but is not
  // a unit, so it must not collect a caret
  One('1.5e-3 kg/m3', '1.5e-3 kg/m3');
  One('1e3 m', '1e3 m');
end;

// A grid cell holds the value and the unit in one string, so reading it back
// has to give exactly what was put in, which is what makes the layer and
// voxel grids safe to round-trip through a configuration
procedure QuantityCellsRoundTrip;

  procedure One(AFamily: TUnitFamily; const ATyped: String;
    AExpectValue: Double; const AExpectUnit: String);
  var
    v: Double;
    u, text: String;
  begin
    v := 0;
    u := '';
    if not StrataParseQuantity(ATyped, AFamily, v, u) then
    begin
      Check(False, Format('"%s" is read as a quantity', [ATyped]));
      Exit;
    end;
    Check((Abs(v - AExpectValue) < 1e-9) and (u = AExpectUnit),
      Format('"%s" reads as %s %s', [ATyped, StrataNumToText(v), u]));

    // And what the window would write back into the cell reads the same again
    text := StrataQuantityText(v, u);
    v := 0;
    u := '';
    Check(StrataParseQuantity(text, AFamily, v, u)
          and (Abs(v - AExpectValue) < 1e-9) and (u = AExpectUnit),
      Format('  and "%s" survives a round trip', [text]));
  end;

  procedure Rejects(AFamily: TUnitFamily; const ATyped: String);
  var
    v: Double;
    u: String;
  begin
    Check(not StrataParseQuantity(ATyped, AFamily, v, u),
      Format('"%s" is rejected', [ATyped]));
  end;

begin
  One(ufLength,  '20 um',        20,    'um');
  One(ufLength,  '500 nm',       500,   'nm');
  One(ufLength,  '0 um',         0,     'um');
  One(ufLength,  '2.5 cm',       2.5,   'cm');
  One(ufDensity, '2.32 g/cm3',   2.32,  'g/cm3');
  One(ufDensity, '2.32 g/cm^3',  2.32,  'g/cm3');
  One(ufMagneticField, '1.5 T',  1.5,   'T');

  // An empty cell means "not given", which the layer grid uses for a density
  // that should stay at the material's own
  Rejects(ufLength, '');
  Rejects(ufLength, '   ');
  // And a unit from the wrong family is not silently taken
  Rejects(ufLength, '2.32 g/cm3');
  Rejects(ufDensity, '20 um');
end;

// The voxel grid sends one unit for a whole row, so a cell written in any
// other unit has to be converted into it exactly
procedure RowConvertsToOneUnit;

  procedure One(const ATyped, AInto: String; AExpected: Double);
  var
    v: Double;
    ok: Boolean;
  begin
    v := -1;
    // The test is computed before the message, because the order in which
    // arguments are evaluated is not defined and the message reports v
    ok := StrataParseQuantityAs(ATyped, ufLength, AInto, v)
          and (Abs(v - AExpected) < 1e-9 * Max(1, Abs(AExpected)));
    Check(ok, Format('"%s" is %s %s (wanted %s)',
      [ATyped, StrataNumToText(v), AInto, StrataNumToText(AExpected)]));
  end;

begin
  // What the z cell is written in is what the other two are converted to
  One('1 mm',    'um', 1000);
  One('500 nm',  'um', 0.5);
  One('2.5 cm',  'mm', 25);
  One('0 nm',    'um', 0);
  One('1 um',    'um', 1);
  // Units beyond the five the window used to list, which is the point of
  // converting with the editor rather than a table
  One('1 m',     'cm', 100);
  One('1 in',    'mm', 25.4);

  // A cell in the wrong family cannot be converted into a length
  Check(not StrataParseQuantityAs('2.32 g/cm3', ufLength, 'um', gScratch),
    '"2.32 g/cm3" will not convert to um');
end;

// A cell is read in the reference unit for its quantity (millimetres for a
// length) which is the common scale the problem's own unit is chosen on.
// The editor does the conversion, so any unit it understands may be typed
procedure CellsReadInTheReferenceUnit;

  procedure One(const ATyped: String; AFamily: TUnitFamily;
    AQuantity: TStrataQuantity; AExpected: Double);
  var
    v: Double;
    ok: Boolean;
  begin
    v := -1;
    ok := StrataParseQuantityAs(ATyped, AFamily,
            StrataReferenceUnit(AQuantity), v)
          and (Abs(v - AExpected) < 1e-9 * Max(1, Abs(AExpected)));
    Check(ok, Format('"%s" reads as %s %s (wanted %s)',
      [ATyped, StrataNumToText(v), StrataReferenceUnit(AQuantity),
       StrataNumToText(AExpected)]));
  end;

begin
  One('20 um',       ufLength,  sqLength,  0.02);
  One('500 nm',      ufLength,  sqLength,  5e-4);
  One('2.5 cm',      ufLength,  sqLength,  25);
  One('2 m',         ufLength,  sqLength,  2000);
  // Including units Geant4 has never heard of: it never sees them, because
  // what it is sent is the problem's unit and that is always one it takes
  One('1 in',        ufLength,  sqLength,  25.4);
  One('5 dm',        ufLength,  sqLength,  500);
  One('10 keV',      ufEnergy,  sqEnergy,  1e-2);
  One('2.32 g/cm3',  ufDensity, sqDensity, 2.32);
  One('2.32 g/cm^3', ufDensity, sqDensity, 2.32);
  One('2320 kg/m3',  ufDensity, sqDensity, 2.32);
  One('1.5 T',       ufMagneticField, sqField, 1.5);
  One('50 G',        ufMagneticField, sqField, 0.005);
end;

begin
  CellsReadInTheReferenceUnit;
  RowConvertsToOneUnit;
  QuantityCellsRoundTrip;
  TypedUnitSurvives;
  WritingBackKeepsTheUnit;
  AutoUnitsIsWhatBroke;
  FamiliesAcceptBothSpellings;
  DetectorBoxesConvert;
  SciEditPropertiesExist;
  RefillingAChecklistLosesTicks;
  SpellingRoundTrips;
  StrataDoneParsing;

  WriteLn;
  if Failures = 0 then
    WriteLn('PASSED (0 failures)')
  else
    WriteLn(Format('FAILED (%d failures)', [Failures]));
  Halt(Ord(Failures <> 0));
end.
