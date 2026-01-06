$script:ATSDownloaderRoot = Split-Path -Parent $PSCommandPath

@{
    Name          = 'ATS Files Downloader'
    Description   = 'Auto-download ATS support tools from the bundled links list'
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

        # Resolve tool root (works under strict mode when sourced).
        $toolRoot = $script:ATSDownloaderRoot
        if (-not $toolRoot -and $Context.ToolsRoot) {
            $toolRoot = Join-Path $Context.ToolsRoot 'ATS Files Downloader'
        }
        if (-not $toolRoot) {
            & $Context.Log 'ATS downloader tool root not resolved.' 'ERROR'
            return
        }

        $scriptPath = Join-Path $toolRoot 'ats-auto-installer.ps1'
        if (-not (Test-Path $scriptPath)) {
            & $Context.Log "Installer script missing at $scriptPath" 'ERROR'
            return
        }

        $linksFile = Join-Path $toolRoot 'download links that work.txt'
        $downloadRoot = Join-Path $Context.DataRoot 'downloads/ATS'
        $shell = (Get-Command pwsh -ErrorAction SilentlyContinue) ? 'pwsh' : 'powershell'

        if (-not (Test-Path $downloadRoot)) { New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null }

        & $Context.Log "Running ATS auto-installer; output -> $downloadRoot" 'INFO'
        & $shell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath -LinksFile $linksFile -OutputDir $downloadRoot
    }
}
