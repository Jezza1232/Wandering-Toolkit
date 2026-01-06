[CmdletBinding()]
param(
    [switch]$NoBootstrap
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir     = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent $DataDir
$ToolsRoot   = Join-Path $ProjectRoot 'tools'
$DataRoot    = Join-Path $ProjectRoot 'data'
$LogsRoot    = Join-Path $ProjectRoot 'Logs'
$SteamCmdDir = Join-Path $DataRoot 'main/steamcmd'
$SteamCmdExe = Join-Path $SteamCmdDir 'steamcmd.exe'
$script:LogFile = $null
$script:TranscriptFile = $null
$script:TranscriptRunning = $false

function Init-Logging {
    if (-not (Test-Path $LogsRoot)) {
        New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null
    }
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFile = Join-Path $LogsRoot "run-$timestamp.log"
    $script:TranscriptFile = Join-Path $LogsRoot "run-$timestamp.transcript.log"
    Add-Content -Path $LogFile -Value "=== Wandering Toolkit run $(Get-Date -Format 's') ==="
    try {
        Start-Transcript -Path $TranscriptFile -Append -ErrorAction Stop | Out-Null
        $script:TranscriptRunning = $true
    }
    catch {
        Write-Warning "Transcript not started: $($_.Exception.Message)"
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 's'), $Level.ToUpper(), $Message
    if ($Level -eq 'ERROR') {
        Write-Host $line -ForegroundColor Red
    }
    elseif ($Level -eq 'WARN') {
        Write-Host $line -ForegroundColor Yellow
    }
    else {
        Write-Host $line -ForegroundColor Cyan
    }
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $line
    }
}

function Ensure-Directories {
    $paths = @(
        $ToolsRoot
        $DataRoot
        (Join-Path $DataRoot 'main')
        (Join-Path $DataRoot 'main/steamcmd')
        (Join-Path $DataRoot 'server')
        (Join-Path $DataRoot 'downloads')
        (Join-Path $DataRoot 'Dev-notes')
        (Join-Path $DataRoot 'rcon')
        (Join-Path $DataRoot 'steamcmd-information/steamcmd')
        (Join-Path $DataRoot 'steamcmd-information/helpful-info')
        $LogsRoot
    )

    foreach ($p in $paths) {
        if (-not (Test-Path $p)) {
            Write-Log "Creating $p" 'INFO'
            New-Item -ItemType Directory -Path $p -Force | Out-Null
        }
    }
}

function Ensure-WinGet {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) { return $true }

    Write-Log 'Installing WinGet (App Installer)' 'INFO'
    $bundlePath = Join-Path $env:TEMP 'winget-latest.msixbundle'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/getwinget' -OutFile $bundlePath
        Add-AppxPackage -Path $bundlePath -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Log "WinGet install failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }

    return (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
}

function Relaunch-WithPwsh {
    if ($env:WANDERING_TOOLKIT_RELAUNCHED -eq '1') { return }

    $pwshPath = Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'
    if (-not (Test-Path $pwshPath)) { return }

    $env:WANDERING_TOOLKIT_RELAUNCHED = '1'
    $args = @('-NoLogo', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
    if ($NoBootstrap) { $args += '-NoBootstrap' }

    & $pwshPath @args
    exit $LASTEXITCODE
}

function Ensure-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -ge 7) { return $true }

    Write-Log 'Installing PowerShell 7 via WinGet' 'INFO'
    if (-not (Ensure-WinGet)) {
        Write-Log 'WinGet is required to install PowerShell 7 automatically.' 'WARN'
        return $false
    }

    try {
        & winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity | Out-Null
    }
    catch {
        Write-Log "PowerShell 7 install failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }

    Relaunch-WithPwsh
    return (Get-Command pwsh -ErrorAction SilentlyContinue) -ne $null
}

function Ensure-SteamCmd {
    if (Test-Path $SteamCmdExe) { return $true }

    Write-Log "Installing SteamCMD to $SteamCmdDir" 'INFO'
    if (-not (Test-Path $SteamCmdDir)) {
        New-Item -ItemType Directory -Path $SteamCmdDir -Force | Out-Null
    }

    $zipPath = Join-Path $env:TEMP 'steamcmd.zip'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $SteamCmdDir -Force
    }
    catch {
        Write-Log "SteamCMD install failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }

    return (Test-Path $SteamCmdExe)
}

function Import-Tools {
    $toolDefs = @()
    if (-not (Test-Path $ToolsRoot)) { return @() }

    $toolDirs = Get-ChildItem -Path $ToolsRoot -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $toolDirs) {
        $toolFile = Join-Path $dir.FullName 'tool.ps1'
        $loaded = $false

        if (Test-Path $toolFile) {
            try {
                $def = . $toolFile
                if ($def) {
                    $toolDefs += [PSCustomObject]@{
                        Name          = $def.Name
                        Description   = $def.Description
                        Version       = $def.Version
                        RequiresAdmin = $def.RequiresAdmin
                        Path          = $dir.FullName
                        Invoke        = $def.Invoke
                        Test          = $def.Test
                        Init          = $def.Init
                    }
                    Write-Log "Loaded tool from $toolFile" 'INFO'
                    $loaded = $true
                }
            }
            catch {
                Write-Log "Failed to load tool from ${toolFile}: $($_.Exception.Message)" 'WARN'
            }
        }

        if ($loaded) { continue }

        $candidateNames = @('menu.bat','start.ps1','start.bat','launch.ps1','launch.bat','run.ps1','run.bat')
        $entryPath = $null
        foreach ($name in $candidateNames) {
            $probe = Join-Path $dir.FullName $name
            if (Test-Path $probe) { $entryPath = $probe; break }
        }
        if (-not $entryPath) { continue }

        $entry = $entryPath
        $toolFolder = $dir.FullName
        $toolDefs += [PSCustomObject]@{
            Name          = $dir.Name
            Description   = "Auto-discovered launcher in $($dir.Name)"
            Version       = 'auto'
            RequiresAdmin = $false
            Path          = $toolFolder
            Invoke        = {
                param($Context)
                Push-Location $toolFolder
                try {
                    if ($entry -like '*.ps1') {
                        $shell = (Get-Command pwsh -ErrorAction SilentlyContinue) ? 'pwsh' : 'powershell'
                        & $shell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry
                    }
                    else {
                        & cmd.exe /c "\"$entry\""
                    }
                }
                finally {
                    Pop-Location
                }
            }
            Test = $null
            Init = $null
        }
        Write-Log "Auto-discovered tool '${dir.Name}' using $entryPath" 'INFO'
    }

    return $toolDefs | Sort-Object Name
}

function Invoke-ToolSafely {
    param(
        $Tool,
        $Context
    )

    Write-Log "Launching tool: $($Tool.Name)" 'INFO'
    if ($Tool.RequiresAdmin -and (-not ([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))) {
        Write-Log "Tool '$($Tool.Name)' requires Administrator. Restart PowerShell as admin." 'WARN'
        return
    }

    try {
        if ($Tool.Test) {
            $ready = & $Tool.Test $Context
            if (-not $ready) {
                Write-Log "Tool '$($Tool.Name)' reported it is not ready." 'WARN'
                return
            }
        }

        if ($Tool.Init) {
            & $Tool.Init $Context
        }

        & $Tool.Invoke $Context
        Write-Log "Tool completed: $($Tool.Name)" 'INFO'
    }
    catch {
        Write-Log "Tool '$($Tool.Name)' failed: $($_.Exception.Message)" 'ERROR'
    }
}

function Show-ToolsMenu {
    param(
        [array]$Tools,
        $Context
    )

    while ($true) {
        Clear-Host
        Write-Host 'Tools' -ForegroundColor Green
        Write-Host '-----'

        for ($i = 0; $i -lt $Tools.Count; $i++) {
            $tool = $Tools[$i]
            $idx = $i + 1
            $label = $tool.Name
            if ($tool.Version) { $label += " (v$($tool.Version))" }
            Write-Host ("[{0}] {1} - {2}" -f $idx, $label, $tool.Description)
        }

        Write-Host '[B] Back'
        $choice = Read-Host 'Enter choice'

        if ([string]::IsNullOrWhiteSpace($choice)) { continue }
        if ($choice -match '^[Bb]') { break }

        if (-not ($choice -as [int])) { continue }
        $index = [int]$choice - 1
        if ($index -lt 0 -or $index -ge $Tools.Count) { continue }

        $selected = $Tools[$index]
        Invoke-ToolSafely -Tool $selected -Context $Context
        Write-Host "`nPress Enter to return to tools..."
        [void][System.Console]::ReadLine()
    }
}

function Show-Links {
    $linksFile = Join-Path $DataRoot 'main/links/links.txt'

    Clear-Host
    Write-Host 'Links' -ForegroundColor Green
    Write-Host '-----'

    if (-not (Test-Path $linksFile)) {
        Write-Log "Links file not found at $linksFile" 'WARN'
        [void](Read-Host 'Press Enter to return')
        return
    }

    Get-Content -Path $linksFile | ForEach-Object { Write-Host "- $_" }
    Write-Host
    [void](Read-Host 'Press Enter to return')
}

function Show-Menu {
    param(
        [array]$Tools,
        $Context
    )

    while ($true) {
        Clear-Host
        Write-Host 'Wandering Toolkit' -ForegroundColor Green
        Write-Host '-----------------'
        Write-Host '[1] Tools'
        Write-Host '[2] Links'
        Write-Host '[R] Reload tools'
        Write-Host '[Q] Quit'
        $choice = Read-Host 'Enter choice'

        if ([string]::IsNullOrWhiteSpace($choice)) { continue }
        if ($choice -match '^[Qq]') { break }
        if ($choice -match '^[Rr]') {
            $Tools = Import-Tools
            continue
        }
        if ($choice -match '^[1]') {
            if (-not $Tools -or $Tools.Count -eq 0) {
                Write-Log "No tools found in $ToolsRoot" 'WARN'
                [void](Read-Host 'Press Enter to return')
                continue
            }
            Show-ToolsMenu -Tools $Tools -Context $Context
            continue
        }
        if ($choice -match '^[2]') {
            Show-Links
            continue
        }
    }
}

function Bootstrap {
    Ensure-Directories
    $wingetOk = Ensure-WinGet
    $ps7Ok = Ensure-PowerShell7
    $steamOk = Ensure-SteamCmd

    if (-not $wingetOk) { Write-Log 'WinGet may not be installed; some automated installs could fail.' 'WARN' }
    if (-not $ps7Ok)  { Write-Log 'PowerShell 7 is recommended; relaunch in PS7 when ready.' 'WARN' }
    if (-not $steamOk) { Write-Log 'SteamCMD install did not complete.' 'WARN' }
}

Init-Logging
try {
    if (-not $NoBootstrap) {
        Bootstrap
    }

    $context = [ordered]@{
        Root        = $ProjectRoot
        ToolsRoot   = $ToolsRoot
        DataRoot    = $DataRoot
        LogsRoot    = $LogsRoot
        SteamCmdDir = $SteamCmdDir
        SteamCmdExe = $SteamCmdExe
        LogFile     = $LogFile
        Log         = { param($Message, $Level = 'INFO') Write-Log -Message $Message -Level $Level }
        Timestamp   = (Get-Date)
    }

    $tools = Import-Tools
    if (-not $tools -or $tools.Count -eq 0) {
        Write-Log "No tools found in $ToolsRoot. Add a folder with tool.ps1 to appear here." 'WARN'
        [void](Read-Host 'Press Enter to exit')
        return
    }

    Show-Menu -Tools $tools -Context $context
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" 'ERROR'
    Write-Host "Fatal error encountered. Press Enter to exit." -ForegroundColor Red
    [void](Read-Host)
}
finally {
    if ($TranscriptRunning) {
        try { Stop-Transcript | Out-Null } catch {}
    }
}
