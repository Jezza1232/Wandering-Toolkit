param(
    [string]$Keyword
)

# Configuration
$ErrorActionPreference = 'Continue'
$knownFragments = @('Death-Valley','ark','ARK','Backup','Back-Up','Steam','steamcmd','steamCMD','SteamCMD','game-servers','ascended')
$explicitExcludes = @('C:\Windows','C:\Program Files','C:\Program Files (x86)')
$logDir = Join-Path -Path $PSScriptRoot -ChildPath 'SearchLogs'
if (-not (Test-Path -Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$now = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$txtLog = Join-Path -Path $logDir -ChildPath "SearchLog_$now.txt"
$jsonLog = Join-Path -Path $logDir -ChildPath "SearchResults_$now.json"
$statusFile = Join-Path -Path $logDir -ChildPath "SearchStatus_$now.txt"
$stopFile = Join-Path -Path $logDir -ChildPath "STOP"

# Performance and safety settings
$extensions = @('*.txt','*.ini','*.cfg','*.log','*.json','*.xml')   # set $null to search all
$maxFileSizeMB = 20      # skip files larger than this
$batchSize = 12          # number of folders processed then sleep
$batchDelayMs = 200      # sleep between batches
$skipReparsePoints = $true

# Helpers (UTF-8) and lore header (plain ASCII hyphen)
$loreHeader = "Echo's little bro - Search Sentinel | Run: $(Get-Date) | Keyword: $Keyword"
# write lore header to txt log
$loreHeader | Out-File -FilePath $txtLog -Encoding utf8
# write a tiny metadata object to the JSON file before results are saved
$loreMeta = @{ Tool = "Echo's little bro"; Run = (Get-Date).ToString('s'); Keyword = $Keyword }
$loreMeta | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonLog -Encoding utf8

function Log {
    param([string]$Line)
    $Line | Out-File -FilePath $txtLog -Append -Encoding utf8
    Write-Host $Line
}

function SaveJson($obj) {
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonLog -Encoding utf8
}

function UpdateStatus([string]$line) {
    $line | Out-File -FilePath $statusFile -Append -Encoding utf8
}

# Prompt keyword if not provided
if (-not $Keyword -or $Keyword.Trim() -eq '') { $Keyword = Read-Host "Enter search keyword" }
Log "Keyword: $Keyword"
UpdateStatus "Started at: $(Get-Date)"
UpdateStatus "Keyword: $Keyword"

# Discover drives
$drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
Log "Drives detected: $($drives -join ', ')"
UpdateStatus "Drives: $($drives -join ', ')"

$results = New-Object System.Collections.Generic.List[object]
$folderCount = 0
$foundCount = 0
$processed = 0

foreach ($d in $drives) {
    # Abort check before each drive
    if (Test-Path -Path $stopFile) { Log 'Abort file detected before drive start — exiting gracefully.'; break }

    Log "Scanning drive: $d"
    try {
        $dirs = Get-ChildItem -Path $d -Directory -Recurse -ErrorAction SilentlyContinue
        if ($skipReparsePoints) {
            $dirs = $dirs | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }
        }
    } catch {
        Log "Warning: cannot enumerate directories on $d - $($_.Exception.Message)"
        continue
    }

    foreach ($dir in $dirs) {
        # Abort check periodically inside the folder loop
        if (Test-Path -Path $stopFile) { Log 'Abort file detected — exiting gracefully.'; break 2 }

        $full = $dir.FullName.TrimEnd([char]92)
        # Exclude explicit paths
        if ($explicitExcludes -contains $full) { continue }

        # Skip common prefixes quickly
        $skipThis = $false
        foreach ($ex in $explicitExcludes) {
            if ($full.StartsWith($ex, [System.StringComparison]::InvariantCultureIgnoreCase)) { $skipThis = $true; break }
        }
        if ($skipThis) { continue }

        $folderCount++
        # Partial fragment match against folder name and full path
        $name = $dir.Name
        $match = $false
        foreach ($frag in $knownFragments) {
            if ($name.IndexOf($frag, [System.StringComparison]::InvariantCultureIgnoreCase) -ge 0 -or
                $full.IndexOf($frag, [System.StringComparison]::InvariantCultureIgnoreCase) -ge 0) {
                $match = $true
                break
            }
        }
        if (-not $match) { continue }

        Log "Matched folder: $full"
        UpdateStatus "Matched: $full"
        $processed++

        # Enumerate files inside matched folder (respect extension filter)
        try {
            if ($null -ne $extensions -and $extensions.Count -gt 0) {
                $files = foreach ($ext in $extensions) { Get-ChildItem -Path $full -File -Recurse -Include $ext -ErrorAction SilentlyContinue }
            } else {
                $files = Get-ChildItem -Path $full -File -Recurse -ErrorAction SilentlyContinue
            }
        } catch {
            Log "Warning: error enumerating files in $full - $($_.Exception.Message)"
            continue
        }

        foreach ($f in $files) {
            try {
                if ($f.Length -gt ($maxFileSizeMB * 1MB)) { continue }
            } catch {
                continue
            }

            try {
                $matches = Select-String -Path $f.FullName -Pattern $Keyword -SimpleMatch -CaseSensitive:$false -ErrorAction SilentlyContinue
            } catch {
                continue
            }

            if ($matches) {
                foreach ($m in $matches) {
                    $entry = [PSCustomObject]@{
                        Timestamp = (Get-Date).ToString('s')
                        Drive = $d.TrimEnd([char]92)
                        MatchedFolder = $full
                        File = $f.FullName
                        LineNumber = $m.LineNumber
                        Line = $m.Line.Trim()
                    }
                    $results.Add($entry)
                    $foundCount++
                    Log "FOUND $($f.FullName) (Line $($m.LineNumber))"
                    Log $m.Line.Trim()
                    Log ""
                }
            }
        }

        if (($processed % $batchSize) -eq 0) {
            UpdateStatus "Processed $processed matched folders; found $foundCount matches; last: $full"
            Start-Sleep -Milliseconds $batchDelayMs
        }
    }
}

# Finalize logs
if ($results.Count -gt 0) {
    SaveJson $results
    Log "Search complete. Results found: $($results.Count). JSON saved: $jsonLog"
    UpdateStatus "Results: $($results.Count) found"
} else {
    Log "Search complete. No matches found."
    UpdateStatus "Results: 0 found"
}
Log "Folders scanned: $folderCount"
UpdateStatus "Folders scanned: $folderCount"
Log "Finished at: $(Get-Date)"
UpdateStatus "Finished at: $(Get-Date)"
Read-Host -Prompt "Press Enter to exit"