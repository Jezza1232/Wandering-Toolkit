[CmdletBinding()]
param(
    [switch]$InstallSteam,
    [switch]$InstallSteamCmd,
    [switch]$DownloadServer,
    [string]$DownloadRoot = "$env:TEMP\\ets2-downloads"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Assert-Admin {
    $current = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "Run PowerShell as Administrator so installs do not fail."
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-DownloadTarget {
    param(
        [string]$Name,
        [string]$Url,
        [string]$DownloadPath
    )

    $uri = [uri]$Url
    $leaf = $uri.Segments[-1].TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        $leaf = $uri.Host
    }

    if (-not $leaf.Contains('.')) {
        $leaf = "$leaf.exe"
    }

    return (Join-Path $DownloadPath $leaf)
}

function Invoke-Download {
    param(
        [string]$Name,
        [string]$PrimaryUrl,
        [string]$FallbackUrl,
        [string]$DownloadPath
    )

    Ensure-Directory -Path $DownloadPath
    $target = Get-DownloadTarget -Name $Name -Url $PrimaryUrl -DownloadPath $DownloadPath

    Write-Host "Downloading $Name..." -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $PrimaryUrl -OutFile $target -UseBasicParsing -MaximumRedirection 5
        return $target
    }
    catch {
        if ($FallbackUrl) {
            Write-Warning "$Name primary URL failed, trying fallback."
            Invoke-WebRequest -Uri $FallbackUrl -OutFile $target -UseBasicParsing -MaximumRedirection 5
            return $target
        }
        throw
    }
}

function Install-FromArchive {
    param(
        [string]$ArchivePath,
        [string]$SilentArgs
    )

    $tempFolder = Join-Path ([IO.Path]::GetDirectoryName($ArchivePath)) ([IO.Path]::GetFileNameWithoutExtension($ArchivePath))
    Ensure-Directory -Path $tempFolder
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $tempFolder -Force
    $exe = Get-ChildItem -LiteralPath $tempFolder -Recurse -Filter '*.exe' | Sort-Object Length -Descending | Select-Object -First 1
    if (-not $exe) {
        throw "No installer found inside archive $ArchivePath"
    }
    Write-Host "Launching installer inside archive: $($exe.FullName)" -ForegroundColor Yellow
    $args = @()
    if ($SilentArgs) { $args = $SilentArgs }
    Start-Process -FilePath $exe.FullName -ArgumentList $args -Wait
}

function Install-Executable {
    param(
        [string]$Path,
        [string]$SilentArgs
    )

    $ext = [IO.Path]::GetExtension($Path)
    switch ($ext.ToLowerInvariant()) {
        '.zip' {
            Install-FromArchive -ArchivePath $Path -SilentArgs $SilentArgs
        }
        default {
            $args = @()
            if ($SilentArgs) { $args = $SilentArgs }
            Write-Host "Launching installer: $Path" -ForegroundColor Yellow
            Start-Process -FilePath $Path -ArgumentList $args -Wait
        }
    }
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )

    $cmd = Get-Command winget -ErrorAction Stop
    $arguments = @("install", "--exact", "--id", $Id, "--accept-package-agreements", "--accept-source-agreements", "--silent")
    Write-Host "Installing $Name via winget..." -ForegroundColor Cyan
    Start-Process -FilePath $cmd.Path -ArgumentList $arguments -Wait -NoNewWindow
}

function Get-SteamCmdPath {
    $cmd = Get-Command steamcmd.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }

    $defaults = @(
        "C:\\Program Files (x86)\\Steam\\steamcmd.exe",
        "C:\\Program Files (x86)\\SteamCMD\\steamcmd.exe",
        "C:\\SteamCMD\\steamcmd.exe"
    )

    foreach ($path in $defaults) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Update-Ets2DedicatedServer {
    param(
        [string]$InstallRoot
    )

    $steamCmd = Get-SteamCmdPath
    if (-not $steamCmd) {
        throw "steamcmd.exe not found. Install SteamCMD or add it to PATH."
    }

    Ensure-Directory -Path $InstallRoot
    $args = "+force_install_dir `"$InstallRoot`" +login anonymous +app_update 1948160 validate +quit"
    Write-Host "Downloading/validating ETS2 dedicated server to $InstallRoot" -ForegroundColor Cyan
    Start-Process -FilePath $steamCmd -ArgumentList $args -Wait -NoNewWindow
}

Assert-Admin

Write-Host "Euro Truck Simulator 2 downloader starting..." -ForegroundColor Cyan

$packages = @(
    @{ Name = "TruckyHub"; PrimaryUrl = "https://truckyapp.com/client-download"; FallbackUrl = $null; SilentArgs = "/S" },
    @{ Name = "TruckersMP"; PrimaryUrl = "https://truckersmp.com/download/zip"; FallbackUrl = $null; SilentArgs = "/SILENT" },
    @{ Name = "Dbus World"; PrimaryUrl = "https://dbusworld.com/uploads/launcher/DBusWorld-Launcher-100.exe"; FallbackUrl = "https://dbusworld.com/client/thanks"; SilentArgs = "/S" },
    @{ Name = "TruckyMods Manager"; PrimaryUrl = "https://truckyapp.com/modsmanager-download"; FallbackUrl = $null; SilentArgs = "/S" }
)

foreach ($pkg in $packages) {
    try {
        $downloaded = Invoke-Download -Name $pkg.Name -PrimaryUrl $pkg.PrimaryUrl -FallbackUrl $pkg.FallbackUrl -DownloadPath $DownloadRoot
        Install-Executable -Path $downloaded -SilentArgs $pkg.SilentArgs
        Write-Host "$($pkg.Name) done." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to process $($pkg.Name): $_"
    }
}

if ($InstallSteam) {
    Install-WingetPackage -Id "Valve.Steam" -Name "Steam"
}

if ($InstallSteamCmd) {
    Install-WingetPackage -Id "Valve.SteamCMD" -Name "SteamCMD"
}

if ($DownloadServer) {
    $serverRoot = Join-Path $DownloadRoot "ets2-dedicated-server"
    Update-Ets2DedicatedServer -InstallRoot $serverRoot
}

Write-Host "All tasks finished." -ForegroundColor Green
