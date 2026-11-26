{==============================================================================
  uStrataCommands.pas: the Geant4 command tree the backend reports.

  Read from the text strata_get_command_tree writes, it answers the macro
  editor's questions: whether a word is a command, what can be typed where
  the cursor is, and what a command and its parameters are for.  No LCL.
==============================================================================}

unit uStrataCommands;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  StrataCommandTreeHeader = '# strata command tree 1';

type
  TStrataParamInfo = record
    Name: String;
    Kind: Char;               // i, d, s or b, as Geant4 has it
    Omittable: Boolean;
    CurrentAsDefault: Boolean;
    DefaultValue: String;
    Candidates: String;       // space-separated, empty for any value
    Range: String;
    Guidance: String;
  end;

  TStrataCommandInfo = class
  public
    Path: String;             // directories end in '/'
    IsDirectory: Boolean;
    States: String;
    Range: String;
    Guidance: String;
    Params: array of TStrataParamInfo;
  end;

  { TStrataCommandTree }

  TStrataCommandTree = class
  private
    FItems: TStringList;      // sorted by path, objects are the entries
    FText: String;
    FMaterials: TStrings;     // offered for a parameter named material, not owned
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    // False, and empty, for anything that is not a command tree
    function LoadFromText(const AText: String): Boolean;
    function LoadFromFile(const AFileName: String): Boolean;
    procedure SaveToFile(const AFileName: String);
    function Count: Integer;
    function Find(const APath: String): TStrataCommandInfo;
    function IsCommand(const APath: String): Boolean;
    // What can be typed at ACaret (the cursor stands before character
    // ACaret, counted from 1) in a line of a macro; AStart is where the
    // word being completed begins
    procedure Complete(const ALine: String; ACaret: Integer; AList: TStrings;
      out AStart: Integer);
    // What the command on the line is, which parameter the cursor is in,
    // and the guidance: the editor's help strip
    function Describe(const ALine: String; ACaret: Integer): String;
    property Text: String read FText;
    property Materials: TStrings read FMaterials write FMaterials;
  end;

// The words of a macro line, without its comment; AStarts are 1-based
procedure StrataMacroWords(const ALine: String; AWords: TStrings;
  out AStarts: TStringArray);
// The word the cursor is in or about to start, -1 on a comment line
function StrataWordAt(const ALine: String; ACaret: Integer;
  out AStart: Integer; out APrefix: String): Integer;

implementation

function Unescape(const AText: String): String;
var
  i: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(AText) do
  begin
    if (AText[i] = '\') and (i < Length(AText)) then
    begin
      case AText[i + 1] of
        'n': Result := Result + LineEnding;
        't': Result := Result + #9;
        '\': Result := Result + '\';
      else
        Result := Result + AText[i] + AText[i + 1];
      end;
      Inc(i, 2);
    end
    else
    begin
      Result := Result + AText[i];
      Inc(i);
    end;
  end;
end;

procedure SplitTabs(const ALine: String; AFields: TStrings);
var
  i, from: Integer;
begin
  AFields.Clear;
  from := 1;
  for i := 1 to Length(ALine) do
    if ALine[i] = #9 then
    begin
      AFields.Add(Copy(ALine, from, i - from));
      from := i + 1;
    end;
  AFields.Add(Copy(ALine, from, MaxInt));
end;

procedure StrataMacroWords(const ALine: String; AWords: TStrings;
  out AStarts: TStringArray);
var
  i, start: Integer;
  quoted: Boolean;
begin
  AWords.Clear;
  AStarts := nil;
  i := 1;
  while i <= Length(ALine) do
  begin
    while (i <= Length(ALine)) and (ALine[i] in [' ', #9]) do Inc(i);
    if i > Length(ALine) then Break;
    // A word starting with '#' starts the comment
    if ALine[i] = '#' then Break;
    start := i;
    quoted := False;
    while i <= Length(ALine) do
    begin
      if ALine[i] = '"' then quoted := not quoted
      else if (ALine[i] in [' ', #9]) and (not quoted) then Break;
      Inc(i);
    end;
    AWords.Add(Copy(ALine, start, i - start));
    SetLength(AStarts, Length(AStarts) + 1);
    AStarts[High(AStarts)] := IntToStr(start);
  end;
end;

// Where the comment starts, 0 for a line without one: a word starting
// with '#', outside quotes
function CommentStart(const ALine: String): Integer;
var
  i: Integer;
  quoted: Boolean;
begin
  quoted := False;
  for i := 1 to Length(ALine) do
    if ALine[i] = '"' then
      quoted := not quoted
    else if (ALine[i] = '#') and (not quoted)
            and ((i = 1) or (ALine[i - 1] in [' ', #9])) then
      Exit(i);
  Result := 0;
end;

function StrataWordAt(const ALine: String; ACaret: Integer;
  out AStart: Integer; out APrefix: String): Integer;
var
  words: TStringList;
  starts: TStringArray;
  c: Integer;
begin
  Result := -1;
  AStart := ACaret;
  APrefix := '';
  c := CommentStart(ALine);
  if (c > 0) and (ACaret > c) then Exit;
  words := TStringList.Create;
  try
    StrataMacroWords(Copy(ALine, 1, ACaret - 1), words, starts);
    if (words.Count > 0)
       and (StrToInt(starts[words.Count - 1]) + Length(words[words.Count - 1]) = ACaret) then
    begin
      // In the middle of, or at the end of, the last word
      Result := words.Count - 1;
      AStart := StrToInt(starts[Result]);
      APrefix := words[Result];
    end
    else
      // After a space: the next word, not started yet
      Result := words.Count;
  finally
    words.Free;
  end;
end;

function KindName(AKind: Char): String;
begin
  case AKind of
    'i': Result := 'integer';
    'd': Result := 'number';
    'b': Result := 'true or false';
  else
    Result := 'text';
  end;
end;

{ TStrataCommandTree }

constructor TStrataCommandTree.Create;
begin
  inherited Create;
  FItems := TStringList.Create;
  FItems.Sorted := True;
  FItems.CaseSensitive := True;
  FItems.Duplicates := dupIgnore;
  FItems.OwnsObjects := True;
end;

destructor TStrataCommandTree.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TStrataCommandTree.Clear;
begin
  FItems.Clear;
  FText := '';
end;

function TStrataCommandTree.LoadFromText(const AText: String): Boolean;
var
  lines, fields: TStringList;
  i, n: Integer;
  current: TStrataCommandInfo;
  entry: TStrataCommandInfo;
  p: TStrataParamInfo;
begin
  Clear;
  Result := False;
  lines := TStringList.Create;
  fields := TStringList.Create;
  try
    lines.Text := AText;
    if (lines.Count = 0) or (lines[0] <> StrataCommandTreeHeader) then Exit;
    current := nil;
    for i := 1 to lines.Count - 1 do
    begin
      SplitTabs(lines[i], fields);
      if fields.Count = 0 then Continue;
      if (fields[0] = 'D') and (fields.Count >= 3) then
      begin
        entry := TStrataCommandInfo.Create;
        entry.Path := Unescape(fields[1]);
        entry.IsDirectory := True;
        entry.Guidance := Unescape(fields[2]);
        FItems.AddObject(entry.Path, entry);
        current := nil;
      end
      else if (fields[0] = 'C') and (fields.Count >= 5) then
      begin
        entry := TStrataCommandInfo.Create;
        entry.Path := Unescape(fields[1]);
        entry.States := fields[2];
        entry.Range := Unescape(fields[3]);
        entry.Guidance := Unescape(fields[4]);
        FItems.AddObject(entry.Path, entry);
        current := entry;
      end
      else if (fields[0] = 'P') and (fields.Count >= 9) and (current <> nil) then
      begin
        p.Name := Unescape(fields[1]);
        if fields[2] <> '' then p.Kind := fields[2][1] else p.Kind := 's';
        p.Omittable := fields[3] = '1';
        p.CurrentAsDefault := fields[4] = '1';
        p.DefaultValue := Unescape(fields[5]);
        p.Candidates := Unescape(fields[6]);
        p.Range := Unescape(fields[7]);
        p.Guidance := Unescape(fields[8]);
        n := Length(current.Params);
        SetLength(current.Params, n + 1);
        current.Params[n] := p;
      end;
    end;
    FText := AText;
    Result := FItems.Count > 0;
  finally
    fields.Free;
    lines.Free;
  end;
end;

function TStrataCommandTree.LoadFromFile(const AFileName: String): Boolean;
var
  f: TStringList;
begin
  Result := False;
  if not FileExists(AFileName) then Exit;
  f := TStringList.Create;
  try
    try
      f.LoadFromFile(AFileName);
    except
      Exit;
    end;
    Result := LoadFromText(f.Text);
  finally
    f.Free;
  end;
end;

procedure TStrataCommandTree.SaveToFile(const AFileName: String);
var
  f: TStringList;
begin
  f := TStringList.Create;
  try
    f.Text := FText;
    f.SaveToFile(AFileName);
  finally
    f.Free;
  end;
end;

function TStrataCommandTree.Count: Integer;
begin
  Result := FItems.Count;
end;

function TStrataCommandTree.Find(const APath: String): TStrataCommandInfo;
var
  i: Integer;
begin
  Result := nil;
  if FItems.Find(APath, i) then Result := TStrataCommandInfo(FItems.Objects[i]);
end;

function TStrataCommandTree.IsCommand(const APath: String): Boolean;
var
  e: TStrataCommandInfo;
begin
  e := Find(APath);
  Result := (e <> nil) and (not e.IsDirectory);
end;

procedure TStrataCommandTree.Complete(const ALine: String; ACaret: Integer;
  AList: TStrings; out AStart: Integer);
var
  word, i, slash: Integer;
  prefix, dir, rest, path: String;
  words: TStringList;
  starts: TStringArray;
  e: TStrataCommandInfo;
  cands: TStringList;
begin
  AList.Clear;
  word := StrataWordAt(ALine, ACaret, AStart, prefix);
  if word < 0 then Exit;
  if word = 0 then
  begin
    // A command path: the entries directly under the directory typed so far
    if (prefix <> '') and (prefix[1] <> '/') then Exit;
    if prefix = '' then prefix := '/';
    slash := Length(prefix);
    while (slash > 0) and (prefix[slash] <> '/') do Dec(slash);
    dir := Copy(prefix, 1, slash);
    for i := 0 to FItems.Count - 1 do
    begin
      path := FItems[i];
      if (Length(path) <= Length(dir)) or (Copy(path, 1, Length(dir)) <> dir) then Continue;
      if Copy(path, 1, Length(prefix)) <> prefix then Continue;
      rest := Copy(path, Length(dir) + 1, MaxInt);
      // Only one level down: a directory ends at its own slash
      slash := Pos('/', rest);
      if (slash > 0) and (slash < Length(rest)) then Continue;
      AList.Add(path);
    end;
    Exit;
  end;
  // A parameter: whatever its candidates are
  words := TStringList.Create;
  try
    StrataMacroWords(ALine, words, starts);
    if words.Count = 0 then Exit;
    e := Find(words[0]);
  finally
    words.Free;
  end;
  if (e = nil) or e.IsDirectory or (word > Length(e.Params)) then Exit;
  cands := TStringList.Create;
  try
    cands.Delimiter := ' ';
    cands.StrictDelimiter := False;
    cands.DelimitedText := e.Params[word - 1].Candidates;
    if (cands.Count = 0) and SameText(e.Params[word - 1].Name, 'material')
       and (FMaterials <> nil) then
      cands.Assign(FMaterials);
    if (cands.Count = 0) and (e.Params[word - 1].Kind = 'b') then
    begin
      cands.Add('true');
      cands.Add('false');
    end;
    for i := 0 to cands.Count - 1 do
      if (cands[i] <> '') and (Copy(cands[i], 1, Length(prefix)) = prefix)
         and (AList.IndexOf(cands[i]) < 0) then
        AList.Add(cands[i]);
  finally
    cands.Free;
  end;
end;

function TStrataCommandTree.Describe(const ALine: String; ACaret: Integer): String;
var
  words: TStringList;
  starts: TStringArray;
  word, start, k: Integer;
  prefix, head, sig: String;
  e: TStrataCommandInfo;
  p: TStrataParamInfo;
begin
  Result := '';
  word := StrataWordAt(ALine, ACaret, start, prefix);
  if word < 0 then Exit;
  words := TStringList.Create;
  try
    StrataMacroWords(ALine, words, starts);
    if words.Count = 0 then Exit;
    head := words[0];
  finally
    words.Free;
  end;
  e := Find(head);
  if e = nil then
  begin
    if (head <> '') and (head[1] = '/') then
      Result := head + ': no such command';
    Exit;
  end;
  if e.IsDirectory then
  begin
    Result := e.Path + LineEnding + e.Guidance;
    Exit;
  end;
  // The signature, with the parameter the cursor is in between brackets
  sig := e.Path;
  for k := 0 to High(e.Params) do
    if k = word - 1 then
      sig := sig + '  [' + e.Params[k].Name + ']'
    else
      sig := sig + '  ' + e.Params[k].Name;
  Result := sig;
  if (word >= 1) and (word <= Length(e.Params)) then
  begin
    p := e.Params[word - 1];
    head := Format('%s: %s', [p.Name, KindName(p.Kind)]);
    if p.Omittable then
    begin
      if p.CurrentAsDefault then
        head := head + ', optional, the current value when left out'
      else if p.DefaultValue <> '' then
        head := head + ', optional, default ' + p.DefaultValue
      else
        head := head + ', optional';
    end;
    if p.Candidates <> '' then head := head + '; one of: ' + p.Candidates;
    if p.Range <> '' then head := head + '; ' + p.Range;
    Result := Result + LineEnding + head;
    if p.Guidance <> '' then Result := Result + LineEnding + p.Guidance;
  end
  else if word > Length(e.Params) then
    Result := Result + LineEnding + 'no more parameters';
  if e.Guidance <> '' then Result := Result + LineEnding + e.Guidance;
end;

end.
