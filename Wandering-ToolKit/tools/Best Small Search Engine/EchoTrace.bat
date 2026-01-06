@echo off
color 0A
setlocal enabledelayedexpansion

:: Prompt for folder path
set /p searchDir="Enter the full path of the folder to search: "

:: Validate folder
if not exist "%searchDir%" (
    echo Folder not found: %searchDir%
    pause
    exit /b
)

:: Prompt for keyword
set /p keyword="Enter the keyword to search for: "

:: Create logs directory
set "logDir=%~dp0SearchLogs"
if not exist "%logDir%" mkdir "%logDir%"

:: Create timestamped log file
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do (
    set "dateStamp=%%d-%%b-%%c"
)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (
    set "timeStamp=%%a-%%b"
)
set "logFile=%logDir%\SearchLog_%dateStamp%_%timeStamp%.txt"

:: Search and log
echo Searching for "%keyword%" in .txt files under "%searchDir%"...
echo Searching for "%keyword%" in .txt files under "%searchDir%"... > "%logFile%"
echo. >> "%logFile%"

for /r "%searchDir%" %%f in (*.txt) (*.ini) do (
    findstr /i /n /c:"%keyword%" "%%f" > nul
    if !errorlevel! equ 0 (
        echo ----- %%~nxf -----
        echo ----- %%~nxf ----- >> "%logFile%"
        findstr /i /n /c:"%keyword%" "%%f"
        findstr /i /n /c:"%keyword%" "%%f" >> "%logFile%"
        echo.
        echo. >> "%logFile%"
    )
)

echo Search complete. Results saved to:
echo %logFile%
pause