; ============================================================================
; Kitsu v2.4.1 - Windows NSIS Installer Script (.exe)
; ============================================================================
!include "MUI2.nsh"

Name "Kitsu v2.4.1"
OutFile "..\..\dist\Kitsu-2.4.1-Setup-x64.exe"
InstallDir "$PROGRAMFILES64\Kitsu"
RequestExecutionLevel admin

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

Section "Kitsu Core (Lua + C++ + llama.cpp)" SecCore
  SetOutPath "$INSTDIR"
  File "..\..\README.md"
  File "..\..\CMakeLists.txt"

  SetOutPath "$INSTDIR\bin"
  File /nonfatal "..\..\bin\*.*"

  SetOutPath "$INSTDIR\lib"
  File /r "..\..\lib\*.*"

  SetOutPath "$INSTDIR\assets"
  File /r "..\..\assets\*.*"

  SetOutPath "$INSTDIR\themes"
  File /r "..\..\themes\*.*"

  CreateDirectory "$INSTDIR\models"

  CreateDirectory "$SMPROGRAMS\Kitsu"
  CreateShortCut "$SMPROGRAMS\Kitsu\Kitsu.lnk" "$INSTDIR\bin\kitsu-bin.exe"
  CreateShortCut "$DESKTOP\Kitsu.lnk" "$INSTDIR\bin\kitsu-bin.exe"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Kitsu.lnk"
  RMDir /r "$SMPROGRAMS\Kitsu"
  RMDir /r "$INSTDIR"
SectionEnd
