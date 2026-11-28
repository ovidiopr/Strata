{==============================================================================
  uResultsFrame.pas: the run summary and the voxel doses of the last run.
  Shown by both the panels and the macro editor, so that the two cannot
  drift apart.  Read-only views of what the engine reports.
==============================================================================}

unit uResultsFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, ExtCtrls, Grids, StdCtrls,
  uStrataApi, uStrataEngine;

type

  { TResultsFrame }

  TResultsFrame = class(TFrame)
    pnlSummary: TPanel;
    sgSummary: TStringGrid;
    spltResults: TSplitter;
    sgVoxels: TStringGrid;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowResults(AEngine: TStrataEngine);
    procedure Clear;
  end;

implementation

{$R *.lfm}

{ TResultsFrame }

constructor TResultsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Clear;
end;

procedure TResultsFrame.Clear;
begin
  sgSummary.ColCount := 2;
  sgSummary.RowCount := 2;
  sgSummary.FixedRows := 1;
  sgSummary.Clean([gzNormal]);
  sgSummary.Cells[0, 0] := 'Quantity';
  sgSummary.Cells[1, 0] := 'Value';

  sgVoxels.ColCount := 5;
  sgVoxels.RowCount := 2;
  sgVoxels.FixedRows := 1;
  sgVoxels.Clean([gzNormal]);
  sgVoxels.Cells[0, 0] := 'Voxel';
  sgVoxels.Cells[1, 0] := 'Edep (MeV)';
  sgVoxels.Cells[2, 0] := 'Fraction (%)';
  sgVoxels.Cells[3, 0] := 'Dose (Gy)';
  sgVoxels.Cells[4, 0] := 'Mass (g)';
end;

procedure TResultsFrame.ShowResults(AEngine: TStrataEngine);
var
  s: TStrataRunStatsC;
  v: TStrataVoxelDoseArray;
  i: Integer;

  procedure Put(ARow: Integer; const AName, AValue: String);
  begin
    sgSummary.Cells[0, ARow] := AName;
    sgSummary.Cells[1, ARow] := AValue;
  end;

  function Pm(AValue, ARms: Double; const AUnit: String): String;
  begin
    Result := Format('%.5g +- %.3g %s', [AValue, ARms, AUnit]);
  end;

begin
  if (AEngine = nil) or (not AEngine.IsOpen) or (not AEngine.HasResults) then Exit;
  s := AEngine.Stats;

  sgSummary.RowCount := 19;
  Put(1, 'Primary', AEngine.ParticleName);
  Put(2, 'Beam energy', Format('%.5g MeV', [s.beamEnergy]));
  Put(3, 'Events', IntToStr(s.events));
  Put(4, 'Target thickness', Format('%.5g mm', [s.targetThickness]));
  Put(5, 'Energy deposited/event', Pm(s.edep, s.edepRms, 'MeV'));
  Put(6, 'NIEL/event', Pm(s.niel, s.nielRms, 'MeV'));
  Put(7, 'Energy balance', Format('%.5g MeV', [s.energyBalance]));
  Put(8, 'Projected range', Pm(s.projRange, s.projRangeRms, 'mm'));
  Put(9, 'Primary steps/event', Format('%.4g', [s.meanPrimarySteps]));
  Put(10, 'Track length (charged)', Pm(s.trakLenCharged, s.trakLenChargedRms, 'mm'));
  Put(11, 'Track length (neutral)', Pm(s.trakLenNeutral, s.trakLenNeutralRms, 'mm'));
  Put(12, 'Secondaries/event', Format('%.4g e-, %.4g gamma, %.4g e+', [s.electronPerEvent, s.gammaPerEvent, s.positronPerEvent]));
  Put(13, 'Transmitted',Format('%.4g %% primary, %.4g %% any', [s.transmitPrimary, s.transmitAny]));
  Put(14, 'Reflected', Format('%.4g %% primary, %.4g %% any', [s.reflectPrimary, s.reflectAny]));
  Put(15, 'Mean dE/dx (simulated)', Format('%.5g MeV/mm', [s.meanDEdx]));
  Put(16, 'dE/dx restricted (table)', Format('%.5g MeV/mm', [s.dedxRestricted]));
  Put(17, 'dE/dx full (table)', Format('%.5g MeV/mm', [s.dedxFull]));
  Put(18, 'MSC theta0 (Highland)', Format('%.5g mrad', [s.mscHighland*1000.0]));

  v := AEngine.VoxelDoses;
  sgVoxels.RowCount := Max(2, Length(v) + 1);
  for i := 0 to High(v) do
  begin
    sgVoxels.Cells[0, i + 1] := IntToStr(i);
    sgVoxels.Cells[1, i + 1] := Format('%.6g', [v[i].Edep]);
    sgVoxels.Cells[2, i + 1] := Format('%.4g', [v[i].Ratio]);
    sgVoxels.Cells[3, i + 1] := Format('%.6g', [v[i].Dose]);
    sgVoxels.Cells[4, i + 1] := Format('%.6g', [v[i].Mass]);
  end;
end;

end.
