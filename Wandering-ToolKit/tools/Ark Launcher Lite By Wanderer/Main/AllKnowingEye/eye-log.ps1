param(
    [Parameter(Mandatory = $true)][string]$ServerName,
    [string]$Map,
    [string]$InstallDir,
    [int]$GamePort,
    [int]$QueryPort,
    [int]$RconPort,
    [SecureString]$RconPassword,
    [int]$MaxPlayers,
    [string]$ClusterID,
    [string]$Mods,
    [string]$ProcessName,
    [string]$ExecutablePath,
    [string]$Status,
    [string]$Note
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$eyeJson = Join-Path $root 'eye.json'
$eyeTxt = Join-Path $root 'eye.txt'
$now = [DateTime]::UtcNow.ToString('s') + 'Z'

$serverDefaults = @{
    'Event'         = @{ Map='Event';         GamePort=7856; QueryPort=27095; RconPort=32402; PublicIP='45.248.49.77' }
    'Testing'       = @{ Map='Testing';       GamePort=7856; QueryPort=27095; RconPort=32402; PublicIP='45.248.49.77' }
    'TheIsland'     = @{ Map='TheIsland';     GamePort=7837; QueryPort=27075; RconPort=32390; PublicIP='45.248.49.77' }
    'ScorchedEarth' = @{ Map='ScorchedEarth'; GamePort=7839; QueryPort=27077; RconPort=32391; PublicIP='45.248.49.77' }
    'TheCenter'     = @{ Map='TheCenter';     GamePort=7841; QueryPort=27079; RconPort=32392; PublicIP='45.248.49.77' }
    'Extinction'    = @{ Map='Extinction';    GamePort=7849; QueryPort=27087; RconPort=32396; PublicIP='45.248.49.77' }
    'Aberration'    = @{ Map='Aberration';    GamePort=7853; QueryPort=27091; RconPort=32398; PublicIP='45.248.49.77' }
    'Ragnarok'      = @{ Map='Ragnarok';      GamePort=7843; QueryPort=27081; RconPort=32393; PublicIP='45.248.49.77' }
    'Valguero'      = @{ Map='Valguero';      GamePort=7777; QueryPort=27098; RconPort=32405; PublicIP='45.248.49.77' }
    'BobsMissions'  = @{ Map='BobsMissions';  GamePort=7851; QueryPort=27089; RconPort=32397; PublicIP='45.248.49.77' }
    'Astraeos'      = @{ Map='Astraeos';      GamePort=7847; QueryPort=27085; RconPort=32395; PublicIP='45.248.49.77' }
    'EmeraldIsles'  = @{ Map='EmeraldIsles';  GamePort=7845; QueryPort=27083; RconPort=32394; PublicIP='45.248.49.77' }
    'TheVolcano'    = @{ Map='TheVolcano';    GamePort=7857; QueryPort=27097; RconPort=32404; PublicIP='45.248.49.77' }
    'Amissa'        = @{ Map='Amissa';        GamePort=7855; QueryPort=27093; RconPort=32401; PublicIP='45.248.49.77' }
    'ClubARK'       = @{ Map='ClubARK';       GamePort=$null; QueryPort=$null; RconPort=$null; PublicIP='45.248.49.77' }
}

function Get-EyeData {
    if (-not (Test-Path -Path $eyeJson)) { return @() }
    try {
        $raw = Get-Content -Path $eyeJson -Raw
        if (-not $raw) { return @() }
        $parsed = $raw | ConvertFrom-Json
        if ($null -eq $parsed) { return @() }
        if ($parsed -is [System.Collections.IList] -or $parsed -is [array]) { return $parsed }
        return ,$parsed
    } catch {
        Write-Warning "eye-log: failed to parse eye.json - $($_.Exception.Message)"
        return @()
    }
}

function Set-EyeData($items) {
    $items | ConvertTo-Json -Depth 6 | Set-Content -Path $eyeJson -Encoding UTF8
    $lines = @()
    foreach ($i in $items) {
        $line = "ServerName=$($i.ServerName)|Map=$($i.Map)|GamePort=$($i.GamePort)|QueryPort=$($i.QueryPort)|RconPort=$($i.RconPort)|ProcessName=$($i.ProcessName)|Exe=$($i.ExecutablePath)|Cluster=$($i.ClusterID)|Status=$($i.Status)|LastUpdateUtc=$($i.LastUpdateUtc)|LastRconOkUtc=$($i.LastRconOkUtc)|PublicIP=$($i.PublicIP)|Note=$($i.Note)"
        $lines += $line
    }
    $lines | Set-Content -Path $eyeTxt -Encoding ascii
}

function Set-IfPresent([psobject]$obj, [string]$name, $value) {
    if ($PSBoundParameters.ContainsKey($name) -and $null -ne $value -and $value -ne '') {
        $obj.$name = $value
    }
}

function Set-EyeProperty([psobject]$obj, [string]$name) {
    # Match() returns a collection that is truthy even when empty; check Names instead
    if (-not ($obj.PSObject.Properties.Name -contains $name)) {
        $obj | Add-Member -NotePropertyName $name -NotePropertyValue $null -Force
    }
}

function ConvertTo-Plain([SecureString]$sec) {
    if (-not $sec) { return $null }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

$items = @(Get-EyeData) # force array even when JSON is a single object
$entry = $items | Where-Object { $_.ServerName -eq $ServerName } | Select-Object -First 1
if (-not $entry) {
    $entry = [pscustomobject]@{
        ServerName    = $ServerName
        CreatedUtc    = $now
    }
    $items = @($items) + $entry
}

# Ensure the object has all expected properties so later assignments do not fail
$expectedProps = 'Map','InstallDir','GamePort','QueryPort','RconPort','PublicIP','RconPassword','MaxPlayers','ClusterID','Mods','ProcessName','ExecutablePath','Status','Note','LastStartUtc','LastUpdateUtc','LastRconOkUtc'
foreach ($p in $expectedProps) { Set-EyeProperty $entry $p }

# Apply built-in defaults when fields are missing
if ($serverDefaults.ContainsKey($ServerName)) {
    $defaults = $serverDefaults[$ServerName]
    foreach ($k in $defaults.Keys) {
        if (-not $entry.$k) { $entry.$k = $defaults[$k] }
    }
}

Set-IfPresent $entry 'Map' $Map
Set-IfPresent $entry 'InstallDir' $InstallDir
Set-IfPresent $entry 'GamePort' $GamePort
Set-IfPresent $entry 'QueryPort' $QueryPort
Set-IfPresent $entry 'RconPort' $RconPort
if ($PSBoundParameters.ContainsKey('RconPassword')) {
    $plain = ConvertTo-Plain $RconPassword
    if ($plain) { $entry.RconPassword = $plain }
}
Set-IfPresent $entry 'MaxPlayers' $MaxPlayers
Set-IfPresent $entry 'ClusterID' $ClusterID
Set-IfPresent $entry 'Mods' $Mods
Set-IfPresent $entry 'ProcessName' $ProcessName
Set-IfPresent $entry 'ExecutablePath' $ExecutablePath
Set-IfPresent $entry 'Note' $Note
if ($Status) { $entry.Status = $Status }
if ($Status -eq 'Started') { $entry.LastStartUtc = $now }
if ($Status -eq 'Updated') { $entry.LastUpdateUtc = $now }
$entry.LastUpdateUtc = $now

Set-EyeData $items
