{==============================================================================
  StrataH1Probe.pas: exercises the histogram path the GUI uses, without the LCL.

  RefreshHistogramList walks every booked histogram with Histogram(i, False);
  ShowHistogram reads one with Histogram(id, True).  This program does the
  same, around a real run, and drains the backend log the way the GUI's timer
  does, so anything the backend complains about shows up here too.

  Run it when the window misbehaves around histograms: if this passes, the
  backend and the binding are fine and the fault is in the GUI layer.

      build/StrataH1Probe /path/to/libstrata.dylib [threads]
==============================================================================}
program StrataH1Probe;

{$mode objfpc}{$H+}

uses
  SysUtils, uStrataApi, uStrataEngine;

type
  { OnLogLine is a method pointer, so the sink needs an owner. }
  TLogSink = class
    Lines: Integer;
    procedure Receive(Sender: TObject; const ALine: string; AIsError: Boolean);
  end;

var
  eng: TStrataEngine;
  sink: TLogSink;
  Failures: Integer = 0;
  nt: Integer;

procedure TLogSink.Receive(Sender: TObject; const ALine: string;
  AIsError: Boolean);
begin
  Inc(Lines);
  if Pos('G4Exception', ALine) > 0 then
  begin
    WriteLn('    backend said: ', ALine);
    Flush(Output);
  end;
end;

procedure Drain;
begin
  eng.Poll;
end;

procedure Walk(const AWhen: string);
var
  i, n, act: Integer;
begin
  n := eng.HistogramCount;
  act := 0;
  for i := 0 to n - 1 do
    if eng.Histogram(i, False).Active then Inc(act);
  Drain;
  WriteLn(Format('  %-26s %d booked, %d active', [AWhen, n, act]));
  Flush(Output);
end;

{ The message the GUI puts on the status line when a spectrum that is
  switched on comes out flat.  Checked against the real h1[2] (which
  does fill once a nuclear-recoil process is in the list) and against
  the three shapes of empty spectrum. }
procedure CheckReasons;
var
  h: TStrataHistogram;
  nothing: array of Double;
  something: array of Double;
  msg: string;

  procedure Expect(const AWhat, AGot, AWanted: string);
  begin
    if AGot = AWanted then
      WriteLn(Format('  %-26s ok', [AWhat]))
    else
    begin
      WriteLn(Format('  %-26s FAILED  got "%s"', [AWhat, AGot]));
      Inc(Failures);
    end;
  end;

  function Mentions(const AText, AWord: string): Boolean;
  begin
    Result := Pos(AWord, AText) > 0;
  end;

begin
  h := eng.Histogram(2, True);
  msg := StrataEmptySpectrumReason(h.Id, h.Entries, h.Y, 'standardNR');
  Expect('h1[2] fills with recoils', msg, '');

  SetLength(nothing, 4);
  SetLength(something, 4);
  something[2] := 1.5;

  msg := StrataEmptySpectrumReason(2, 0, nothing, 'local');
  if not Mentions(msg, 'standardNR') then
  begin
    WriteLn('  h1[2] never filled          FAILED  got "', msg, '"');
    Inc(Failures);
  end
  else
    WriteLn('  h1[2] never filled          ok');

  msg := StrataEmptySpectrumReason(2, 1000, nothing, 'local');
  if not Mentions(msg, 'non-ionizing') then
  begin
    WriteLn('  h1[2] zero weights          FAILED  got "', msg, '"');
    Inc(Failures);
  end
  else
    WriteLn('  h1[2] zero weights          ok');

  msg := StrataEmptySpectrumReason(5, 1000, nothing, 'standardNR');
  if not Mentions(msg, 'outside the axis') then
  begin
    WriteLn('  any spectrum, empty bins    FAILED  got "', msg, '"');
    Inc(Failures);
  end
  else
    WriteLn('  any spectrum, empty bins    ok');

  msg := StrataEmptySpectrumReason(5, 1000, something, 'local');
  Expect('a spectrum with content', msg, '');
end;

procedure Plot(AId: Integer; const AWhen: string);
var
  h: TStrataHistogram;
begin
  h := eng.Histogram(AId, True);
  Drain;
  WriteLn(Format('  %-26s h1[%d] active=%-5s nbins=%d points=%d entries=%.0f',
    [AWhen, AId, BoolToStr(h.Active, True), h.NBins, Length(h.Y), h.Entries]));
  Flush(Output);
end;

var
  err: string;
begin
  if ParamCount < 1 then
  begin
    WriteLn('usage: StrataH1Probe <libstrata> [threads]');
    Halt(2);
  end;
  nt := StrToIntDef(ParamStr(2), 0);
  if not LoadStrataLibrary(ParamStr(1), err) then
  begin
    WriteLn('cannot load the backend: ', err);
    Halt(1);
  end;

  sink := TLogSink.Create;
  eng := TStrataEngine.Create;
  try
    eng.OnLogLine := @sink.Receive;
    eng.Open(nt);
    eng.Apply('/control/verbose 0');
    eng.Apply('/run/verbose 0');
    eng.Apply('/strata/physics/addPhysics standardNR');
    eng.Apply('/strata/geometry/layerNumber 1');
    eng.Apply('/strata/geometry/layerMaterial 0 G4_SILICON_DIOXIDE');
    eng.Apply('/strata/geometry/layerThickness 0 20 um');
    eng.Initialize;
    eng.Apply('/run/setCut 10 nm');
    eng.Apply('/gun/particle proton');
    eng.Apply('/gun/energy 1 MeV');
    Drain;

    WriteLn(Format('=== threads=%d ===', [nt]));
    Walk('after initialise');
    eng.Apply('/analysis/h1/set 1 50 0 20 um');
    eng.Apply('/analysis/h1/set 2 50 0 20 um');
    Walk('after activating h1[1] and h1[2]');
    Plot(1, 'before any run');

    eng.BeamOn(50);
    while eng.State in [STRATA_STATE_RUNNING, STRATA_STATE_ABORTING] do
    begin
      Drain;
      Sleep(50);
    end;
    Drain;

    Walk('after the run');
    Plot(1, 'after the run');
    Plot(2, 'after the run');
    CheckReasons;

    eng.Apply('/analysis/h1/setActivation 1 false');
    Walk('after deactivating h1[1]');

    eng.Close;
    if Failures = 0 then
      WriteLn(Format('PASSED (%d log lines drained, no faults)', [sink.Lines]))
    else
      WriteLn(Format('FAILED (%d checks)', [Failures]));
    Flush(Output);
  finally
    eng.Free;
    sink.Free;
  end;
  if StrataLibraryLoaded then strata_exit_process(0);
end.
