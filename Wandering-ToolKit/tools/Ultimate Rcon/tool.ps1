$script:UltimateRconRoot = Split-Path -Parent $PSCommandPath

@{
    Name          = 'Ultimate Rcon'
    Description   = 'Launches the Ultimate Rcon client from data/rcon'
    Version       = '0.1.0'
    RequiresAdmin = $false

    Test = {
        param($Context)
        return $true
    }

    Init = {
        param($Context)
    }

    Invoke = {
        param($Context)

        $toolRoot = $script:UltimateRconRoot
        if (-not $toolRoot -and $Context.ToolsRoot) {
            $toolRoot = Join-Path $Context.ToolsRoot 'Ultimate Rcon'
        }
        if (-not $toolRoot) {
            & $Context.Log 'Ultimate Rcon tool root not resolved.' 'ERROR'
            return
        }

        $exe = Join-Path $Context.DataRoot 'rcon/UltimateRcon.exe'
        if (-not (Test-Path $exe)) {
            & $Context.Log "UltimateRcon.exe not found at $exe" 'ERROR'
            return
        }

        & $Context.Log 'Launching Ultimate Rcon...' 'INFO'
        Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) | Out-Null
    }
}
