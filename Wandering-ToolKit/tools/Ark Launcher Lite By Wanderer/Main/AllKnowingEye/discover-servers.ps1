param(
    [string]$RootPath = 'C:\',
    [string[]]$ProcessNames = @('ArkAscendedServer.exe','ShooterGameServer.exe','PalServer.exe','ConanSandboxServer-Win64-Test.exe','SquadGameServer.exe'),
    [string[]]$ExeNameHints = @('server','dedicated','ds','game'),
    [int]$MaxDepth = 6,
    [switch]$PreferWritable
)

<#
    Quick discovery script to locate probable dedicated server folders and seed eye.json entries.
    Heuristics:
      - Look for known process names or executables containing common server hints.
      - Limit recursion depth for speed.
      - Pull basic ports from command lines where available; otherwise leave null.
      - Writes entries via eye-log.ps1 with ProcessName/ExecutablePath/InstallDir guessed.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

$thisDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$eyeLogger = Join-Path $thisDir 'eye-log.ps1'
if (-not (Test-Path $eyeLogger)) {
    Write-Host "eye-log.ps1 not found; aborting." -ForegroundColor Red
    exit 1
}

function Is-ProbablyServerExe {
    param([IO.FileInfo]$File)
    if (-not $File) { return $false }
    $name = $File.Name.ToLowerInvariant()
    if ($ProcessNames -contains $File.Name) { return $true }
    foreach ($hint in $ExeNameHints) {
        if ($name -like "*${hint}*.exe") { return $true }
    }
    return $false
}

function Get-PortFromCmdLine {
    param([string]$Cmd)
    if (-not $Cmd) { return $null }
    $m = [regex]::Match($Cmd, 'Port=(\d{3,6})', 'IgnoreCase')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $null
}

Write-Host "Scanning $RootPath (depth <= $MaxDepth) for server executables..." -ForegroundColor Cyan

# PowerShell 5.x compatibility: emulate -Depth filtering manually
$rootDepth = ($RootPath.TrimEnd('\')).Split('\\').Count
$dirs = Get-ChildItem -Directory -Path $RootPath -Recurse -ErrorAction SilentlyContinue |
    Where-Object { ($_.FullName.Split('\\').Count - $rootDepth) -le $MaxDepth }
$candidates = @()

foreach ($d in $dirs) {
    try {
        $exes = Get-ChildItem -Path $d.FullName -Filter *.exe -File -ErrorAction SilentlyContinue
    } catch { continue }

    foreach ($exe in $exes) {
        if (-not (Is-ProbablyServerExe -File $exe)) { continue }

        if ($PreferWritable -and ($exe.FullName -match '^C:\\Program Files')) { continue }

        $candidates += [pscustomobject]@{
            Name           = $exe.Name
            FullPath       = $exe.FullName
            Directory      = $exe.DirectoryName
            LastWriteTime  = $exe.LastWriteTime
        }
    }
}

$candidates = $candidates | Sort-Object -Property LastWriteTime -Descending | Select-Object -Unique FullPath,Name,Directory,LastWriteTime

if (-not $candidates -or $candidates.Count -eq 0) {
    Write-Host 'No candidate server executables found.' -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($candidates.Count) candidate executables. Seeding eye.json..." -ForegroundColor Green

foreach ($c in $candidates) {
    $serverName = Split-Path $c.Directory -Leaf
    if ($serverName -match '(server|dedicated|ds)$') {
        $serverName = ($serverName -replace '(?i)(server|dedicated|ds)$','').Trim('-_ ')
        if (-not $serverName) { $serverName = Split-Path $c.Directory -Leaf }
    }

    $gamePort = $null
    try {
        $running = Get-CimInstance Win32_Process -Filter ("Name='{0}'" -f $c.Name) -ErrorAction SilentlyContinue
        if ($running) {
            foreach ($p in $running) {
                $gamePort = Get-PortFromCmdLine -Cmd $p.CommandLine
                if ($gamePort) { break }
            }
        }
    } catch {}

    Write-Host "Seeding $serverName => $($c.FullPath)" -ForegroundColor Cyan
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $eyeLogger -ServerName $serverName -InstallDir $c.Directory -ProcessName $c.Name -ExecutablePath $c.FullPath -GamePort $gamePort -Status 'Discovered' | Out-Null
    } catch {
        Write-Warning "Failed to seed $serverName: $($_.Exception.Message)"
    }
}

Write-Host 'Discovery complete. Review eye.json/eye.txt for new entries.' -ForegroundColor Green
