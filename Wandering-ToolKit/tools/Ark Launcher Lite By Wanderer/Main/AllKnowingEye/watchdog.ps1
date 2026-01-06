param(
    [int]$PollSeconds = 60,
    [int]$MaxRetries = 2,
    [int]$RestartDelaySeconds = 10,
    [int]$WarmupSeconds = 180,
    [switch]$AutoRestart,
    [string]$DiscordWebhook = '',
    [string]$RconClient = ''
)

# Simple watchdog that reads eye.json, attempts RCON pings, and logs status.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$eyeJson = Join-Path $root 'eye.json'
$logFile = Join-Path $root 'watchdog.log'
$stopFile = Join-Path $root 'STOP'
$eyeLogger = Join-Path $root 'eye-log.ps1'
$startRoot = Split-Path (Split-Path $root -Parent) -Parent  # points to C:\ServerStartFiles
$startScripts = Join-Path $startRoot 'start files'
if (-not $RconClient) { $RconClient = Join-Path $root 'rcon.exe' }

function Log([string]$msg) {
    $line = "$(Get-Date -Format s)Z $msg"
    $line | Tee-Object -FilePath $logFile -Append | Out-Null
}

function Send-Discord([string]$text) {
    if (-not $DiscordWebhook) { return }
    try {
        Invoke-RestMethod -Method Post -Uri $DiscordWebhook -Body (@{ content = $text } | ConvertTo-Json) -ContentType 'application/json' | Out-Null
    } catch {
        Log "discord send failed: $($_.Exception.Message)"
    }
}

function Get-EyeData {
    if (-not (Test-Path -Path $eyeJson)) { return @() }
    try {
        $raw = Get-Content -Path $eyeJson -Raw
        if (-not $raw) { return @() }
        $parsed = $raw | ConvertFrom-Json
        if ($null -eq $parsed) { return @() }
        if ($parsed -is [System.Collections.IEnumerable]) { return @($parsed) }
        return @($parsed)
    } catch {
        Log "failed to parse eye.json: $($_.Exception.Message)"
        return @()
    }
}

function Initialize-ConfigPresence {
    param([Parameter(Mandatory=$true)]$Entry)
    if (-not $Entry.InstallDir) { return $null }
    $cfgDir = Join-Path $Entry.InstallDir "ShooterGame\Saved\Config\WindowsServer"
    if (-not (Test-Path -Path $cfgDir)) {
        try {
            $null = New-Item -ItemType Directory -Path $cfgDir -Force
            Log "Created config folder for $($Entry.ServerName) at $cfgDir"
        }
        catch {
            Log "Failed to create config folder for $($Entry.ServerName): $($_.Exception.Message)"
            return $cfgDir
        }
    }
    $gameIni = Join-Path $cfgDir 'Game.ini'
    if (-not (Test-Path -Path $gameIni)) {
        try {
            $null = New-Item -ItemType File -Path $gameIni -Force
            Log "Created missing Game.ini for $($Entry.ServerName) at $gameIni"
        }
        catch {
            Log "Failed to create Game.ini for $($Entry.ServerName): $($_.Exception.Message)"
        }
    }
    return $cfgDir
}

function Set-RconPassword {
    $entries = Get-EyeData
    if (-not $entries -or $entries.Count -eq 0) { return }

    $missing = $entries | Where-Object { -not $_.RconPassword }
    foreach ($m in $missing) {
        $cfgDir = Initialize-ConfigPresence -Entry $m
        if (-not $cfgDir) { continue }
        $adminPassword = Get-RconFromIni -Entry $m
        if ($adminPassword) {
            try {
                $sec = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
                & $eyeLogger -ServerName $m.ServerName -RconPassword $sec | Out-Null
                Log "Set RCON/admin password for $($m.ServerName) from GameUserSettings.ini"
            }
            catch {
                Log "Failed to set RCON/admin password for $($m.ServerName) from ini: $($_.Exception.Message)"
            }
        }
    }
}

function Get-RconFromIni {
    param([Parameter(Mandatory=$true)]$Entry)
    if (-not $Entry.InstallDir) { return $null }
    $gus = Join-Path $Entry.InstallDir "ShooterGame\Saved\Config\WindowsServer\GameUserSettings.ini"
    if (-not (Test-Path $gus)) { return $null }
    try {
        $match = Get-Content -Path $gus -Raw | Select-String -Pattern '^ServerAdminPassword=(.+)$' -AllMatches | Select-Object -First 1
        if ($match) { return $match.Matches[0].Groups[1].Value }
    } catch { return $null }
    return $null
}

function Update-EyeStatus([string]$name, [string]$status, [string]$note = '') {
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $eyeLogger -ServerName $name -Status $status -Note $note | Out-Null
    } catch {
        Log "eye-log call failed for ${name}: $($_.Exception.Message)"
    }
}

function Send-Rcon($entry, [string]$command) {
    if (-not $entry.RconPort) { return $null }
    if (-not $entry.RconPassword) { return $null }
    if (-not (Test-Path -Path $RconClient)) {
        Log "rcon client missing at $RconClient"
        return $null
    }
    $endpoint = ('127.0.0.1:{0}' -f $entry.RconPort)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $RconClient
    $psi.Arguments = "-a ${endpoint} -p $($entry.RconPassword) $command"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) {
        Log "rcon error [$($entry.ServerName)]: $err"
        return $null
    }
    return $out
}

function Get-ServerProcess($entry) {
    $procName = $entry.ProcessName
    if (-not $procName) { $procName = 'ArkAscendedServer.exe' }
    try {
        $procs = Get-CimInstance Win32_Process -Filter "Name='$procName'"
    } catch {
        return @()
    }
    $matchList = @()
    foreach ($p in $procs) {
        $cmd = $p.CommandLine
        if (-not $cmd) { continue }
        if ($entry.ExecutablePath -and $p.ExecutablePath -and ($p.ExecutablePath -ieq $entry.ExecutablePath)) { $matchList += $p; continue }
        if ($entry.GamePort -and $cmd -match "Port=$($entry.GamePort)") { $matchList += $p; continue }
        if ($entry.Map -and $cmd -match [regex]::Escape($entry.Map)) { $matchList += $p; continue }
        if ($entry.InstallDir -and $cmd -match [regex]::Escape($entry.InstallDir)) { $matchList += $p; continue }
    }
    return $matchList
}

Log "watchdog starting with poll=$PollSeconds s, retries=$MaxRetries, autoRestart=$AutoRestart, warmup=$WarmupSeconds"
Log "watchdog using eye.json at $eyeJson"

$lastNoServersLog = $null

Set-RconPassword

while (-not (Test-Path -Path $stopFile)) {
    $entries = Get-EyeData | Where-Object { $_.Status -eq 'Started' }
    Log "checking $($entries.Count) started entries from eye.json"
    if (-not $entries -or $entries.Count -eq 0) {
        if (-not $lastNoServersLog -or (New-TimeSpan -Start $lastNoServersLog -End (Get-Date)).TotalMinutes -ge 1) {
            Log "no started servers found in eye.json"
            $lastNoServersLog = Get-Date
        }
        Start-Sleep -Seconds $PollSeconds
        continue
    }
    foreach ($e in $entries) {
        $name = $e.ServerName
        Log "checking $name"
        $ageSeconds = $null
        if ($e.LastStartUtc) {
            $parsed = [datetime]::MinValue
            if ([DateTime]::TryParse([string]$e.LastStartUtc, [ref]$parsed)) {
                $ageSeconds = [int]((Get-Date).ToUniversalTime() - $parsed.ToUniversalTime()).TotalSeconds
            }
        }
        if ($null -ne $ageSeconds -and $ageSeconds -lt $WarmupSeconds) {
            Log "${name}: warmup in progress ($ageSeconds s < $WarmupSeconds s), skipping crash checks"
            continue
        }
        $ok = $false
        for ($i = 1; $i -le $MaxRetries; $i++) {
            $resp = Send-Rcon $e 'GetGameLog'
            if ($resp) { $ok = $true; break }
            Start-Sleep -Seconds 5
        }
        if ($ok) {
            Update-EyeStatus -name $name -status 'Started' -note 'RCON ok'
            continue
        }

        $procs = Get-ServerProcess $e
        if ($procs.Count -gt 0) {
            Log "$($name): no RCON reply but process still running"
            continue
        }

        Log "$($name): crash suspected (no process + RCON failures)"
        Update-EyeStatus -name $name -status 'Crash' -note 'Watchdog detected crash'
        Send-Discord "Watchdog: $name crashed at $(Get-Date -Format s)Z"

        if ($AutoRestart.IsPresent) {
            Log "$($name): restarting after $RestartDelaySeconds seconds"
            Start-Sleep -Seconds $RestartDelaySeconds
            $starter = Join-Path $startScripts "start_$name.bat"
            if (Test-Path -Path $starter) {
                Log "$($name): starting $starter"
                Start-Process -FilePath $starter -WorkingDirectory $startScripts | Out-Null
            } else {
                # Fallback to legacy location in case scripts are still at root.
                $legacyStarter = Join-Path $startRoot "start_$name.bat"
                if (Test-Path -Path $legacyStarter) {
                    Log "$($name): starting legacy $legacyStarter"
                    Start-Process -FilePath $legacyStarter -WorkingDirectory $startRoot | Out-Null
                } else {
                    Log "$($name): starter $starter not found (legacy path also missing)"
                }
            }
        }
    }

    Start-Sleep -Seconds $PollSeconds
}

Log 'watchdog stop file detected, exiting'
