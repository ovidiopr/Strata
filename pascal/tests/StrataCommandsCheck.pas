{==============================================================================
  StrataCommandsCheck.pas: reading the command tree and what the editor asks
  of it.  Plain console Free Pascal, no backend needed: the tree is written
  here in the form strata_get_command_tree gives it.
==============================================================================}

program StrataCommandsCheck;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, uStrataCommands;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AWhat: String);
begin
  if ACondition then
    WriteLn(Format('%-64s ok', [AWhat]))
  else
  begin
    WriteLn(Format('%-64s FAILED', [AWhat]));
    Inc(Failures);
  end;
end;

const
  T = #9;
  N = LineEnding;
  Sample =
    StrataCommandTreeHeader + N +
    'D' + T + '/' + T + '' + N +
    'D' + T + '/gun/' + T + 'Particle gun' + N +
    'C' + T + '/gun/energy' + T + 'PreInit Idle' + T + '' + T + 'Set kinetic energy.' + N +
    'P' + T + 'Energy' + T + 'd' + T + '0' + T + '0' + T + '1' + T + '' + T + 'Energy >= 0' + T + '' + N +
    'P' + T + 'Unit' + T + 's' + T + '1' + T + '0' + T + 'GeV' + T + 'eV keV MeV GeV' + T + '' + T + '' + N +
    'C' + T + '/gun/particle' + T + 'PreInit Idle' + T + '' + T + 'Set particle to be generated.\nThe list depends on the physics.' + N +
    'P' + T + 'particleName' + T + 's' + T + '1' + T + '0' + T + 'geantino' + T + 'proton alpha e- ion' + T + '' + T + '' + N +
    'D' + T + '/run/' + T + 'Run control' + N +
    'C' + T + '/run/beamOn' + T + 'Idle' + T + 'numberOfEvent >= 0' + T + 'Start a Run.' + N +
    'P' + T + 'numberOfEvent' + T + 'i' + T + '1' + T + '0' + T + '1' + T + '' + T + '' + T + 'Number of events' + N +
    'C' + T + '/run/initialize' + T + 'PreInit Idle' + T + '' + T + 'Initialize G4 kernel.' + N +
    'D' + T + '/run/particle/' + T + 'Particle stuff' + N +
    'C' + T + '/run/particle/dumpCutValues' + T + 'Idle' + T + '' + T + 'Dump a list.' + N +
    'C' + T + '/run/physicsModified' + T + 'Idle' + T + '' + T + 'Tab\there, backslash \\ there' + N +
    'D' + T + '/strata/' + T + '' + N +
    'C' + T + '/strata/flag' + T + 'Idle' + T + '' + T + '' + N +
    'P' + T + 'on' + T + 'b' + T + '1' + T + '0' + T + 'true' + T + '' + T + '' + T + '' + N +
    'C' + T + '/strata/layerMat' + T + 'PreInit' + T + '' + T + '' + N +
    'P' + T + 'layerNb' + T + 'i' + T + '0' + T + '0' + T + '' + T + '' + T + '' + T + '' + N +
    'P' + T + 'material' + T + 's' + T + '0' + T + '0' + T + '' + T + '' + T + '' + T + '' + N;

function Listed(L: TStrings): String;
begin
  Result := StringReplace(Trim(L.Text), LineEnding, ' ', [rfReplaceAll]);
end;

var
  tree: TStrataCommandTree;
  e: TStrataCommandInfo;
  L, mats: TStringList;
  start, w: Integer;
  prefix, help: String;

begin
  tree := TStrataCommandTree.Create;
  L := TStringList.Create;
  try
    Check(not tree.LoadFromText('/run/beamOn 10'), 'text without the header is not a tree');
    Check(tree.Count = 0, '  and leaves it empty');
    Check(tree.LoadFromText(Sample), 'the sample reads');

    e := tree.Find('/gun/energy');
    Check((e <> nil) and (not e.IsDirectory) and (Length(e.Params) = 2),
          'a command with its two parameters');
    Check((e <> nil) and (e.Params[1].Candidates = 'eV keV MeV GeV')
          and e.Params[1].Omittable and (e.Params[1].DefaultValue = 'GeV'),
          'a parameter keeps its candidates and default');
    Check(tree.IsCommand('/run/beamOn') and (not tree.IsCommand('/run/'))
          and (not tree.IsCommand('/run/beamOff')), 'commands told from directories and typos');
    e := tree.Find('/gun/particle');
    Check((e <> nil) and (Pos(LineEnding, e.Guidance) > 0), 'an escaped line break is a line break');
    e := tree.Find('/run/physicsModified');
    Check((e <> nil) and (e.Guidance = 'Tab'#9'here, backslash \ there'),
          'escaped tab and backslash come back');

    w := StrataWordAt('/gun/energy 1 MeV', 14, start, prefix);
    Check((w = 1) and (start = 13) and (prefix = '1'), 'the cursor after "1" is in the first parameter');
    w := StrataWordAt('/gun/energy 1 ', 15, start, prefix);
    Check((w = 2) and (prefix = ''), 'after a space the next parameter starts');
    w := StrataWordAt('# /gun/energy', 5, start, prefix);
    Check(w = -1, 'a comment line has no words');
    w := StrataWordAt('/gun/energy 1 MeV # 3', 21, start, prefix);
    Check(w = -1, 'neither has the comment at the end of a line');

    tree.Complete('/', 2, L, start);
    Check(Listed(L) = '/gun/ /run/ /strata/', 'under / come the top directories');
    tree.Complete('/ru', 4, L, start);
    Check((Listed(L) = '/run/') and (start = 1), 'a partial directory completes');
    tree.Complete('/run/', 6, L, start);
    Check(Listed(L) = '/run/beamOn /run/initialize /run/particle/ /run/physicsModified',
          'one level down, commands and the subdirectory');
    tree.Complete('/run/p', 7, L, start);
    Check(Listed(L) = '/run/particle/ /run/physicsModified', 'filtered by what is typed');
    tree.Complete('/gun/particle pr', 17, L, start);
    Check((Listed(L) = 'proton') and (start = 15), 'a parameter completes from its candidates');
    tree.Complete('/gun/particle ', 15, L, start);
    Check(L.Count = 4, 'all of them before anything is typed');
    tree.Complete('/strata/flag ', 14, L, start);
    Check(Listed(L) = 'true false', 'a boolean offers true and false');
    tree.Complete('/run/beamOn ', 13, L, start);
    Check(L.Count = 0, 'a number offers nothing');
    tree.Complete('# /ru', 6, L, start);
    Check(L.Count = 0, 'nothing in a comment');
    tree.Complete('gun', 4, L, start);
    Check(L.Count = 0, 'nothing for a relative path');
    tree.Complete('/strata/layerMat 0 G4_', 23, L, start);
    Check(L.Count = 0, 'no materials until a list is given');
    mats := TStringList.Create;
    try
      mats.CommaText := 'G4_Si,G4_WATER,Vacuum';
      tree.Materials := mats;
      tree.Complete('/strata/layerMat 0 G4_', 23, L, start);
      Check(Listed(L) = 'G4_Si G4_WATER', 'a material parameter offers the materials');
      tree.Complete('/strata/layerMat ', 18, L, start);
      Check(L.Count = 0, 'but not the parameter before it');
    finally
      tree.Materials := nil;
      mats.Free;
    end;

    help := tree.Describe('/gun/energy 1 MeV', 18);
    Check(Pos('/gun/energy  Energy  [Unit]', help) = 1, 'the help marks the parameter the cursor is in');
    Check(Pos('one of: eV keV MeV GeV', help) > 0, '  and lists what it takes');
    Check(Pos('default GeV', help) > 0, '  and its default');
    Check(Pos('Set kinetic energy.', help) > 0, '  and the command''s guidance');
    help := tree.Describe('/run/beamOff 10', 3);
    Check(help = '/run/beamOff: no such command', 'an unknown command is said to be one');
    help := tree.Describe('/run/beamOn 10 20', 17);
    Check(Pos('no more parameters', help) > 0, 'a word too many is pointed out');
  finally
    L.Free;
    tree.Free;
  end;

  WriteLn;
  if Failures = 0 then
    WriteLn('PASSED (0 failures)')
  else
    WriteLn(Format('FAILED (%d failures)', [Failures]));
  Halt(Ord(Failures <> 0));
end.
