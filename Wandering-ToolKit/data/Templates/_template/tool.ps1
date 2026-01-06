# Template for a menu tool. Copy this file into a new folder under tools\ and adjust the fields.
@{
    Name         = 'Template Tool'
    Description  = 'just a example file for auto software adding'
    Version      = '0.1.0'
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

        # Use the shared logger if you need to record to Logs/.
        & $Context.Log 'Template Tool invoked' 'INFO'
        Write-Host "Running Template Tool from $($Context.Root)"
    }
}
