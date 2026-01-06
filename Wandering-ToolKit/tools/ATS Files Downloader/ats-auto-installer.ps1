# Auto-installer for common American Truck Simulator tooling
# Run in an elevated PowerShell. Assumes winget is available.

param(
    [string]$LinksFile = (Join-Path $PSScriptRoot 'download links that work.txt'),
    [string]$OutputDir = (Join-Path $PSScriptRoot 'downloads'),
    [switch]$SkipWinget
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $stamp = (Get-Date).ToString('u')
    Write-Host "[$stamp][$Level] $Message"
}

function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Script must run elevated (Admin).'
    }
}

function Invoke-WingetInstall {
    param([string]$Id)
    if ($SkipWinget) { return 'skipped-winget' }
    $args = @('install', '--id', $Id, '--silent', '--accept-package-agreements', '--accept-source-agreements')
    $p = Start-Process 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -ne 0) { throw "winget install failed (exit $($p.ExitCode))" }
    return 'installed'
}

function Invoke-Download {
    param($Item, [string]$TargetDirectory)

    $uri = [uri]$Item.Url
    $name = [IO.Path]::GetFileName($uri.LocalPath)
    if (-not $name) { $name = ($Item.Name -replace '\s','-') + '.bin' }
    $dest = Join-Path $TargetDirectory $name

    if (-not (Test-Path $dest)) {
        Write-Log "Downloading $($Item.Name) from $uri"
        Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $dest
    } else {
        Write-Log "Using existing file $dest" 'WARN'
    }
    return $dest
}

function Invoke-Install {
    param([string]$Path, [string]$InstallerType, [string]$SilentArgs)

    switch ($InstallerType) {
        'msi' {
            Start-Process 'msiexec.exe' -ArgumentList "/i `"$Path`" /qn /norestart" -Wait -NoNewWindow
            return 'installed'
        }
        'exe' {
            $args = if ($SilentArgs) { $SilentArgs } else { $null }
            Start-Process $Path -ArgumentList $args -Wait -NoNewWindow
            return 'installed'
        }
        'zip' {
            $extractDir = "$Path-extracted"
            if (-not (Test-Path $extractDir)) {
                Expand-Archive -Path $Path -DestinationPath $extractDir -Force
            }
            return "extracted to $extractDir"
        }
        default { return 'downloaded-only' }
    }
}

Ensure-Admin

if (-not (Test-Path $LinksFile)) { throw "Links file missing at $LinksFile" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$manifest = @(
    [pscustomobject]@{ Name='TruckyHub';  Url='https://truckyapp.com/client-download'; InstallerType='exe'; SilentArgs='/S'; AutoInstall=$true; WingetId=$null }
    [pscustomobject]@{ Name='TruckersMP'; Url='https://truckersmp.com/download/zip';   InstallerType='zip'; SilentArgs=$null; AutoInstall=$false; WingetId=$null }
    [pscustomobject]@{ Name='Dbus World'; Url='https://dbusworld.com/uploads/launcher/DBusWorld-Launcher-100.exe'; InstallerType='exe'; SilentArgs='/S'; AutoInstall=$true; WingetId=$null }
    [pscustomobject]@{ Name='TruckyMods'; Url='https://truckyapp.com/modsmanager-download'; InstallerType='exe'; SilentArgs='/S'; AutoInstall=$true; WingetId=$null }
    [pscustomobject]@{ Name='SteamCMD';   Url=$null; InstallerType=$null; SilentArgs=$null; AutoInstall=$true; WingetId='Valve.SteamCMD' }
)

$extraUrls = Select-String -Path $LinksFile -Pattern 'https?://\S+' -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    ForEach-Object { $_.Trim('"').TrimEnd('.','"') } |
    Where-Object { $_ -match '^https?://' } | Select-Object -Unique

foreach ($u in $extraUrls) {
    if ($manifest.Url -contains $u) { continue }
    $ext = ([IO.Path]::GetExtension(([uri]$u).AbsolutePath)).TrimStart('.')
    $type = switch ($ext) { 'msi' {'msi'} 'zip' {'zip'} 'exe' {'exe'} default {'unknown'} }
    $manifest += [pscustomobject]@{ Name=$u; Url=$u; InstallerType=$type; SilentArgs=$null; AutoInstall=$false; WingetId=$null }
}

Write-Log "Output directory: $OutputDir"

foreach ($item in $manifest) {
    Write-Log "Processing $($item.Name)"

    if ($item.WingetId) {
        try {
            $status = Invoke-WingetInstall -Id $item.WingetId
            Write-Log "$($item.Name): $status via winget"
            continue
        } catch {
            Write-Log "$($item.Name): winget failed - $($_.Exception.Message). Falling back to download if URL exists." 'WARN'
            if (-not $item.Url) { continue }
        }
    }

    if (-not $item.Url) { Write-Log "$($item.Name): no URL available" 'WARN'; continue }

    try {
        $path = Invoke-Download -Item $item -TargetDirectory $OutputDir
    } catch {
        Write-Log "$($item.Name): download failed - $($_.Exception.Message)" 'ERROR'
        continue
    }

    if (-not $item.AutoInstall) { Write-Log "$($item.Name): auto-install disabled; left at $path" 'WARN'; continue }

    try {
        $installed = Invoke-Install -Path $path -InstallerType $item.InstallerType -SilentArgs $item.SilentArgs
        Write-Log "$($item.Name): $installed"
    } catch {
        Write-Log "$($item.Name): install failed - $($_.Exception.Message)" 'ERROR'
    }
}

Write-Log 'Done. Check downloads for installers or extracted content.'
