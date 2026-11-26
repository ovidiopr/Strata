{==============================================================================
  uStrataMacro.pas: a Geant4 macro as the commands a run sends, one by one.

  The text is read the way Geant4's batch session reads a file: blank lines
  and lines starting with '#' are skipped, a word starting with '#' ends
  the command, and a line ending in '\' or '_' goes on in the next one.
  /run/initialize and /run/beamOn are told apart, because the engine has
  calls of its own for them.
==============================================================================}

unit uStrataMacro;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TStrataMacroKind = (mkCommand, mkInitialize, mkBeamOn);

  TStrataMacroCommand = record
    Line: Integer;        // where it starts in the text, counted from 1
    Command: String;      // as sent, comments and continuations resolved
    Kind: TStrataMacroKind;
    Events: Int64;        // for /run/beamOn
    Error: String;        // why it cannot be sent, empty when it can
  end;

  TStrataMacroCommands = array of TStrataMacroCommand;

function StrataParseMacro(ALines: TStrings): TStrataMacroCommands;

implementation

// Cuts the command at the first word that starts with '#', outside quotes
function StripComment(const ALine: String): String;
var
  i: Integer;
  quoted: Boolean;
begin
  quoted := False;
  for i := 1 to Length(ALine) do
  begin
    if ALine[i] = '"' then
      quoted := not quoted
    else if (ALine[i] = '#') and (not quoted)
            and ((i = 1) or (ALine[i - 1] in [' ', #9])) then
      Exit(TrimRight(Copy(ALine, 1, i - 1)));
  end;
  Result := ALine;
end;

procedure Classify(var ACommand: TStrataMacroCommand);
var
  words: TStringList;
  n: Int64;
begin
  words := TStringList.Create;
  try
    words.Delimiter := ' ';
    words.StrictDelimiter := False;
    words.DelimitedText := ACommand.Command;
    if words.Count = 0 then Exit;
    if words[0] = '/run/initialize' then
      ACommand.Kind := mkInitialize
    else if words[0] = '/run/beamOn' then
    begin
      ACommand.Kind := mkBeamOn;
      // Geant4 runs one event when no number is given
      ACommand.Events := 1;
      if words.Count > 1 then
      begin
        if TryStrToInt64(words[1], n) and (n > 0) then
          ACommand.Events := n
        else
          ACommand.Error := 'the number of events has to be a whole number above zero';
      end;
      if (ACommand.Error = '') and (words.Count > 2) then
        ACommand.Error := 'only the number of events is supported here, '
                          + 'not a macro to run after each event';
    end;
  finally
    words.Free;
  end;
end;

function StrataParseMacro(ALines: TStrings): TStrataMacroCommands;
var
  i, first, n: Integer;
  line, pending: String;
  continued: Boolean;
begin
  Result := nil;
  n := 0;
  pending := '';
  first := 0;
  for i := 0 to ALines.Count - 1 do
  begin
    line := Trim(ALines[i]);
    if (pending = '') and ((line = '') or (line[1] = '#')) then Continue;
    line := StripComment(line);
    continued := (line <> '') and (line[Length(line)] in ['\', '_']);
    if continued then
      line := TrimRight(Copy(line, 1, Length(line) - 1));
    if pending = '' then
    begin
      first := i + 1;
      pending := line;
    end
    else if line <> '' then
      pending := pending + ' ' + line;
    if continued then Continue;
    if pending = '' then Continue;
    SetLength(Result, n + 1);
    Result[n].Line := first;
    Result[n].Command := pending;
    Result[n].Kind := mkCommand;
    Result[n].Events := 0;
    Result[n].Error := '';
    Classify(Result[n]);
    Inc(n);
    pending := '';
  end;
  // A continuation on the last line still ends the command
  if pending <> '' then
  begin
    SetLength(Result, n + 1);
    Result[n].Line := first;
    Result[n].Command := pending;
    Result[n].Kind := mkCommand;
    Result[n].Events := 0;
    Result[n].Error := '';
    Classify(Result[n]);
  end;
end;

end.
