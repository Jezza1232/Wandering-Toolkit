@echo off
color 0A
title ASA Multi-Server Launcher (Single Window)
setlocal EnableExtensions EnableDelayedExpansion

:: Common flags appended to every server launch (customize if desired)
set "COMMON_FLAGS="

:: Base ports (increment by index)
set "BASE_GAME_PORT=7777"
set "BASE_QUERY_PORT=27015"
set "BASE_RCON_PORT=32390"

:: Map registry (NAME / TOKEN / MOD list)
set "MAP_COUNT=31"
set "MAP1_NAME=The Island"         & set "MAP1_TOKEN=TheIsland_WP"            & set "MAP1_MOD="
set "MAP2_NAME=Scorched Earth"     & set "MAP2_TOKEN=ScorchedEarth_WP"        & set "MAP2_MOD="
set "MAP3_NAME=The Center"         & set "MAP3_TOKEN=TheCenter_WP"            & set "MAP3_MOD="
set "MAP4_NAME=Aberration"         & set "MAP4_TOKEN=Aberration_WP"           & set "MAP4_MOD="
set "MAP5_NAME=Extinction"         & set "MAP5_TOKEN=Extinction_WP"           & set "MAP5_MOD="
set "MAP6_NAME=Ragnarok"           & set "MAP6_TOKEN=Ragnarok_WP"             & set "MAP6_MOD="
set "MAP7_NAME=Valguero"           & set "MAP7_TOKEN=Valguero_WP"             & set "MAP7_MOD="
set "MAP8_NAME=Crystal Isles"      & set "MAP8_TOKEN=CrystalIsles_WP"         & set "MAP8_MOD="
set "MAP9_NAME=Genesis: Part 1"    & set "MAP9_TOKEN=Genesis_WP"              & set "MAP9_MOD="
set "MAP10_NAME=Genesis: Part 2"   & set "MAP10_TOKEN=Genesis2_WP"            & set "MAP10_MOD="
set "MAP11_NAME=Lost Island"       & set "MAP11_TOKEN=LostIsland_WP"          & set "MAP11_MOD="
set "MAP12_NAME=ClubArk"           & set "MAP12_TOKEN=BobsMissions_WP"        & set "MAP12_MOD=1005639"
set "MAP13_NAME=Fjordur"           & set "MAP13_TOKEN=Fjordur_WP"             & set "MAP13_MOD="
set "MAP14_NAME=Lost Colony"       & set "MAP14_TOKEN=LostColony_WP"          & set "MAP14_MOD="
set "MAP15_NAME=LostCity"          & set "MAP15_TOKEN=LostCity_WP"            & set "MAP15_MOD=1187557"
set "MAP16_NAME=Astraeos"          & set "MAP16_TOKEN=Astraeos_WP"            & set "MAP16_MOD=988598"
set "MAP17_NAME=Amissa"            & set "MAP17_TOKEN=Amissa_WP"              & set "MAP17_MOD=965379"
set "MAP18_NAME=Appalachia"        & set "MAP18_TOKEN=Appalachia_WP"          & set "MAP18_MOD=935306"
set "MAP19_NAME=Arkopolis"         & set "MAP19_TOKEN=Arkopolis_WP"           & set "MAP19_MOD=954190"
set "MAP20_NAME=Atlantis"          & set "MAP20_TOKEN=Atlantis_WP"            & set "MAP20_MOD=1081192"
set "MAP21_NAME=Nyrandil Free"     & set "MAP21_TOKEN=Nyrandil_WP"            & set "MAP21_MOD=965599"
set "MAP22_NAME=Nyrandil Premium"  & set "MAP22_TOKEN=Nyrandil_Premium_WP"    & set "MAP22_MOD=1027407"
set "MAP23_NAME=Forglar Premium"   & set "MAP23_TOKEN=Forglar_Premium_WP"     & set "MAP23_MOD=1009169"
set "MAP24_NAME=Ice Age"           & set "MAP24_TOKEN=Frost_WP"               & set "MAP24_MOD=943275"
set "MAP25_NAME=Insaluna"          & set "MAP25_TOKEN=Insaluna_WP"            & set "MAP25_MOD=939532"
set "MAP26_NAME=Emerald Isles"     & set "MAP26_TOKEN=EmeraldIsles_WP"        & set "MAP26_MOD=1127117"
set "MAP27_NAME=Svartalfheim Premium" & set "MAP27_TOKEN=Svartalfheim_WP"     & set "MAP27_MOD=962796"
set "MAP28_NAME=Temptress Lagoon"  & set "MAP28_TOKEN=TemptressLagoon_WP"     & set "MAP28_MOD=1017342"
set "MAP29_NAME=ALTHEMIA Premium"  & set "MAP29_TOKEN=ALTHEMIA"               & set "MAP29_MOD=1077433"
set "MAP30_NAME=The Volcano"       & set "MAP30_TOKEN=TheVolcano_WP"          & set "MAP30_MOD=1158003"
set "MAP31_NAME=LOST PROTOCOL"     & set "MAP31_TOKEN=PROTOCOL_WP"            & set "MAP31_MOD=1240685"

:: Resolve repo root and log dir
pushd "%~dp0.." || goto :eof
set "ROOT=%CD%"
set "LOG_DIR=%ROOT%\Main\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "START_LOG=%LOG_DIR%\starts.log"
set "STEAMCMD="

call :ensure_steamcmd
if errorlevel 1 (
    echo steamcmd missing; aborting launch.
    goto :eof
)

echo ROOT resolved to: %ROOT%
echo ------------------------------------------------------------
echo Listing maps and default ports (incremented by index):
echo -----------------------------------------------
for /L %%I in (1,1,%MAP_COUNT%) do call :show_map %%I
echo -----------------------------------------------

set /p DEBUG_INLINE=Debug inline (show live output here) [Y/N, default N]: 
if /I "%DEBUG_INLINE%"=="Y" set "RUN_INLINE=1"
if /I "%DEBUG_INLINE%"=="YES" set "RUN_INLINE=1"

set /p TARGETS=Enter map numbers (space-separated) or ALL: 
if /I "%TARGETS%"=="ALL" (
    set "TARGETS="
    for /L %%I in (1,1,%MAP_COUNT%) do call set "TARGETS=%%TARGETS%% %%I"
)
if "%TARGETS%"=="" set "TARGETS=1"
call :log "Selected: %TARGETS%"

for %%N in (%TARGETS%) do call :launch_map %%N

echo All selected servers dispatched. Done!
popd
endlocal
goto :eof

:ensure_steamcmd
rem Prefer existing SteamCMD; set path as we find it
if exist "C:\steamcmd\steamcmd.exe" (
    set "STEAMCMD=C:\steamcmd\steamcmd.exe"
    exit /b 0
)
if exist "%ROOT%\Main\SteamCMD\steamcmd.exe" (
    set "STEAMCMD=%ROOT%\Main\SteamCMD\steamcmd.exe"
    exit /b 0
)
if exist "%ROOT%\SteamCMD\steamcmd.exe" (
    set "STEAMCMD=%ROOT%\SteamCMD\steamcmd.exe"
    exit /b 0
)

echo steamcmd not found. Downloading to C:\steamcmd ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $zip = Join-Path $env:TEMP 'steamcmd.zip'; Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip -UseBasicParsing; New-Item -ItemType Directory -Path 'C:\steamcmd' -Force | Out-Null; Expand-Archive -Path $zip -DestinationPath 'C:\steamcmd' -Force; Remove-Item $zip -Force; Write-Host 'steamcmd installed to C:\steamcmd' } catch { Write-Host 'steamcmd download failed:' $_.Exception.Message; exit 1 }" || (
    call :log "steamcmd download failed"
    exit /b 1
)

if exist "C:\steamcmd\steamcmd.exe" set "STEAMCMD=C:\steamcmd\steamcmd.exe"
if not defined STEAMCMD if exist "%ROOT%\Main\SteamCMD\steamcmd.exe" set "STEAMCMD=%ROOT%\Main\SteamCMD\steamcmd.exe"
if not defined STEAMCMD if exist "%ROOT%\SteamCMD\steamcmd.exe" set "STEAMCMD=%ROOT%\SteamCMD\steamcmd.exe"
if not defined STEAMCMD (
    call :log "steamcmd still missing after download"
    exit /b 1
)
exit /b 0

:show_map
set "IDX=%~1"
call set "NAME=%%MAP%IDX%_NAME%%"
call set "TOKEN=%%MAP%IDX%_TOKEN%%"
call set "MOD=%%MAP%IDX%_MOD%%"
set "MOD_CLEAN="
if not "!MOD!"=="" (
    set "MOD_CLEAN=!MOD:,=;!"
    set "MOD_CLEAN=!MOD_CLEAN: =!"
)
if "!MOD_CLEAN!"=="" (set "MOD_DISPLAY=(none)") else (set "MOD_DISPLAY=!MOD_CLEAN!")
set /a GP=%BASE_GAME_PORT%+%IDX%-1
set /a QP=%BASE_QUERY_PORT%+%IDX%-1
set /a RP=%BASE_RCON_PORT%+%IDX%-1
echo [!IDX!] !NAME!  (token=!TOKEN!, mods=!MOD_DISPLAY!, ports GP=!GP! QP=!QP! RCON=!RP!)
goto :eof

:launch_map
set "IDX=%~1"
call set "NAME=%%MAP%IDX%_NAME%%"
call set "TOKEN=%%MAP%IDX%_TOKEN%%"
call set "MOD=%%MAP%IDX%_MOD%%"
set "MOD_CLEAN="
if not "!MOD!"=="" (
    set "MOD_CLEAN=!MOD:,=;!"
    set "MOD_CLEAN=!MOD_CLEAN: =!"
)
if "!NAME!"=="" (
    echo Skipping unknown map index %IDX%
    call :log "Skip unknown index %IDX%"
    goto :eof
)
set /a GP=%BASE_GAME_PORT%+%IDX%-1
set /a QP=%BASE_QUERY_PORT%+%IDX%-1
set /a RP=%BASE_RCON_PORT%+%IDX%-1
set "INSTALL_TOKEN=!TOKEN!"
set "INSTALL_ALT=!TOKEN:_WP=!"
if exist "C:\Ark_SA\!INSTALL_ALT!\ShooterGame\Binaries\Win64\ArkAscendedServer.exe" (
    set "INSTALL=C:\Ark_SA\!INSTALL_ALT!"
) else (
    set "INSTALL=C:\Ark_SA\!INSTALL_TOKEN!"
)
set "LOG_OUT=%LOG_DIR%\server-!TOKEN!.log"
set "SERVER_CMD=!TOKEN!?Port=!GP!?QueryPort=!QP!?RCONEnabled=True?RCONPort=!RP! -server -log -servergamelog !COMMON_FLAGS!"
if not "!MOD_CLEAN!"=="" set "SERVER_CMD=!SERVER_CMD! -Mods=!MOD_CLEAN!"

echo [!date! !time!] !NAME! start requested (token=!TOKEN!, mods=!MOD_CLEAN!, GP=!GP!, QP=!QP!, RCON=!RP!, COMMON=!COMMON_FLAGS!, steamcmd=!STEAMCMD!)>"!LOG_OUT!"
call :log "Launching !NAME! (token=!TOKEN!, mods=!MOD_CLEAN!, GP=!GP!, QP=!QP!, RCON=!RP!, Install=!INSTALL!)"
echo ------------------------------------------------------------
echo !NAME! :: Updating via SteamCMD and starting server
echo Install dir: !INSTALL!
echo Ports      : GP=!GP! QP=!QP! RCON=!RP!
echo ------------------------------------------------------------
echo Log output : !LOG_OUT!

echo Updating server files via SteamCMD...
"!STEAMCMD!" +force_install_dir "!INSTALL!" +login anonymous +app_update 2430930 validate +quit
set "SC_CODE=!ERRORLEVEL!"
echo SteamCMD exited with code !SC_CODE!
echo [!date! !time!] steamcmd exit !SC_CODE!>>"!LOG_OUT!"
call :log "steamcmd exit !SC_CODE! for !NAME!"

if not exist "!INSTALL!\ShooterGame\Binaries\Win64\ArkAscendedServer.exe" (
    echo ArkAscendedServer.exe not found under !INSTALL!\ShooterGame\Binaries\Win64
    echo [!date! !time!] missing ArkAscendedServer.exe>>"!LOG_OUT!"
    call :log "ArkAscendedServer.exe missing for !NAME!"
    goto :eof
)

pushd "!INSTALL!\ShooterGame\Binaries\Win64" || goto :eof
echo Launching !NAME! ...
if defined RUN_INLINE (
    echo [!date! !time!] !NAME! starting (inline)>>"!LOG_OUT!"
    call ArkAscendedServer.exe !SERVER_CMD! >>"!LOG_OUT!" 2>&1
    set "EXIT_CODE=!ERRORLEVEL!"
    echo [!date! !time!] !NAME! exited with code !EXIT_CODE!>>"!LOG_OUT!"
    call :log "!NAME! exit code !EXIT_CODE!"
) else (
    start "" /b cmd /c "echo [!date! !time!] !NAME! starting >""!LOG_OUT!"" & ArkAscendedServer.exe !SERVER_CMD! >>""!LOG_OUT!"" 2>&1"
)
popd
goto :eof

:log
set "MSG=%~1"
if not "!START_LOG!"=="" echo [%date% %time%] !MSG!>>"!START_LOG!"
goto :eof
