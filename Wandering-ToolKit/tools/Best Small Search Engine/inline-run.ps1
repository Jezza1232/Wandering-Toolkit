param(
    [Parameter(Mandatory=$true)][string]$ServerCmd,
    [Parameter(Mandatory=$true)][string]$LogPath,
    [Parameter(Mandatory=$true)][string]$DisplayName
)
$ErrorActionPreference = 'Continue'
try {
    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    "[$timestamp] $DisplayName launching inline" | Out-File -FilePath $LogPath -Encoding utf8 -Append
    Invoke-Expression $ServerCmd 2>&1 | Tee-Object -FilePath $LogPath -Append
    exit $LASTEXITCODE
} catch {
    "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] $DisplayName error: $($_.Exception.Message)" | Out-File -FilePath $LogPath -Encoding utf8 -Append
    exit 1
}
