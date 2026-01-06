$script:WingetPreapprovedRoot = Split-Path -Parent $PSCommandPath

@{
    Name          = 'Winget Preapproved Installer'
    Description   = 'Installs software listed in data/main/Winget preapproved software.txt via winget'
    Version       = '0.1.0'
    RequiresAdmin = $true

    Test = {
        param($Context)
        return $true
    }

    Init = {
        param($Context)
    }

    Invoke = {
        param($Context)

        $toolRoot = $script:WingetPreapprovedRoot
        if (-not $toolRoot -and $Context.ToolsRoot) {
            $toolRoot = Join-Path $Context.ToolsRoot 'Winget Preapproved Installer'
        }
        if (-not $toolRoot) {
            & $Context.Log 'Winget tool root not resolved.' 'ERROR'
            return
        }

        $listPath = Join-Path $Context.DataRoot 'main/Winget preapproved software.txt'
        if (-not (Test-Path $listPath)) {
            & $Context.Log "List file missing at $listPath" 'ERROR'
            return
        }

        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $winget) {
            & $Context.Log 'winget not found. Install WinGet/App Installer first.' 'ERROR'
            return
        }

        $entries = @()
        foreach ($raw in Get-Content -LiteralPath $listPath) {
            $line = $raw.Trim()
            if (-not $line) { continue }
            if ($line.StartsWith('#') -or $line.StartsWith(';') -or $line.StartsWith('//')) { continue }

            $name = $null
            $id = $null
            if ($line -like '*|*') {
                $parts = $line.Split('|',2)
                $name = $parts[0].Trim()
                $id = $parts[1].Trim()
            } else {
                $id = $line
                $name = $line
            }

            if (-not $id) { continue }
            $entries += [pscustomobject]@{ Name = ($name -ne '' ? $name : $id); Id = $id }
        }

        if (-not $entries -or $entries.Count -eq 0) {
            & $Context.Log 'No entries found in preapproved list.' 'WARN'
            return
        }

        foreach ($entry in $entries) {
            $id = $entry.Id
            $name = $entry.Name
            & $Context.Log "Installing $name ($id) via winget" 'INFO'

            $args = @('install','--id',$id,'--exact','--accept-package-agreements','--accept-source-agreements','--silent','--source','winget')
            try {
                $proc = Start-Process -FilePath $winget.Source -ArgumentList $args -Wait -NoNewWindow -PassThru
                if ($proc.ExitCode -ne 0) {
                    & $Context.Log "$name ($id) install exit code $($proc.ExitCode)" 'WARN'
                } else {
                    & $Context.Log "$name ($id) installed" 'INFO'
                }
            }
            catch {
                & $Context.Log "$name ($id) failed: $($_.Exception.Message)" 'ERROR'
            }
        }
    }
}
