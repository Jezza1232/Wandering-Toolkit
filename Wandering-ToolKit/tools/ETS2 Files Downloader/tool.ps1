$script:ETS2DownloaderRoot = Split-Path -Parent $PSCommandPath

@{
    Name          = 'ETS2 Files Downloader'
    Description   = 'Auto-download ETS2 support tools from the bundled links list'
    Version       = '0.2.0'
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

        # Resolve tool root (strict mode safe) with context fallback.
        $toolRoot = $script:ETS2DownloaderRoot
        if (-not $toolRoot -and $Context.ToolsRoot) {
            $toolRoot = Join-Path $Context.ToolsRoot 'ETS2 Files Downloader'
        }
        if (-not $toolRoot) {
            & $Context.Log 'ETS2 downloader tool root not resolved.' 'ERROR'
            return
        }

        $scriptPath = Join-Path $toolRoot 'ets2-auto-downloader.ps1'
        if (-not (Test-Path $scriptPath)) {
            & $Context.Log "Downloader script missing at $scriptPath" 'ERROR'
            return
        }

        $downloadRoot = Join-Path $Context.DataRoot 'downloads/ETS2'
        $shell = (Get-Command pwsh -ErrorAction SilentlyContinue) ? 'pwsh' : 'powershell'

        if (-not (Test-Path $downloadRoot)) { New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null }

        & $Context.Log "Running ETS2 downloader; output -> $downloadRoot" 'INFO'
        & $shell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath -DownloadRoot $downloadRoot
    }
}
