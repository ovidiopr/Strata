Unicode True

;=============================================================================
;  Strata: Windows installer
;
;  Installs the four things Strata is made of: the window (StrataGUI.exe),
;  the batch program (Strata.exe), the engine (strata_engine.exe) and the
;  backend the window drives it
;  through (strata.dll), plus the example macros.
;
;  Geant4 is NOT installed here.  It is a separate installer, because it is
;  shared with everything else built on it and because its data files are
;  downloaded on demand; Strata only needs it to be on PATH at run time.
;  The window says which of the data files are missing rather than letting
;  Geant4 abort when the physics tables are built.
;
;  Build with:
;      makensis /DPRODUCT_VERSION=1.0.0 windows\Strata.nsi
;  Any of PRODUCT_VERSION, PRODUCT_ARCH and BUILD_DIR may be overridden the
;  same way; the defaults below are what the Makefile passes.
;=============================================================================

!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "1.0.0"
!endif
!ifndef PRODUCT_ARCH
  !define PRODUCT_ARCH "win64-x86_64"
!endif
!ifndef BUILD_DIR
  !define BUILD_DIR "..\build\release\stage\bin"
!endif

!define PRODUCT_NAME "Strata"
!define EXE_NAME "StrataGUI.exe"
!define CLI_NAME "Strata.exe"
!define DLL_NAME "strata.dll"
!define ENGINE_NAME "strata_engine.exe"
!define PRODUCT_PUBLISHER "Ovidio Y. Pena Rodriguez"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\${EXE_NAME}"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
; The Geant4 version Strata is built against, from GEANT4_VERSION
!ifndef G4_VERSION
  !error "Pass /DG4_VERSION=<version>"
!endif
!define G4_URL "https://github.com/ovidiopr/geant4-installers/releases"

SetCompressor bzip2

BrandingText "(c) 2026 ${PRODUCT_PUBLISHER}"

; MUI 1.67 compatible ------
!include "x64.nsh"
!include "LogicLib.nsh"
!include "MUI.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "..\images\strata.ico"
!define MUI_UNICON "..\images\strata.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; Components page
!insertmacro MUI_PAGE_COMPONENTS
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE_NAME}"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; Reserve files
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS

; MUI end ------

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "Install-${PRODUCT_NAME}-${PRODUCT_VERSION}-${PRODUCT_ARCH}.exe"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show

Section "!${PRODUCT_NAME}" SEC01
  SetOutPath "$INSTDIR"
  SetOverwrite try
  File "${BUILD_DIR}\${EXE_NAME}"
  File "${BUILD_DIR}\${CLI_NAME}"
  File "${BUILD_DIR}\${DLL_NAME}"
  File "${BUILD_DIR}\${ENGINE_NAME}"
  File "..\images\strata.ico"

  ; The window looks for the backend next to its own executable first and
  ; the backend looks for the engine next to itself, so the three above are
  ; already where they will be found.

  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\${EXE_NAME}"
  SectionIn RO
SectionEnd

Section "Example macros" SEC02
  SetOutPath "$INSTDIR\macros"
  SetOverwrite try
  File "..\macros\*.mac"
  SetOutPath "$INSTDIR\configs"
  File "..\configs\*.scf"
SectionEnd

Section "Desktop link" SEC03
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\${EXE_NAME}"
  SetOverwrite try
SectionEnd

Section -AdditionalIcons
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\uninst.exe"
SectionEnd

Section -Post
  ; Use the register for 64 bits
  SetRegView 64

  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\${EXE_NAME}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\strata.ico"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoRepair" 1
SectionEnd

; Section descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC01} "The window, the batch program and the backend library"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC02} "Example macros and configurations"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC03} "Create a link on the desktop"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was removed."
FunctionEnd

; Geant4 has to be installed first
Function .onInit
  StrCpy $1 0
  loop:
    ${If} $1 == 0
      SetRegView 64
    ${Else}
      SetRegView 32
    ${EndIf}
    ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Geant4" "DisplayVersion"
    StrCmp $0 "${G4_VERSION}" found
    ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Geant4" "DisplayVersion"
    StrCmp $0 "${G4_VERSION}" found
    IntOp $1 $1 + 1
    IntCmp $1 2 0 loop
  SetRegView 64
  MessageBox MB_ICONEXCLAMATION|MB_YESNO "Strata needs Geant4 ${G4_VERSION}, which is not installed.$\r$\n$\r$\nInstall it from the Geant4 installers and run this installer again.$\r$\n$\r$\nOpen the download page?" IDNO +2
  ExecShell "open" "${G4_URL}"
  Abort
  found:
  SetRegView 64
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Remove $(^Name) and all of its components?" IDYES +2
  Abort
FunctionEnd

Section Uninstall
  Delete "$INSTDIR\uninst.exe"
  Delete "$INSTDIR\${EXE_NAME}"
  Delete "$INSTDIR\${CLI_NAME}"
  Delete "$INSTDIR\${DLL_NAME}"
  Delete "$INSTDIR\${ENGINE_NAME}"
  Delete "$INSTDIR\strata.ico"
  Delete "$INSTDIR\macros\*.mac"
  Delete "$INSTDIR\configs\*.scf"

  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"

  RMDir "$INSTDIR\macros"
  RMDir "$INSTDIR\configs"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  RMDir "$INSTDIR"

  ; Use the register for 64 bits
  SetRegView 64

  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
  SetAutoClose true
SectionEnd
