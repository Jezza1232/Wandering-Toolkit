@echo off
title The All Seeing Eye Watchdog
setlocal EnableDelayedExpansion
set SCRIPT_DIR=%~dp0
set WATCHDOG=%SCRIPT_DIR%watchdog.ps1
if not exist "%WATCHDOG%" (
    echo ERROR: watchdog.ps1 not found next to this file.
    pause
    exit /b 1
)

echo Launching The All Seeing Eye (prefers PowerShell 7)...
set "PS_CMD=powershell"
where /q pwsh.exe
if %errorlevel%==0 set "PS_CMD=pwsh.exe"

set "USER_ARGS=%*"
set "RUN_ARGS=%USER_ARGS%"
if not defined RUN_ARGS set "RUN_ARGS=-AutoRestart -PollSeconds 60"

echo Using: %PS_CMD%
echo Script: %WATCHDOG%
echo Args  : %RUN_ARGS%

:run_watchdog
"%PS_CMD%" -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%WATCHDOG%" %RUN_ARGS%
set "RC=%errorlevel%"
echo Watchdog exited with code %RC%.
if %RC% NEQ 0 (
    echo Restarting watchdog after crash with AutoRestart and 60s poll...
    set "RUN_ARGS=%USER_ARGS%"
    if not defined RUN_ARGS set "RUN_ARGS=-AutoRestart -PollSeconds 60"
    echo !RUN_ARGS! ^| findstr /I "AutoRestart" >nul || set "RUN_ARGS=!RUN_ARGS! -AutoRestart"
    echo !RUN_ARGS! ^| findstr /I "PollSeconds" >nul || set "RUN_ARGS=!RUN_ARGS! -PollSeconds 60"
    timeout /t 5 >nul
    goto run_watchdog
)
pause
endlocal
