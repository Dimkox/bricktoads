$ErrorActionPreference = 'Stop'
$credentialPath = Join-Path $env:LOCALAPPDATA 'BrickToads\analytics\open-cloud.dpapi'
$previousKey = $env:ROBLOX_ANALYTICS_KEY
try {
    if (-not $previousKey) {
        $protected = Get-Content -Raw -LiteralPath $credentialPath
        $secure = ConvertTo-SecureString -String $protected.Trim()
        $env:ROBLOX_ANALYTICS_KEY = [Net.NetworkCredential]::new('', $secure).Password
    }
    & python -X utf8 (Join-Path $PSScriptRoot 'collect_roblox_ads.py')
    $result = $LASTEXITCODE
} finally {
    $env:ROBLOX_ANALYTICS_KEY = $previousKey
}
exit $result
