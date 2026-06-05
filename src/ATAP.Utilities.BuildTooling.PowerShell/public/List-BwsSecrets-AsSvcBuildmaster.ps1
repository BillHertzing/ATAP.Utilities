if (-not $env:BWS_ACCESS_TOKEN) {
  try {
    $cred = Get-ServiceAccountBWSAccessToken -ErrorAction Stop
    $env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
  } catch {
    "ERROR: Failed to resolve BWS access token: $($_.Exception.Message)" |
      Out-File -FilePath 'C:\Tools\svcBuildmaster-bws-secrets.txt' -Encoding UTF8
    exit 1
  }
}

$raw = & bws secret list --output json 2>&1
if ($LASTEXITCODE -ne 0) {
  "ERROR: bws secret list failed (exit $LASTEXITCODE). Output:`n$raw" |
    Out-File -FilePath 'C:\Tools\svcBuildmaster-bws-secrets.txt' -Encoding UTF8
  exit $LASTEXITCODE
}

try {
  $secrets = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
  "ERROR: Failed to parse JSON from bws secret list: $($_.Exception.Message)" |
    Out-File -FilePath 'C:\Tools\svcBuildmaster-bws-secrets.txt' -Encoding UTF8
  exit 1
}

$secrets |
  Sort-Object key |
  Select-Object key, id, projectId |
  Out-File -FilePath 'C:\svcBuildmaster-bws-secrets.txt' -Encoding UTF8

