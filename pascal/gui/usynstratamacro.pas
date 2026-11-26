{==============================================================================
  uSynStrataMacro.pas: syntax colours for a Geant4 macro.

  A line is a command path and its parameters, or a comment.  The first word
  is coloured as a command when the command tree knows it, as an error when
  it does not, and plainly while no tree has been read.  Words are whatever
  lies between spaces, as Geant4 reads them, which is also what completion
  replaces.
==============================================================================}

unit uSynStrataMacro;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditHighlighter, SynEditTypes,
  uStrataCommands;

type
  TStrataMacroToken = (smtNull, smtSpace, smtComment, smtCommand,
    smtDirectory, smtUnknown, smtNumber, smtString, smtAlias, smtText);

  { TSynStrataMacroSyn }

  TSynStrataMacroSyn = class(TSynCustomHighlighter)
  private
    FLine: PChar;
    FLineLen: Integer;
    FRun: Integer;
    FTokenPos: Integer;
    FToken: TStrataMacroToken;
    FWordIndex: Integer;
    FTree: TStrataCommandTree;
    FCommentAttri: TSynHighlighterAttributes;
    FCommandAttri: TSynHighlighterAttributes;
    FDirectoryAttri: TSynHighlighterAttributes;
    FUnknownAttri: TSynHighlighterAttributes;
    FNumberAttri: TSynHighlighterAttributes;
    FStringAttri: TSynHighlighterAttributes;
    FAliasAttri: TSynHighlighterAttributes;
    FTextAttri: TSynHighlighterAttributes;
    FSpaceAttri: TSynHighlighterAttributes;
    function IsWordChar(AIndex: Integer): Boolean;
    function CommandToken(const AWord: String): TStrataMacroToken;
  protected
    function GetIdentChars: TSynIdentChars; override;
  public
    class function GetLanguageName: string; override;
    constructor Create(AOwner: TComponent); override;
    procedure SetLine(const NewValue: String; LineNumber: Integer); override;
    procedure Next; override;
    function GetEol: Boolean; override;
    function GetToken: String; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: integer; override;
    function GetTokenPos: Integer; override;
    function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
    // The tree the commands are checked against; nil to check nothing
    property Tree: TStrataCommandTree read FTree write FTree;
  end;

implementation

const
  // Everything but spaces and quotes is part of a word
  MacroWordChars: TSynIdentChars = [#33, #35..#126];

constructor TSynStrataMacroSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCommentAttri := TSynHighlighterAttributes.Create('Comment', 'Comment');
  FCommentAttri.Foreground := clGreen;
  FCommentAttri.Style := [fsItalic];
  AddAttribute(FCommentAttri);
  FCommandAttri := TSynHighlighterAttributes.Create('Command', 'Command');
  FCommandAttri.Foreground := clNavy;
  FCommandAttri.Style := [fsBold];
  AddAttribute(FCommandAttri);
  FDirectoryAttri := TSynHighlighterAttributes.Create('Directory', 'Directory');
  FDirectoryAttri.Foreground := clNavy;
  AddAttribute(FDirectoryAttri);
  FUnknownAttri := TSynHighlighterAttributes.Create('Unknown command', 'UnknownCommand');
  FUnknownAttri.Foreground := clRed;
  FUnknownAttri.Style := [fsUnderline];
  AddAttribute(FUnknownAttri);
  FNumberAttri := TSynHighlighterAttributes.Create('Number', 'Number');
  FNumberAttri.Foreground := clTeal;
  AddAttribute(FNumberAttri);
  FStringAttri := TSynHighlighterAttributes.Create('String', 'String');
  FStringAttri.Foreground := clMaroon;
  AddAttribute(FStringAttri);
  FAliasAttri := TSynHighlighterAttributes.Create('Alias', 'Alias');
  FAliasAttri.Foreground := clPurple;
  AddAttribute(FAliasAttri);
  FTextAttri := TSynHighlighterAttributes.Create('Text', 'Text');
  AddAttribute(FTextAttri);
  FSpaceAttri := TSynHighlighterAttributes.Create('Space', 'Space');
  AddAttribute(FSpaceAttri);
  SetAttributesOnChange(@DefHighlightChange);
end;

class function TSynStrataMacroSyn.GetLanguageName: string;
begin
  Result := 'Geant4 macro';
end;

function TSynStrataMacroSyn.GetIdentChars: TSynIdentChars;
begin
  Result := MacroWordChars;
end;

procedure TSynStrataMacroSyn.SetLine(const NewValue: String; LineNumber: Integer);
begin
  inherited;
  FLine := PChar(NewValue);
  FLineLen := Length(NewValue);
  FRun := 0;
  FWordIndex := 0;
  Next;
end;

function TSynStrataMacroSyn.IsWordChar(AIndex: Integer): Boolean;
begin
  Result := (AIndex < FLineLen) and (not (FLine[AIndex] in [#0, ' ', #9]));
end;

function TSynStrataMacroSyn.CommandToken(const AWord: String): TStrataMacroToken;
var
  e: TStrataCommandInfo;
begin
  if (AWord = '') or (AWord[1] <> '/') then Exit(smtText);
  if (FTree = nil) or (FTree.Count = 0) then Exit(smtCommand);
  e := FTree.Find(AWord);
  // A directory may be written without its closing '/'
  if (e = nil) and (AWord[Length(AWord)] <> '/') then e := FTree.Find(AWord + '/');
  if e = nil then
    Result := smtUnknown
  else if e.IsDirectory then
    Result := smtDirectory
  else
    Result := smtCommand;
end;

procedure TSynStrataMacroSyn.Next;
var
  word: String;
  i: Integer;
  numeric: Boolean;
begin
  FTokenPos := FRun;
  if FRun >= FLineLen then
  begin
    FToken := smtNull;
    Exit;
  end;
  // Spaces
  if FLine[FRun] in [' ', #9] then
  begin
    while (FRun < FLineLen) and (FLine[FRun] in [' ', #9]) do Inc(FRun);
    FToken := smtSpace;
    Exit;
  end;
  // A word starting with '#' is the comment, to the end of the line
  if FLine[FRun] = '#' then
  begin
    FRun := FLineLen;
    FToken := smtComment;
    Exit;
  end;
  // A quoted string, spaces and all
  if FLine[FRun] = '"' then
  begin
    Inc(FRun);
    while (FRun < FLineLen) and (FLine[FRun] <> '"') do Inc(FRun);
    if FRun < FLineLen then Inc(FRun);
    FToken := smtString;
    Inc(FWordIndex);
    Exit;
  end;
  // A word
  while IsWordChar(FRun) and (FLine[FRun] <> '"') do Inc(FRun);
  SetString(word, FLine + FTokenPos, FRun - FTokenPos);
  if FWordIndex = 0 then
    FToken := CommandToken(word)
  else if (word[1] = '{') and (word[Length(word)] = '}') then
    FToken := smtAlias
  else
  begin
    numeric := True;
    for i := 1 to Length(word) do
      if not (word[i] in ['0'..'9', '.', '+', '-', 'e', 'E']) then
      begin
        numeric := False;
        Break;
      end;
    if numeric and (word[1] in ['0'..'9', '.', '+', '-']) then
      FToken := smtNumber
    else
      FToken := smtText;
  end;
  Inc(FWordIndex);
end;

function TSynStrataMacroSyn.GetEol: Boolean;
begin
  Result := FToken = smtNull;
end;

function TSynStrataMacroSyn.GetToken: String;
begin
  SetString(Result, FLine + FTokenPos, FRun - FTokenPos);
end;

procedure TSynStrataMacroSyn.GetTokenEx(out TokenStart: PChar; out TokenLength: integer);
begin
  TokenStart := FLine + FTokenPos;
  TokenLength := FRun - FTokenPos;
end;

function TSynStrataMacroSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  case FToken of
    smtComment: Result := FCommentAttri;
    smtCommand: Result := FCommandAttri;
    smtDirectory: Result := FDirectoryAttri;
    smtUnknown: Result := FUnknownAttri;
    smtNumber: Result := FNumberAttri;
    smtString: Result := FStringAttri;
    smtAlias: Result := FAliasAttri;
    smtSpace: Result := FSpaceAttri;
  else
    Result := FTextAttri;
  end;
end;

function TSynStrataMacroSyn.GetTokenKind: integer;
begin
  Result := Ord(FToken);
end;

function TSynStrataMacroSyn.GetTokenPos: Integer;
begin
  Result := FTokenPos;
end;

function TSynStrataMacroSyn.GetDefaultAttribute(Index: integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT: Result := FCommentAttri;
    SYN_ATTR_KEYWORD: Result := FCommandAttri;
    SYN_ATTR_STRING: Result := FStringAttri;
    SYN_ATTR_NUMBER: Result := FNumberAttri;
    SYN_ATTR_WHITESPACE: Result := FSpaceAttri;
  else
    Result := nil;
  end;
end;

end.
