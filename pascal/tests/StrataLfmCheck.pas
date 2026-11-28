{==============================================================================
  StrataLfmCheck.pas: static consistency check between each .lfm and its .pas.

  A .lfm is only validated when the form is streamed at run time, so a
  component the designer knows about but the unit does not (or an event
  handler whose method was renamed) produces a clean compile and a crash on
  first launch.  This program reads both files as text and checks that:

    * every "object Name: TClass" in the .lfm has a published field of the
      same name in the form class, declared with the same class;
    * every "OnSomething = Handler" names a method the form declares;
    * every published field of a component type appears in the .lfm, so the
      code cannot reference a control the designer never created;
    * every frame a form embeds is one of the units checked here, and the
      form's state routine calls the frame's.

  The main window and each frame are checked as a pair, listed in Checked.

  It is plain console Free Pascal: no LCL, no widgetset, nothing that needs a
  display.  (Instantiating the form would be a stronger check, but TForm
  cannot be constructed on a machine without a window server, even
  TForm.CreateNew raises EDivByZero when the screen metrics are all zero.)

  Usage: StrataLfmCheck [path-to-gui-directory]
==============================================================================}

program StrataLfmCheck;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, StrUtils;

var
  Failures: Integer = 0;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAILED  ', AMessage);
  Inc(Failures);
end;

procedure Note(const AMessage: string);
begin
  WriteLn('        ', AMessage);
end;

{ Splits "name: TClass" into its two halves. }
function SplitDecl(const AText: string; out AName, AClass: string): Boolean;
var
  p: Integer;
begin
  p := Pos(':', AText);
  Result := p > 0;
  if not Result then Exit;
  AName := Trim(Copy(AText, 1, p - 1));
  AClass := Trim(Copy(AText, p + 1, MaxInt));
  if (AClass <> '') and (AClass[Length(AClass)] = ';') then
    SetLength(AClass, Length(AClass) - 1);
  Result := (AName <> '') and (AClass <> '');
end;

{ Reads the .lfm: component declarations into AComponents as name=class, and
  every event-handler value into AHandlers. }
procedure ParseLfm(const AFileName: string; AComponents, AHandlers, AInlines: TStrings);
var
  lines: TStringList;
  i, eq, indent, partsIndent: Integer;
  line, rest, name, cls, prop, value: string;
begin
  lines := TStringList.Create;
  try
    lines.LoadFromFile(AFileName);
    partsIndent := -1;
    for i := 0 to lines.Count - 1 do
    begin
      line := Trim(lines[i]);
      if line = '' then Continue;
      indent := Length(lines[i]) - Length(TrimLeft(lines[i]));
      if (partsIndent >= 0) and (indent <= partsIndent) then partsIndent := -1;

      { The gutter parts the IDE writes inside a SynEdit are the editor's own }
      if (partsIndent >= 0) and (StartsStr('object ', line) or StartsStr('inline ', line)) then
        Continue;

      if StartsStr('object ', line) then
      begin
        rest := Trim(Copy(line, Length('object ') + 1, MaxInt));
        if SplitDecl(rest, name, cls) then
        begin
          AComponents.Values[name] := cls;
          if cls = 'TSynEdit' then partsIndent := indent;
        end;
        Continue;
      end;

      { A frame placed on a form; what is inside it belongs to the frame.  The
        IDE writes a SynEdit as inline too, and that one is no frame }
      if StartsStr('inline ', line) then
      begin
        rest := Trim(Copy(line, Length('inline ') + 1, MaxInt));
        if SplitDecl(rest, name, cls) then
        begin
          AComponents.Values[name] := cls;
          if cls = 'TSynEdit' then
            partsIndent := indent
          else
            AInlines.Values[name] := cls;
        end;
        Continue;
      end;

      eq := Pos('=', line);
      if eq > 1 then
      begin
        prop := Trim(Copy(line, 1, eq - 1));
        value := Trim(Copy(line, eq + 1, MaxInt));
        { Event handlers are the only properties whose value is a bare
          identifier and whose name starts with On. }
        if StartsStr('On', prop) and (value <> '')
           and (value[1] in ['A'..'Z', 'a'..'z', '_']) then
          AHandlers.Add(prop + '=' + value);
      end;
    end;
  finally
    lines.Free;
  end;
end;

{ Reads the published section of the form class: component fields into
  AFields as name=class, declared method names into AMethods. }
{ How many parentheses a line opens and does not close.  A wrapped
  procedure declaration ends with a semicolon on every line (that is the
  parameter separator) so the brackets are what says where it stops. }
function ParenBalance(const ALine: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to Length(ALine) do
    if ALine[i] = '(' then Inc(Result)
    else if ALine[i] = ')' then Dec(Result);
end;

procedure ParsePas(const AFileName, AClass: string; AFields, AMethods: TStrings);
var
  lines: TStringList;
  i, p: Integer;
  line, name, cls, lower: string;
  inClass, inPublished, inDecl: Boolean;
  depth: Integer;
begin
  lines := TStringList.Create;
  try
    lines.LoadFromFile(AFileName);
    inClass := False;
    inPublished := False;
    inDecl := False;
    depth := 0;
    for i := 0 to lines.Count - 1 do
    begin
      line := Trim(lines[i]);
      lower := LowerCase(line);

      { A procedure declaration may be wrapped over several lines.  Its
        continuation looks like a field ("var Editor: TWinControl);")
        so skip to the end of the declaration before reading anything. }
      if inDecl then
      begin
        depth := depth + ParenBalance(line);
        if depth <= 0 then inDecl := False;
        Continue;
      end;

      if not inClass then
      begin
        if StartsStr(AClass + ' = class(', line) then
        begin
          inClass := True;
          inPublished := True;   { the default section of a published class }
        end;
        Continue;
      end;

      if (lower = 'private') or (lower = 'protected') or (lower = 'public') then
      begin
        inPublished := False;
        Continue;
      end;
      if lower = 'published' then
      begin
        inPublished := True;
        Continue;
      end;
      if lower = 'end;' then
        Break;

      if not inPublished then
      begin
        { still collect methods: handlers may be declared anywhere }
        if StartsStr('procedure ', line) then
        begin
          name := Trim(Copy(line, Length('procedure ') + 1, MaxInt));
          p := Pos('(', name);
          if p > 0 then name := Trim(Copy(name, 1, p - 1));
          if name <> '' then AMethods.Add(name);
          depth := ParenBalance(line);
          inDecl := depth > 0;
        end;
        Continue;
      end;

      if StartsStr('procedure ', line) then
      begin
        name := Trim(Copy(line, Length('procedure ') + 1, MaxInt));
        p := Pos('(', name);
        if p > 0 then name := Trim(Copy(name, 1, p - 1));
        if name <> '' then AMethods.Add(name);
        depth := ParenBalance(line);
        inDecl := depth > 0;
        Continue;
      end;

      if (Pos(':', line) > 0) and EndsStr(';', line)
         and (not StartsStr('//', line)) and (not StartsStr('{', line)) then
        if SplitDecl(line, name, cls) then
          if StartsStr('T', cls) then
            AFields.Values[name] := cls;
    end;
  finally
    lines.Free;
  end;
end;

{ --- 4. every control that can be operated is governed in one place ------

  A control whose Enabled is never set stays on for the whole session, which
  is how a window comes to offer things the kernel will refuse.  The rule is
  that the state routine (UpdateControlState on the window, UpdateState on a
  frame) assigns Enabled for every interactive component --
  either on the component, or, when it carries an Action, on that action,
  because the LCL lets the action drive Enabled and overwrites whatever the
  control was given.  The exceptions are listed here rather than left
  implicit: the read-only views, and the few commands that touch nothing but
  a file or this window. }

procedure CheckStateCoverage(const ALfm, APas, AClass, AState: string; AComponents: TStrings);
const
  InteractiveClasses: array[0..18] of string = (
    'TButton', 'TSpeedButton', 'TBitBtn', 'TComboBox', 'TEdit', 'TSpinEdit',
    'TSciEdit', 'TCheckBox', 'TRadioButton', 'TStringGrid', 'TCheckListBox',
    'TListBox', 'TMemo', 'TTrackBar', 'TAction',
    { these three were interactive all along and went unchecked }
    'TBCTrackbarUpdown', 'TFileOpen', 'TFileSaveAs',
    'TSynEdit');

  AlwaysEnabled: array[0..27] of string = (
    'mLog',                { the log is a view, not a control  }
    'sgSummary',           { results table, read only          }
    'sgVoxels',            { dose table, read only             }
    'lbDefinedMaterials',  { what exists already, read only    }
    'actAbout',
    'actClearLog',         { empties the view                  }
    'btnClearLog',
    'btnSaveLog',          { writes the view to a file         }
    'actSaveConfig',       { writes the pages to a file        }
    'actOptions',          { where the engine is configured,   }
                           { so it cannot depend on the engine }
    'actTerminal',         { a shell of its own, it neither    }
                           { reads nor writes the session      }
    'actSaveConfigAs',     { these three only write a file     }
    'actExportMacro',
    'actSaveLog',
    'actSaveMacro',        { the macro editor's file and log }
    'actSaveMacroAs',      { commands, as for the panels       }
    'mEdLog',
    'mEdHelp',
    'actEdClearLog',
    'btnEdClearLog',
    'actEdSaveLog',
    'btnEdSaveLog',
    'actEditUndo',         { the edit commands act on whatever }
    'actEditRedo',         { control has the focus             }
    'actEditCut',
    'actEditCopy',
    'actEditPaste',
    'actEditSelectAll');

  function IsInteractive(const AClass: string): Boolean;
  var
    k: Integer;
  begin
    Result := False;
    for k := Low(InteractiveClasses) to High(InteractiveClasses) do
      if AClass = InteractiveClasses[k] then Exit(True);
  end;

  function IsAlwaysEnabled(const AName: string): Boolean;
  var
    k: Integer;
  begin
    Result := False;
    for k := Low(AlwaysEnabled) to High(AlwaysEnabled) do
      if AName = AlwaysEnabled[k] then Exit(True);
  end;

  { name=action for every designed component that carries one }
  procedure ParseActions(AActions: TStrings);
  var
    lines: TStringList;
    k: Integer;
    line, current, nm, cl: string;
  begin
    current := '';
    lines := TStringList.Create;
    try
      lines.LoadFromFile(ALfm);
      for k := 0 to lines.Count - 1 do
      begin
        line := Trim(lines[k]);
        if StartsStr('object ', line) then
        begin
          if SplitDecl(Copy(line, Length('object ') + 1, MaxInt), nm, cl) then
            current := nm;
        end
        else if StartsStr('Action = ', line) and (current <> '') then
          AActions.Values[current] :=
            Trim(Copy(line, Length('Action = ') + 1, MaxInt));
      end;
    finally
      lines.Free;
    end;
  end;

  { everything assigned <name>.Enabled := inside the state routine }
  procedure ParseGoverned(AGoverned, ADuplicates: TStrings);
  var
    lines: TStringList;
    k, dot: Integer;
    line, nm: string;
    inside: Boolean;
  begin
    inside := False;
    lines := TStringList.Create;
    try
      lines.LoadFromFile(APas);
      for k := 0 to lines.Count - 1 do
      begin
        line := lines[k];
        if (AState <> '')
           and (StartsStr('procedure ' + AClass + '.' + AState + ';', line)
                or StartsStr('procedure ' + AClass + '.' + AState + '(', line)) then
        begin
          inside := True;
          Continue;
        end;
        if not inside then Continue;
        { the implementation section puts its routines at column one }
        if StartsStr('procedure ', line) or StartsStr('function ', line) then
          Break;
        line := Trim(line);
        dot := Pos('.Enabled', line);
        if dot > 1 then
        begin
          nm := Trim(Copy(line, 1, dot - 1));
          if nm <> '' then
            if AGoverned.IndexOf(nm) < 0 then
              AGoverned.Add(nm)
            else if ADuplicates.IndexOf(nm) < 0 then
              ADuplicates.Add(nm);
        end;
      end;
    finally
      lines.Free;
    end;
  end;

var
  actions, governed, duplicates: TStringList;
  k, covered, exempt: Integer;
  nm, cl, act: string;
begin
  actions := TStringList.Create;
  governed := TStringList.Create;
  duplicates := TStringList.Create;
  try
    ParseActions(actions);
    ParseGoverned(governed, duplicates);

    { Two rules for one control means only the second one is in force }
    for k := 0 to duplicates.Count - 1 do
      Fail(Format('%s sets %s.Enabled more than once, so only '
        + 'the last rule applies, combine them into one', [AState, duplicates[k]]));
    covered := 0;
    exempt := 0;
    for k := 0 to AComponents.Count - 1 do
    begin
      nm := AComponents.Names[k];
      cl := AComponents.ValueFromIndex[k];
      if not IsInteractive(cl) then Continue;
      if IsAlwaysEnabled(nm) then
      begin
        Inc(exempt);
        Continue;
      end;
      act := actions.Values[nm];
      if (governed.IndexOf(nm) >= 0)
         or ((act <> '') and (governed.IndexOf(act) >= 0)) then
      begin
        Inc(covered);
        Continue;
      end;
      Fail(Format('%s: %s is never enabled or disabled, add it to '
        + '%s.%s, or to AlwaysEnabled in this test with a reason',
        [nm, cl, AClass, AState]));
    end;

    { Enabled assigned on a control that carries an Action does nothing }
    for k := 0 to governed.Count - 1 do
    begin
      act := actions.Values[governed[k]];
      if act <> '' then
        Fail(Format('%s sets %s.Enabled, but %s is driven by '
          + '%s, which overwrites it, set %s.Enabled instead',
          [AState, governed[k], governed[k], act, act]));
    end;

    WriteLn(Format('%d interactive components governed, %d deliberately always on',
      [covered, exempt]));
  finally
    duplicates.Free;
    governed.Free;
    actions.Free;
  end;
end;


{ --- 5. a closed list is never selected by assigning Text ----------------

  A csDropDownList combo ignores an assignment to Text when its Items do not
  already hold that string, and it does so silently.  Every list in this
  window is filled by the backend at some later moment (the materials when
  the engine opens, the particles only once the kernel is built) so a
  value read from a configuration file is routinely assigned before its list
  exists.  That is how a saved beam came back as proton and a saved physics
  list as local.  Selections must go through RestoreSelection, which keeps
  the value and applies it when the list is refilled. }

// Every TSciEdit keeps the unit the user typed
//
// seoAutoUnits re-picks the SI prefix on every programmatic write, and
// TSciEdit only honours the typed spelling while the prefix it remembers still
// matches the current one. So with seoAutoUnits on, writing a value back into
// the box silently changes its unit: '0 um' becomes '0 m' because a zero gets
// no prefix at all, and '20000 um' becomes '20 mm'. The next Apply then reads
// that unit and sends it, and the configuration is saved with it
procedure CheckUnitOptions(const ALfm: string);
var
  lfmLines: TStringList;
  i, n: Integer;
  line, current, nm, cl, opts: string;
  isSci: Boolean;
begin
  lfmLines := TStringList.Create;
  try
    lfmLines.LoadFromFile(ALfm);
    current := '';
    isSci := False;
    n := 0;
    for i := 0 to lfmLines.Count - 1 do
    begin
      line := Trim(lfmLines[i]);
      if StartsStr('object ', line) then
      begin
        if SplitDecl(Copy(line, Length('object ') + 1, MaxInt), nm, cl) then
        begin
          current := nm;
          isSci := cl = 'TSciEdit';
          if isSci then Inc(n);
        end;
      end
      else if isSci and StartsStr('Options = [', line) then
      begin
        opts := line;
        if Pos('seoAutoUnits', opts) > 0 then
          Fail(Format('%s line %d: %s has seoAutoUnits, which re-picks '
            + 'the SI prefix on every write and so discards the unit the user '
            + 'typed', [ExtractFileName(ALfm), i + 1, current]));
        if Pos('seoKeepTypedUnits', opts) = 0 then
          Fail(Format('%s line %d: %s is missing seoKeepTypedUnits, so '
            + 'it will redisplay values in whatever unit the prefix logic '
            + 'chooses', [ExtractFileName(ALfm), i + 1, current]));
        if Pos('seoCanonicalUnits', opts) > 0 then
          Fail(Format('%s line %d: %s has seoCanonicalUnits, which '
            + 'converts every value to base SI', [ExtractFileName(ALfm), i + 1, current]));
        if Pos('seoPreferredUnits', opts) > 0 then
          Fail(Format('%s line %d: %s has seoPreferredUnits, which '
            + 'overrides what the user typed', [ExtractFileName(ALfm), i + 1, current]));
      end;
    end;

    WriteLn(Format('%d value-and-unit boxes, all keeping the typed unit', [n]));
  finally
    lfmLines.Free;
  end;
end;

procedure CheckClosedLists(const ALfm, APas: string);
var
  lfmLines, pasLines: TStringList;
  closed: TStringList;
  i, eqPos: Integer;
  line, current, nm, cl, target: string;
begin
  closed := TStringList.Create;
  lfmLines := TStringList.Create;
  pasLines := TStringList.Create;
  try
    { which combos are closed lists }
    lfmLines.LoadFromFile(ALfm);
    current := '';
    for i := 0 to lfmLines.Count - 1 do
    begin
      line := Trim(lfmLines[i]);
      if StartsStr('object ', line) then
      begin
        if SplitDecl(Copy(line, Length('object ') + 1, MaxInt), nm, cl) then
          current := nm;
      end
      else if (line = 'Style = csDropDownList') and (current <> '') then
        if closed.IndexOf(current) < 0 then closed.Add(current);
    end;

    { nobody may assign Text to one of them }
    pasLines.LoadFromFile(APas);
    for i := 0 to pasLines.Count - 1 do
    begin
      line := Trim(pasLines[i]);
      eqPos := Pos('.Text :=', line);
      if eqPos < 2 then Continue;
      target := Trim(Copy(line, 1, eqPos - 1));
      if closed.IndexOf(target) >= 0 then
        Fail(Format('%s line %d assigns %s.Text, but %s is a '
          + 'csDropDownList and drops a value its Items do not hold, use '
          + 'RestoreSelection', [ExtractFileName(APas), i + 1, target, target]));
    end;

    WriteLn(Format('%d closed lists, none selected by assigning Text',
      [closed.Count]));
  finally
    pasLines.Free;
    lfmLines.Free;
    closed.Free;
  end;
end;


type
  TChecked = record
    UnitName: string;    { the .lfm and .pas share it }
    ClassName: string;
    State: string;       { where Enabled is set, empty for a frame with nothing to govern }
  end;

const
  Checked: array[0..3] of TChecked = (
    (UnitName: 'umain';            ClassName: 'TMainForm';        State: 'UpdateControlState'),
    (UnitName: 'upanelsframe';     ClassName: 'TPanelsFrame';     State: 'UpdateState'),
    (UnitName: 'ueditorframe';     ClassName: 'TEditorFrame';     State: 'UpdateState'),
    (UnitName: 'uresultsframe';    ClassName: 'TResultsFrame';    State: ''));

function CheckedIndex(const AClass: string): Integer;
var
  k: Integer;
begin
  Result := -1;
  for k := Low(Checked) to High(Checked) do
    if Checked[k].ClassName = AClass then Exit(k);
end;

{ The body of one routine, from its header to the next routine at column one }
function RoutineBody(const APas, AClass, AName: string): string;
var
  lines: TStringList;
  k: Integer;
  inside: Boolean;
begin
  Result := '';
  inside := False;
  lines := TStringList.Create;
  try
    lines.LoadFromFile(APas);
    for k := 0 to lines.Count - 1 do
    begin
      if StartsStr('procedure ' + AClass + '.' + AName, lines[k]) then
      begin
        inside := True;
        Continue;
      end;
      if not inside then Continue;
      if StartsStr('procedure ', lines[k]) or StartsStr('function ', lines[k]) then
        Break;
      Result := Result + lines[k] + LineEnding;
    end;
  finally
    lines.Free;
  end;
end;

procedure CheckPair(const ADir: string; const AChecked: TChecked);
var
  lfm, pas, root, name, cls, handler: string;
  Components, Handlers, Fields, Methods, Inlines: TStringList;
  i, eq, k: Integer;
begin
  lfm := ADir + AChecked.UnitName + '.lfm';
  pas := ADir + AChecked.UnitName + '.pas';
  if not FileExists(lfm) then
  begin
    WriteLn('cannot find ', lfm);
    Halt(2);
  end;
  if not FileExists(pas) then
  begin
    WriteLn('cannot find ', pas);
    Halt(2);
  end;

  Components := TStringList.Create;
  Handlers := TStringList.Create;
  Fields := TStringList.Create;
  Methods := TStringList.Create;
  Inlines := TStringList.Create;
  try
    ParseLfm(lfm, Components, Handlers, Inlines);
    ParsePas(pas, AChecked.ClassName, Fields, Methods);
    { the first object is the form or frame itself }
    root := '';
    if Components.Count > 0 then root := Components.Names[0];

    WriteLn(Format('== %s: %d components and %d event handlers in %s.lfm',
      [AChecked.ClassName, Components.Count, Handlers.Count, AChecked.UnitName]));
    WriteLn(Format('%d published component fields and %d methods in %s.pas',
      [Fields.Count, Methods.Count, AChecked.UnitName]));

    { 1. every designed component must have a published field of the same type }
    for i := 0 to Components.Count - 1 do
    begin
      name := Components.Names[i];
      cls := Components.ValueFromIndex[i];
      if name = root then Continue;
      if Fields.IndexOfName(name) < 0 then
        Fail(Format('%s.lfm declares %s: %s, but %s.pas has no published '
          + 'field for it (the form would fail to stream at startup)',
          [AChecked.UnitName, name, cls, AChecked.UnitName]))
      else if not SameText(Fields.Values[name], cls) then
        Fail(Format('%s is %s in the .lfm but %s in the .pas',
          [name, cls, Fields.Values[name]]));
    end;

    { 2. every published component field must exist in the designed form }
    for i := 0 to Fields.Count - 1 do
    begin
      name := Fields.Names[i];
      if Components.IndexOfName(name) < 0 then
        Fail(Format('%s.pas publishes %s: %s, but %s.lfm never creates '
          + 'it (the code would dereference nil)',
          [AChecked.UnitName, name, Fields.ValueFromIndex[i], AChecked.UnitName]));
    end;

    { 3. every event handler named by the designer must be declared }
    for i := 0 to Handlers.Count - 1 do
    begin
      eq := Pos('=', Handlers[i]);
      handler := Copy(Handlers[i], eq + 1, MaxInt);
      if Methods.IndexOf(handler) < 0 then
        Fail(Format('%s.lfm assigns %s, which %s.pas does not declare',
          [AChecked.UnitName, Handlers[i], AChecked.UnitName]));
    end;

    { 4. every control that can be operated is governed in one place }
    CheckStateCoverage(lfm, pas, AChecked.ClassName, AChecked.State, Components);

    { 5. a closed list is never selected by assigning Text }
    CheckClosedLists(lfm, pas);

    { 6. a value-and-unit box keeps the unit the user typed }
    CheckUnitOptions(lfm);

    { 7. a frame on this form is checked too, and its state is kept with the form's }
    for i := 0 to Inlines.Count - 1 do
    begin
      name := Inlines.Names[i];
      cls := Inlines.ValueFromIndex[i];
      k := CheckedIndex(cls);
      if k < 0 then
      begin
        Fail(Format('%s.lfm places %s: %s, a frame this test does not check, '
          + 'add it to Checked', [AChecked.UnitName, name, cls]));
        Continue;
      end;
      if Checked[k].State = '' then Continue;
      if Pos(name + '.' + Checked[k].State + '(',
             RoutineBody(pas, AChecked.ClassName, AChecked.State)) = 0 then
        Fail(Format('%s.%s never calls %s.%s, so the frame''s controls keep '
          + 'whatever state they were designed with',
          [AChecked.ClassName, AChecked.State, name, Checked[k].State]));
    end;
    WriteLn;
  finally
    Inlines.Free;
    Components.Free;
    Handlers.Free;
    Fields.Free;
    Methods.Free;
  end;
end;

var
  dir: string;
  n: Integer;

begin
  dir := '../gui';
  if ParamCount >= 1 then dir := ParamStr(1);
  dir := IncludeTrailingPathDelimiter(dir);

  for n := Low(Checked) to High(Checked) do
    CheckPair(dir, Checked[n]);

  if Failures = 0 then
  begin
    Note('every designed component has a matching published field');
    Note('every published field is created by the designer');
    Note('every event handler referenced by the .lfm is declared');
    Note('every control that can be operated is enabled from one place');
    Note('no closed list is selected by assigning Text');
    Note('no value-and-unit box re-picks the unit behind the user');
    Note('every frame placed on a form is checked, and its state kept with the form''s');
  end;

  WriteLn;
  if Failures = 0 then
    WriteLn('PASSED (0 failures)')
  else
    WriteLn(Format('FAILED (%d failures)', [Failures]));
  Halt(Ord(Failures <> 0));
end.
