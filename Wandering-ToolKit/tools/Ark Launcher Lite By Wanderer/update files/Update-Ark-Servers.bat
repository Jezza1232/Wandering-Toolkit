@echo off
color 0A
title ASA Multi-Server Cluster-Updater

setlocal EnableDelayedExpansion
:: Resolve repo root (parent of this Main folder) and normalize path
pushd "%~dp0.." || goto :eof
set "ROOT=%CD%"

call :ensure_steamcmd || goto :eof

:: Paths and logs
set "UPDATE_DIR=%ROOT%\update files"
set "LOG_DIR=%ROOT%\Main\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set "MODE=update"
if /I "%INSTALL_MODE%"=="1" set "MODE=install"
if /I "%MODE%"=="install" (
    set "RUN_LOG=%LOG_DIR%\installs.log"
    set "PROMPT_LABEL=Enter servers to install (space-separated or ALL): "
) else (
    set "RUN_LOG=%LOG_DIR%\updates.log"
    set "PROMPT_LABEL=Enter servers to update (space-separated or ALL): "
)

if not exist "%UPDATE_DIR%" (
    echo Missing update directory: %UPDATE_DIR%
    popd
    endlocal
    goto :eof
)

:: Build available server list from files on disk
set "AVAILABLE_UPDATES="
for %%F in ("%UPDATE_DIR%\update_*.bat") do (
    set "NAME=%%~nF"
    set "NAME=!NAME:update_=!"
    set "AVAILABLE_UPDATES=!AVAILABLE_UPDATES! !NAME!"
)

echo Available servers to update: !AVAILABLE_UPDATES!
set /p TARGETS=%PROMPT_LABEL%
if /I "%TARGETS%"=="ALL" set "TARGETS=!AVAILABLE_UPDATES!"
if "!TARGETS!"=="" set "TARGETS=!AVAILABLE_UPDATES!"

:: Loop through selected servers sequentially
for %%S in (!TARGETS!) do (
    call :run_update "%%~S"
)

echo All %MODE%s finished.
popd
endlocal
goto :eof

:ensure_steamcmd
if exist "C:\steamcmd\steamcmd.exe" exit /b 0
echo steamcmd not found. Downloading to C:\steamcmd ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "\
    $zip = Join-Path $env:TEMP 'steamcmd.zip'; \
    Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip; \
    New-Item -ItemType Directory -Path 'C:\steamcmd' -Force | Out-Null; \
    Expand-Archive -Path $zip -DestinationPath 'C:\steamcmd' -Force; \
    Remove-Item $zip -Force; \
    Write-Host 'steamcmd installed to C:\steamcmd'"
if exist "C:\steamcmd\steamcmd.exe" exit /b 0
echo Failed to acquire steamcmd. Please download manually to C:\steamcmd
exit /b 1

:log_update
set "MSG=%~1"
echo [%date% %time%] %MSG%>>"%RUN_LOG%"
exit /b 0

:run_update
set "SERVER=%~1"
set "SCRIPT=%UPDATE_DIR%\update_%SERVER%.bat"
if exist "!SCRIPT!" (
    echo Running !MODE! for !SERVER! at %date% %time%...
    call :log_update "Starting %MODE% for !SERVER!"
    call "!SCRIPT!"
    call :log_update "Finished %MODE% for !SERVER!"
) else (
    echo Skipping missing script: !SCRIPT!
    call :log_update "Missing script for !SERVER!: !SCRIPT!"
)
exit /b 0
