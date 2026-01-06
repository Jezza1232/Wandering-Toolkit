@echo off
REM Wrapper to run SearchEngine.ps1 with a one-time bypass so users can double-click
setlocal
if exist "%~dp0SearchEngine.ps1" (
    echo Launching SearchEngine...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SearchEngine.ps1" %*
) else (
    echo ERROR: SearchEngine.ps1 not found in this folder.
)
echo.
echo Press any key to close...
pause >nul
endlocal