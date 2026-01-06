@echo off
color 0A
title ARK Cluster Backup

echo backing up cluster now please wait and do not start the cluster, This may take some time i will be right back.

:: Generate timestamp using PowerShell (safe across all modern Windows)
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format \"dd-MM-yyyy\""' ) do set datestamp=%%I

:: Define paths
set source=C:\Ark_SA
set destination=C:\Death-Valley\Ark Master Backup\Backup Of %datestamp%
set logpath=%destination%\Backup_log.txt

echo Starting full cluster backup...
echo Source: %source%
echo Destination: %destination%

:: Create destination folder
mkdir "%destination%"

:: Run robocopy to mirror everything
robocopy "%source%" "%destination%" /MIR /R:3 /W:5 /LOG:"%logpath%"

echo Backup complete at %date% %time%.
timeout /t 10
exit