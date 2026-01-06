@echo off
setlocal

set SCRIPT_DIR=%~dp0
set "SEARCH_NAME=Wandering-ToolKit"
set "SEARCH_DIR=%CD%"

rem Elevate if not running as admin (robust UAC check via PowerShell).
powershell -NoLogo -NoProfile -Command "if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Start-Process -FilePath '%~f0' -Verb RunAs; exit 1 }" >nul 2>nul
if errorlevel 1 exit /b

:find_toolkit
if exist "%SEARCH_DIR%\%SEARCH_NAME%\menu.bat" (
	set "SCRIPT_DIR=%SEARCH_DIR%\%SEARCH_NAME%\"
	goto have_root
)
for %%P in ("%SEARCH_DIR%") do if "%%~fP"=="%%~dpP" goto have_root
for %%P in ("%SEARCH_DIR%\..") do set "SEARCH_DIR=%%~fP"
goto find_toolkit

:have_root
echo Using toolkit root: %SCRIPT_DIR%

rem Prefer PowerShell 7 (pwsh) if available; fall back to Windows PowerShell.
set POWERSHELL_EXE=
for %%P in (pwsh.exe) do (
	where %%P >nul 2>nul
	if not errorlevel 1 (
		set POWERSHELL_EXE=%%P
	)
)

if "%POWERSHELL_EXE%"=="" set POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

"%POWERSHELL_EXE%" -NoLogo -ExecutionPolicy Bypass -File "%SCRIPT_DIR%data\main\menu.ps1"

endlocal
