$script:ArkLauncherToolRoot = Split-Path -Parent $PSCommandPath

# Template for a menu tool. Copy this file into a new folder under tools\ and adjust the fields.
@{
    Name         = 'Ark Launcher By Wanderer'
    Description  = 'bunch of scrips and setups for ark asa'
    Version      = '1.0.1'
    RequiresAdmin = $false

    # Optional: runs before Invoke. Return $true/$false to allow blocking launch.
    Test = {
        param($Context)
        return $true
    }

    # Optional: runs once before Invoke; use for lightweight prep.
    Init = {
        param($Context)
        # e.g., ensure a temp folder exists
    }

    # Required: main entry point for the tool.
    Invoke = {
        param($Context)

        # Resolve the tool folder; fall back to context if the script-scope variable is missing.
        $toolRoot = $script:ArkLauncherToolRoot
        if (-not $toolRoot -and $Context.ToolsRoot) {
            $toolRoot = Join-Path $Context.ToolsRoot 'Ark Launcher Lite By Wanderer'
        }

        if (-not $toolRoot) {
            & $Context.Log 'Ark Launcher tool root not resolved.' 'ERROR'
            return
        }

        $menuBat  = Join-Path $toolRoot 'Ark Menu.bat'

        if (-not (Test-Path $menuBat)) {
            & $Context.Log "Ark Menu not found at ${menuBat}" 'ERROR'
            return
        }

        & $Context.Log "Launching Ark Menu.bat from ${toolRoot}" 'INFO'

        Push-Location $toolRoot
        try {
            # Run batch inside current console so the menu stays interactive; quote path for spaces.
            & cmd.exe /c "`"$menuBat`""
        }
        finally {
            Pop-Location
        }
    }
}
