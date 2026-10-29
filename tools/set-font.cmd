@echo off
setlocal
rem ===========================================================================
rem  set-font.cmd - replace the fonts used by the TF2 "!000_customfont" mod
rem
rem  Usage:  set-font.cmd <font.ttf> [options]
rem          set-font.cmd -Font "tf2=2.ttf,build=1.ttf,secondary=1.ttf,professor=2.ttf"
rem  Put several -Font entries in one quoted argument (PowerShell does not
rem  allow the same parameter name twice). Run "set-font.cmd -Help" for the
rem  full option list (roles, -Keep, -ListFonts, -Hud, -NoRange, -Target,
rem  -Restore).
rem ===========================================================================

set "PS_SCRIPT=%~dp0set-font.ps1"

if not exist "%PS_SCRIPT%" (
    echo [x] set-font.ps1 was not found next to this file.
    exit /b 1
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [x] Windows PowerShell was not found. Windows 10/11 should include it.
    exit /b 1
)

powershell.exe -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
set "RC=%errorlevel%"

rem When started by double-click or by dropping a font onto this file, keep the
rem window open so the result can be read.
echo "%cmdcmdline%" | find /i "%~nx0" >nul
if not errorlevel 1 pause

exit /b %RC%
