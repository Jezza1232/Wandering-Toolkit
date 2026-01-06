@echo off
color 0A
title ARK Server Control Menu
setlocal
set "ROOT=%~dp0"
set "FALLBACK=C:\Ark-Launcher-Lite-By-Wanderer"
set "STEAMCMD_DIR=%ROOT%..\..\data\main\steamcmd"

call :EnsurePrereqs

:menu
cls
echo ===============================
echo     ARK SERVER CONTROL
echo ===============================
echo [1] Update Servers
echo [2] Start Servers
echo [3] Install Servers
echo [4] Backup Cluster
echo [5] Search
echo [6] Watchdog
echo [7] Download SteamCMD
echo [Q] Quit
echo -------------------------------
set /p choice=Enter your choice: 

if "%choice%"=="1" goto Update
if "%choice%"=="2" goto StartMenu
if "%choice%"=="3" goto Install
if "%choice%"=="4" goto Backup
if "%choice%"=="5" goto SearchMenu
if "%choice%"=="6" goto Watchdog
if "%choice%"=="7" goto SteamCMD
if /I "%choice%"=="Q" exit
goto menu

:Update
echo Running updater...
set "BASE=%ROOT%update files"
if not exist "%BASE%\Update-Ark-Servers.bat" set "BASE=%FALLBACK%\update files"
if not exist "%BASE%\Update-Ark-Servers.bat" (
	echo Missing file: %ROOT%update files\Update-Ark-Servers.bat
	echo Also tried: %FALLBACK%\update files\Update-Ark-Servers.bat
	echo ROOT resolved to: %ROOT%
	echo Listing %ROOT%Main\ for visibility...
	dir /b "%ROOT%Main" 2>nul
	pause
	goto menu
)
echo ROOT resolved to: %ROOT%
echo Using base: %BASE%
pushd "%BASE%"
if not exist "Update-Ark-Servers.bat" (
	echo Unexpected: Update-Ark-Servers.bat missing after pushd to %BASE%
	popd
	pause
	goto menu
)
echo Calling: %CD%\Update-Ark-Servers.bat
call "Update-Ark-Servers.bat"
popd
echo Update complete.
pause
goto menu

:Install
echo Running install flow (uses updater scripts)...
set "BASE=%ROOT%update files"
if not exist "%BASE%\Update-Ark-Servers.bat" set "BASE=%FALLBACK%\update files"
if not exist "%BASE%\Update-Ark-Servers.bat" (
	echo Missing file: %ROOT%update files\Update-Ark-Servers.bat
	echo Also tried: %FALLBACK%\update files\Update-Ark-Servers.bat
	pause
	goto menu
)
pushd "%BASE%"
set "INSTALL_MODE=1"
echo Calling: %CD%\Update-Ark-Servers.bat (install mode)
call "Update-Ark-Servers.bat"
popd
echo Install flow complete.
pause
goto menu

:StartMenu
cls
echo -------------------------------
echo       START SERVER OPTIONS
echo -------------------------------
echo [1] Main Ark Network
echo [B] Back
echo -------------------------------
set /p startchoice=Choose server batch to launch: 

if "%startchoice%"=="1" goto StartMain
if /I "%startchoice%"=="B" goto menu
goto StartMenu

:StartMain
echo Launching Main Cluster Servers...
set "START_BASE=%ROOT%start files"
if not exist "%START_BASE%\start_servers.bat" set "START_BASE=%FALLBACK%\start files"
if not exist "%START_BASE%\start_servers.bat" (
	echo Missing file: %ROOT%start files\start_servers.bat
	echo Also tried: %FALLBACK%\start files\start_servers.bat
	pause
	goto menu
)
call "%START_BASE%\start_servers.bat"
echo Start sequence complete. Launching The All Seeing Eye in this window...
goto LaunchWatchdog

:LaunchWatchdog
echo Starting The All Seeing Eye watchdog in this window...
set "EYE_DIR=%ROOT%Main\AllKnowingEye"
if not exist "%EYE_DIR%\watchdog.ps1" set "EYE_DIR=%FALLBACK%\Main\AllKnowingEye"
if not exist "%EYE_DIR%\watchdog.ps1" (
	echo Missing file: %ROOT%Main\AllKnowingEye\watchdog.ps1
	echo Also tried: %FALLBACK%\Main\AllKnowingEye\watchdog.ps1
	pause
	goto menu
)
set "PS_CMD=powershell"
where /q pwsh.exe
if %errorlevel%==0 set "PS_CMD=pwsh.exe"
echo Using: %PS_CMD%
echo Script: %EYE_DIR%\watchdog.ps1
echo Running... press Ctrl+C to stop or create a STOP file in the same folder.
"%PS_CMD%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%EYE_DIR%\watchdog.ps1" -AutoRestart -PollSeconds 60
echo Watchdog exited with code %errorlevel%.
pause
goto menu
:Backup
echo Starting cluster backup...
if not exist "%ROOT%Main\ClusterBackup.bat" (
	echo Missing file: %ROOT%Main\ClusterBackup.bat
	pause
	goto menu
)
call "%ROOT%Main\ClusterBackup.bat"
echo Backup complete.
pause
goto menu

:SearchEngine
echo Starting Search Engine...
if not exist "%ROOT%Main\RunSearch.cmd" (
	echo Missing file: %ROOT%Main\RunSearch.cmd
	pause
	goto menu
)
call "%ROOT%Main\RunSearch.cmd"
echo Search complete.
pause
goto menu

:SearchMenu
cls
echo -------------------------------
echo          SEARCH OPTIONS
echo -------------------------------
echo [1] Primary Search
echo [2] Backup Search
echo [B] Back
echo -------------------------------
set /p searchchoice=Choose search mode: 

if "%searchchoice%"=="1" goto SearchEngine
if "%searchchoice%"=="2" goto BackupSearchEngine
if /I "%searchchoice%"=="B" goto menu
goto SearchMenu

:BackupSearchEngine
echo Starting Backup Search Engine...
if not exist "%ROOT%Main\EchoTrace.bat" (
	echo Missing file: %ROOT%Main\EchoTrace.bat
	pause
	goto menu
)
call "%ROOT%Main\EchoTrace.bat"
echo Search complete.
pause
goto menu

:Watchdog
goto LaunchWatchdog

:SteamCMD
echo Checking/downloading SteamCMD...
call :EnsureSteamCMD
if exist "%STEAMCMD_DIR%\steamcmd.exe" (
	echo SteamCMD present at %STEAMCMD_DIR%\steamcmd.exe
) else (
	echo SteamCMD still missing. Please place steamcmd.exe under %STEAMCMD_DIR%.
)
pause
goto menu

:EnsurePrereqs
call :EnsureWinget
call :EnsureSteamCMD
call :EnsurePwsh7
exit /b 0

:EnsureSteamCMD
if exist "%STEAMCMD_DIR%\steamcmd.exe" exit /b 0
echo steamcmd not found. Downloading to %STEAMCMD_DIR% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $zip = Join-Path $env:TEMP 'steamcmd.zip'; Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip -UseBasicParsing; New-Item -ItemType Directory -Path '%STEAMCMD_DIR%' -Force | Out-Null; Expand-Archive -Path $zip -DestinationPath '%STEAMCMD_DIR%' -Force; Remove-Item $zip -Force; Write-Host 'steamcmd installed to %STEAMCMD_DIR%' } catch { Write-Host 'steamcmd download failed:' $_.Exception.Message; exit 1 }" || (
	echo SteamCMD auto-download failed. Please place steamcmd.exe under %STEAMCMD_DIR% manually.
)
if exist "%STEAMCMD_DIR%\steamcmd.exe" exit /b 0
echo Failed to acquire steamcmd. Please download manually to %STEAMCMD_DIR%
exit /b 0

:EnsurePwsh7
where /q pwsh.exe && exit /b 0
echo PowerShell 7 not found. Attempting winget install...
winget install --id Microsoft.PowerShell --exact --source winget --silent --accept-package-agreements --accept-source-agreements
where /q pwsh.exe && exit /b 0
echo winget install failed or pwsh still missing. Attempting direct download...
powershell -NoProfile -ExecutionPolicy Bypass -Command "\
	try {\
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;\
		$msi = Join-Path $env:TEMP 'PowerShell-7-x64.msi';\
		Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.1-win-x64.msi' -OutFile $msi -UseBasicParsing;\
		Start-Process msiexec.exe -ArgumentList '/i', $msi, '/quiet', '/norestart' -Wait;\
		Remove-Item $msi -Force;\
		Write-Host 'PowerShell 7 installer executed.';\
	} catch {\
		Write-Host 'PowerShell 7 download/install failed:' $_.Exception.Message; exit 1;\
	}" || (
	echo PowerShell 7 auto-install failed. Please install manually from https://aka.ms/powershell.
)
where /q pwsh.exe && exit /b 0
echo PowerShell 7 install may require admin. Please install manually if still missing.
exit /b 0

:EnsureWinget
where /q winget.exe && exit /b 0
echo WinGet not found. Attempting install via PowerShell (NuGet + Microsoft.WinGet.Client)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "\
	try {\
		$ProgressPreference = 'SilentlyContinue';\
		Install-PackageProvider -Name NuGet -Force | Out-Null;\
		Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null;\
		Repair-WinGetPackageManager -AllUsers;\
		Write-Host 'WinGet install attempted.';\
	} catch {\
		Write-Host 'WinGet install failed:' $_.Exception.Message; exit 1;\
	}" || (
	echo WinGet install failed. Please install manually from https://aka.ms/getwinget.
)
where /q winget.exe && exit /b 0
echo WinGet still missing. Please install manually from https://aka.ms/getwinget
exit /b 0