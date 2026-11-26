{==============================================================================
  StrataMacroCheck.pas: how the macro editor reads a macro into commands.

  Plain console Free Pascal, no backend needed.
==============================================================================}

program StrataMacroCheck;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, uStrataMacro;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AWhat: String);
begin
  if ACondition then
    WriteLn(Format('%-60s ok', [AWhat]))
  else
  begin
    WriteLn(Format('%-60s FAILED', [AWhat]));
    Inc(Failures);
  end;
end;

function Parse(const AText: String): TStrataMacroCommands;
var
  lines: TStringList;
begin
  lines := TStringList.Create;
  try
    lines.Text := AText;
    Result := StrataParseMacro(lines);
  finally
    lines.Free;
  end;
end;

var
  c: TStrataMacroCommands;

begin
  c := Parse('');
  Check(Length(c) = 0, 'an empty macro sends nothing');

  c := Parse('# a comment' + LineEnding + LineEnding + '   ' + LineEnding
             + '/run/verbose 2');
  Check((Length(c) = 1) and (c[0].Command = '/run/verbose 2'),
        'comments and blank lines are skipped');
  Check((Length(c) = 1) and (c[0].Line = 4), 'a command keeps the line it is on');

  c := Parse('  /gun/energy 1 MeV   # the beam');
  Check((Length(c) = 1) and (c[0].Command = '/gun/energy 1 MeV'),
        'a trailing comment is cut, and the spaces round it');

  c := Parse('/strata/geometry/layerMaterial 0 G4_Si#2');
  Check((Length(c) = 1) and (c[0].Command = '/strata/geometry/layerMaterial 0 G4_Si#2'),
        'a # inside a word is not a comment');

  c := Parse('/control/echo "a # b"');
  Check((Length(c) = 1) and (c[0].Command = '/control/echo "a # b"'),
        'a # inside quotes is not a comment');

  c := Parse('/analysis/h1/set 3 100 0 1 \' + LineEnding + '  um' + LineEnding
             + '/run/verbose 0');
  Check((Length(c) = 2) and (c[0].Command = '/analysis/h1/set 3 100 0 1 um')
        and (c[0].Line = 1) and (c[1].Line = 3),
        'a line ending in \ goes on in the next one');

  c := Parse('/gun/particle _' + LineEnding + 'proton');
  Check((Length(c) = 1) and (c[0].Command = '/gun/particle proton'),
        'a line ending in _ goes on as well');

  c := Parse('/gun/particle \');
  Check((Length(c) = 1) and (c[0].Command = '/gun/particle'),
        'a continuation on the last line still ends the command');

  c := Parse('/run/initialize');
  Check((Length(c) = 1) and (c[0].Kind = mkInitialize), '/run/initialize is told apart');

  c := Parse('/run/beamOn 1000');
  Check((Length(c) = 1) and (c[0].Kind = mkBeamOn) and (c[0].Events = 1000)
        and (c[0].Error = ''), '/run/beamOn carries its number of events');

  c := Parse('/run/beamOn');
  Check((Length(c) = 1) and (c[0].Kind = mkBeamOn) and (c[0].Events = 1),
        '/run/beamOn alone is one event, as in Geant4');

  c := Parse('/run/beamOn ten');
  Check((Length(c) = 1) and (c[0].Error <> ''), 'a number of events that is not one is refused');

  c := Parse('/run/beamOn 0');
  Check((Length(c) = 1) and (c[0].Error <> ''), 'zero events is refused');

  c := Parse('/run/beamOn 10 after.mac 5');
  Check((Length(c) = 1) and (c[0].Error <> ''),
        'a macro after each event is refused, the engine cannot run it');

  c := Parse('/run/beamOnce 10');
  Check((Length(c) = 1) and (c[0].Kind = mkCommand), 'only the exact command name counts');

  WriteLn;
  if Failures = 0 then
    WriteLn('PASSED (0 failures)')
  else
    WriteLn(Format('FAILED (%d failures)', [Failures]));
  Halt(Ord(Failures <> 0));
end.
