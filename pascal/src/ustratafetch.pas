unit uStrataFetch;

// Fetching the Geant4 datasets, for a front end that would rather not send
// the user back to an installer.
//
// Everything happens in bounded steps driven from a timer, so the window
// stays alive without a thread: Step() starts a transfer, or reads one chunk
// of a checksum, or unpacks a few files, and returns. The transfer itself is
// curl or wget, which every platform the front end is built for has (macOS
// and Windows 10 ship them, Linux distributions carry them) and which bring
// resume and proxy support with them. A lab behind a proxy needs no setting
// here: curl reads http_proxy and the rest of the environment itself.
//
// The checksums are Geant4's own, out of the table the installers are built
// from, and the archives are unpacked in process rather than by calling tar,
// which Windows only acquired recently.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, md5, zstream, libtar, uStrataDatasets;

type
  TStrataFetchStage = (fsIdle, fsSizing, fsDownloading, fsVerifying,
                       fsExtracting, fsFinished, fsFailed);

  { TStrataFetcher }

  TStrataFetcher = class
  private
    FDestination: String;
    FWanted: array of Boolean;
    FIndex: Integer;                 // the dataset in hand
    FStage: TStrataFetchStage;
    FStatus: String;
    FFailed: String;

    FChild: TProcess;
    FReply: String;                  // what it has said for itself so far
    FArchive: String;                // where the archive is being written
    FFileTotal: Int64;               // what the server says it is
    FFileDone: Int64;
    FDoneBefore: Int64;              // bytes of the whole job before this one
    FTotal: Int64;
    FResumedFrom: Int64;
    FRetried: Boolean;

    FContext: TMD5Context;
    FReader: TFileStream;
    FGz: TGZFileStream;
    FTar: TTarArchive;
    FUnpacked: Int64;

    procedure Fail(const AWhy: String);
    procedure DrainChild;
    procedure CloseChild;
    procedure CloseStreams;
    function DownloadDir: String;
    function NextWanted: Boolean;
    procedure BeginSizing;
    procedure FinishSizing;
    procedure BeginDownload;
    procedure FinishDownload;
    procedure BeginVerify;
    procedure StepVerify;
    procedure BeginExtract;
    procedure StepExtract;
  public
    destructor Destroy; override;

    // ADestination is the directory the dataset directories go into, the one
    // GEANT4_DATA_DIR is then pointed at. AWanted is indexed like
    // kStrataDatasets
    function Start(const ADestination: String; const AWanted: array of Boolean;
                   out AError: String): Boolean;
    // Called from a timer. Returns quickly, whatever the stage
    procedure Step;
    procedure Stop;

    property Stage: TStrataFetchStage read FStage;
    property Status: String read FStatus;
    property Failed: String read FFailed;
    property Index: Integer read FIndex;
    property FileDone: Int64 read FFileDone;
    property FileTotal: Int64 read FFileTotal;
    property BytesDone: Int64 read FDoneBefore;
    property BytesTotal: Int64 read FTotal;
  end;

// The program that will do the transfers, empty when there is none
function StrataDownloader: String;

// Whether a dataset is installed under ABase. The same test the backend
// makes: a directory is not enough, because the shared parent holds nothing
// but subdirectories and would pass, so it has to hold a file of its own
function StrataDatasetPresent(const ABase: String;
                              const ADataset: TStrataDataset): Boolean;

// What a size looks like to a person
function StrataBytesText(ABytes: Int64): String;

implementation

const
  // Read or unpack this much per step. Large enough that a 350 MB dataset is
  // checksummed in a couple of seconds, small enough that a window redrawing
  // ten times a second never misses a beat
  kChunk = 16*1024*1024;

// Looked up here rather than with FindDefaultExecutablePath, so that nothing
// in pascal/src needs Lazarus and the tests can link it on its own
function FindOnPath(const AName: String): String;
var
  dirs: TStringList;
  i: Integer;
  name_, cand: String;
begin
  Result := '';
  name_ := AName;
  {$IFDEF WINDOWS}
  if ExtractFileExt(name_) = '' then name_ := name_ + '.exe';
  {$ENDIF}

  dirs := TStringList.Create;
  try
    dirs.Delimiter := PathSeparator;
    dirs.StrictDelimiter := True;
    dirs.DelimitedText := GetEnvironmentVariable('PATH');
    for i := 0 to dirs.Count - 1 do
    begin
      // A Windows PATH is allowed to quote an entry, and a stray quote makes
      // the directory look as though it is not there
      cand := Trim(StringReplace(dirs[i], '"', '', [rfReplaceAll]));
      if cand = '' then Continue;
      cand := IncludeTrailingPathDelimiter(cand) + name_;
      if FileExists(cand) then Exit(cand);
    end;
  finally
    dirs.Free;
  end;
end;

function StrataDownloader: String;
begin
  Result := FindOnPath('curl');
  if Result = '' then Result := FindOnPath('wget');
end;

// How large a file is, taken from the directory entry rather than by opening
// it: this is asked of a file the downloader still has open for writing, and
// on Windows a second handle to that can be refused outright
function SizeOfFile(const AName: String): Int64;
var
  found: TSearchRec;
begin
  Result := 0;
  if FindFirst(AName, faAnyFile, found) = 0 then
  begin
    Result := found.Size;
    FindClose(found);
  end;
end;

function StrataDatasetPresent(const ABase: String;
                              const ADataset: TStrataDataset): Boolean;
var
  dir: String;
  found: TSearchRec;
begin
  Result := False;
  if Trim(ABase) = '' then Exit;
  dir := IncludeTrailingPathDelimiter(ABase) + ADataset.Directory;
  if not DirectoryExists(dir) then Exit;

  if FindFirst(IncludeTrailingPathDelimiter(dir) + '*', faAnyFile, found) = 0 then
  begin
    repeat
      if (found.Attr and faDirectory) = 0 then
      begin
        Result := True;
        Break;
      end;
    until FindNext(found) <> 0;
    FindClose(found);
  end;
end;

// Decimal, because that is what the server reports and what a browser would
// have shown: 350393595 bytes is the 350 MB Geant4 calls it, and the 334 MiB
// a file manager calls it is nobody's idea of the download size
function StrataBytesText(ABytes: Int64): String;
begin
  if ABytes >= 1000*1000*1000 then
    Result := Format('%.1f GB', [ABytes/1.0e9])
  else if ABytes >= 1000*1000 then
    Result := Format('%.0f MB', [ABytes/1.0e6])
  else if ABytes >= 1000 then
    Result := Format('%.0f kB', [ABytes/1.0e3])
  else
    Result := Format('%d bytes', [ABytes]);
end;

{ TStrataFetcher }

destructor TStrataFetcher.Destroy;
begin
  CloseChild;
  CloseStreams;
  inherited Destroy;
end;

procedure TStrataFetcher.Fail(const AWhy: String);
begin
  CloseChild;
  CloseStreams;
  FFailed := AWhy;
  FStatus := AWhy;
  FStage := fsFailed;
end;

// Read whatever the downloader has written, every time it is looked at.  A
// pipe nobody empties fills at 64 kB and the child then blocks on its next
// write, waiting for a reader that is waiting for it to finish
procedure TStrataFetcher.DrainChild;
var
  n: Integer;
  buf: array[0..4095] of AnsiChar;
begin
  if FChild = nil then Exit;
  while FChild.Output.NumBytesAvailable > 0 do
  begin
    n := FChild.Output.Read(buf[0], SizeOf(buf));
    if n <= 0 then Break;
    FReply := FReply + Copy(String(buf), 1, n);
    // A downloader with that much to say has gone wrong in a way the message
    // will not explain any better for being complete
    if Length(FReply) > 64*1024 then Break;
  end;
end;

procedure TStrataFetcher.CloseChild;
begin
  if FChild = nil then Exit;
  if FChild.Running then FChild.Terminate(1);
  FreeAndNil(FChild);
end;

procedure TStrataFetcher.CloseStreams;
begin
  FreeAndNil(FTar);
  FreeAndNil(FGz);
  FreeAndNil(FReader);
end;

function TStrataFetcher.DownloadDir: String;
begin
  // Beside the datasets rather than in the temporary directory, so that a
  // partly fetched 350 MB archive survives a reboot and can be resumed
  Result := IncludeTrailingPathDelimiter(FDestination) + '.download';
end;

function TStrataFetcher.Start(const ADestination: String;
  const AWanted: array of Boolean; out AError: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  AError := '';
  CloseChild;
  CloseStreams;

  if StrataDownloader = '' then
  begin
    AError := 'Neither curl nor wget could be found, and one of them is what '
              + 'fetches the archives.';
    Exit;
  end;

  FDestination := ExcludeTrailingPathDelimiter(Trim(ADestination));
  if FDestination = '' then
  begin
    AError := 'No directory to download into.';
    Exit;
  end;
  if not ForceDirectories(DownloadDir) then
  begin
    AError := 'Could not create ' + DownloadDir;
    Exit;
  end;

  SetLength(FWanted, kStrataDatasetCount);
  for i := 0 to kStrataDatasetCount - 1 do
    FWanted[i] := (i <= High(AWanted)) and AWanted[i];

  FIndex := -1;
  FTotal := 0;
  FDoneBefore := 0;
  FFileDone := 0;
  FFileTotal := 0;
  FFailed := '';
  FStatus := '';
  FStage := fsIdle;
  if not NextWanted then
  begin
    AError := 'Nothing selected.';
    Exit;
  end;
  Result := True;
end;

function TStrataFetcher.NextWanted: Boolean;
begin
  Result := False;
  CloseChild;
  CloseStreams;
  FDoneBefore := FDoneBefore + FFileTotal;
  FFileDone := 0;
  FFileTotal := 0;
  FRetried := False;

  repeat
    Inc(FIndex);
  until (FIndex >= kStrataDatasetCount) or FWanted[FIndex];

  if FIndex >= kStrataDatasetCount then
  begin
    FStage := fsFinished;
    FStatus := 'Done';
    Exit;
  end;

  BeginSizing;
  Result := True;
end;

// How big the archive is, asked of the server rather than kept in the table:
// a size is the one thing about a dataset that the Geant4 release notes do
// not publish, and a progress bar without a total is no use
procedure TStrataFetcher.BeginSizing;
begin
  FStage := fsSizing;
  FStatus := 'Asking about ' + kStrataDatasets[FIndex].Archive;
  FReply := '';
  FChild := TProcess.Create(nil);
  FChild.Executable := StrataDownloader;
  if Pos('wget', LowerCase(ExtractFileName(FChild.Executable))) > 0 then
  begin
    FChild.Parameters.Add('--spider');
    FChild.Parameters.Add('--server-response');
    FChild.Parameters.Add('-q');
  end
  else
  begin
    FChild.Parameters.Add('-sIL');
  end;
  FChild.Parameters.Add(kStrataDatasetBaseURL + '/'
                        + kStrataDatasets[FIndex].Archive);
  // poNoConsole as well on Windows: curl is a console program, and without it
  // a black window flashes up for every archive and every size enquiry
  FChild.Options := [poUsePipes, poStderrToOutPut]
                    {$IFDEF WINDOWS} + [poNoConsole]{$ENDIF};
  try
    FChild.Execute;
  except
    on E: Exception do Fail('Could not start ' + FChild.Executable + ': ' + E.Message);
  end;
end;

procedure TStrataFetcher.FinishSizing;
var
  reply: TStringList;
  i, p: Integer;
  line: String;
begin
  DrainChild;
  reply := TStringList.Create;
  try
    reply.Text := FReply;
    for i := 0 to reply.Count - 1 do
    begin
      line := LowerCase(Trim(reply[i]));
      p := Pos('content-length:', line);
      if p = 1 then
        FFileTotal := StrToInt64Def(Trim(Copy(line, Length('content-length:') + 1,
                                              MaxInt)), FFileTotal);
    end;
  finally
    reply.Free;
  end;
  CloseChild;

  // A server that will not say is no reason to stop; the bar just has
  // nothing to fill until the file is there
  FTotal := FTotal + FFileTotal;
  BeginDownload;
end;

procedure TStrataFetcher.BeginDownload;
var
  wget: Boolean;
begin
  FStage := fsDownloading;
  FArchive := IncludeTrailingPathDelimiter(DownloadDir)
              + kStrataDatasets[FIndex].Archive;
  FResumedFrom := SizeOfFile(FArchive);

  if FResumedFrom > 0 then
    FStatus := 'Resuming ' + kStrataDatasets[FIndex].Archive + ' at '
               + StrataBytesText(FResumedFrom)
  else
    FStatus := 'Downloading ' + kStrataDatasets[FIndex].Archive;

  FReply := '';
  FChild := TProcess.Create(nil);
  FChild.Executable := StrataDownloader;
  wget := Pos('wget', LowerCase(ExtractFileName(FChild.Executable))) > 0;
  if wget then
  begin
    FChild.Parameters.Add('-q');
    FChild.Parameters.Add('--tries=3');
    if FResumedFrom > 0 then FChild.Parameters.Add('-c');
    FChild.Parameters.Add('-O');
    FChild.Parameters.Add(FArchive);
  end
  else
  begin
    FChild.Parameters.Add('-sSLf');
    FChild.Parameters.Add('--retry');
    FChild.Parameters.Add('3');
    if FResumedFrom > 0 then
    begin
      FChild.Parameters.Add('-C');
      FChild.Parameters.Add('-');
    end;
    FChild.Parameters.Add('-o');
    FChild.Parameters.Add(FArchive);
  end;
  FChild.Parameters.Add(kStrataDatasetBaseURL + '/'
                        + kStrataDatasets[FIndex].Archive);
  // poNoConsole as well on Windows: curl is a console program, and without it
  // a black window flashes up for every archive and every size enquiry
  FChild.Options := [poUsePipes, poStderrToOutPut]
                    {$IFDEF WINDOWS} + [poNoConsole]{$ENDIF};
  try
    FChild.Execute;
  except
    on E: Exception do Fail('Could not start ' + FChild.Executable + ': ' + E.Message);
  end;
end;

procedure TStrataFetcher.FinishDownload;
var
  code: Integer;
begin
  DrainChild;
  // ExitStatus is the raw wait status on Unix, where 22 arrives as 5632
  code := FChild.ExitCode;
  if code <> 0 then
  begin
    Fail(Format('%s stopped with %d while fetching %s. %s',
         [ExtractFileName(StrataDownloader), code,
          kStrataDatasets[FIndex].Archive, Trim(FReply)]));
    Exit;
  end;
  CloseChild;
  BeginVerify;
end;

procedure TStrataFetcher.BeginVerify;
begin
  FStage := fsVerifying;
  FStatus := 'Checking ' + kStrataDatasets[FIndex].Archive;
  MD5Init(FContext);
  try
    FReader := TFileStream.Create(FArchive, fmOpenRead or fmShareDenyNone);
  except
    on E: Exception do
    begin
      Fail('Could not read ' + FArchive + ': ' + E.Message);
      Exit;
    end;
  end;
  FFileDone := 0;
end;

procedure TStrataFetcher.StepVerify;
var
  buf: array of Byte;
  n: Integer;
  digest: TMD5Digest;
  got: String;
begin
  SetLength(buf, kChunk);
  n := FReader.Read(buf[0], kChunk);
  if n > 0 then
  begin
    MD5Update(FContext, buf[0], n);
    FFileDone := FFileDone + n;
    Exit;
  end;

  CloseStreams;
  MD5Final(FContext, digest);
  got := LowerCase(MD5Print(digest));
  if got <> LowerCase(kStrataDatasets[FIndex].MD5) then
  begin
    // A half-written archive that was resumed into is the likely cause, so
    // it is thrown away and fetched once more before giving up
    DeleteFile(FArchive);
    if FRetried then
    begin
      Fail(Format('%s did not match its checksum (%s, expected %s)',
           [kStrataDatasets[FIndex].Archive, got, kStrataDatasets[FIndex].MD5]));
      Exit;
    end;
    FRetried := True;
    FStatus := kStrataDatasets[FIndex].Archive
               + ' did not match its checksum; fetching it again';
    BeginDownload;
    Exit;
  end;

  BeginExtract;
end;

procedure TStrataFetcher.BeginExtract;
begin
  FStage := fsExtracting;
  FStatus := 'Unpacking ' + kStrataDatasets[FIndex].Archive;
  FUnpacked := 0;
  try
    ForceDirectories(FDestination);
    FGz := TGZFileStream.Create(FArchive, gzopenread);
    FTar := TTarArchive.Create(FGz);
    FTar.Reset;
  except
    on E: Exception do
    begin
      Fail('Could not open ' + FArchive + ': ' + E.Message);
      Exit;
    end;
  end;
end;

procedure TStrataFetcher.StepExtract;
var
  rec: TTarDirRec;
  path: String;
  budget: Int64;
begin
  budget := 0;
  try
    while budget < kChunk do
    begin
      if not FTar.FindNext(rec) then
      begin
        CloseStreams;
        // The archive has done its job; 1.5 GB of them is not worth keeping
        DeleteFile(FArchive);
        NextWanted;
        Exit;
      end;

      path := IncludeTrailingPathDelimiter(FDestination)
              + StringReplace(rec.Name, '/', PathDelim, [rfReplaceAll]);
      case rec.FileType of
        ftDirectory:
          ForceDirectories(path);
        ftNormal:
          begin
            ForceDirectories(ExtractFilePath(path));
            FTar.ReadFile(path);
            budget := budget + rec.Size;
            FUnpacked := FUnpacked + rec.Size;
          end;
      end;
    end;
  except
    on E: Exception do Fail('Could not unpack ' + FArchive + ': ' + E.Message);
  end;
end;

procedure TStrataFetcher.Step;
begin
  case FStage of
    fsSizing:
      begin
        DrainChild;
        if (FChild <> nil) and (not FChild.Running) then FinishSizing;
      end;
    fsDownloading:
      begin
        DrainChild;
        FFileDone := SizeOfFile(FArchive);
        if (FChild <> nil) and (not FChild.Running) then FinishDownload;
      end;
    fsVerifying:
      StepVerify;
    fsExtracting:
      StepExtract;
  end;
end;

procedure TStrataFetcher.Stop;
begin
  CloseChild;
  CloseStreams;
  // Whatever has arrived stays where it is, to be resumed
  FStatus := 'Stopped';
  FStage := fsIdle;
end;

end.
