[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ })][string]$Path,
  [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{40,64}$')][string]$CertificateThumbprint,
  [Parameter(Mandatory)][uri]$TimestampServerUri
)

function Invoke-PSModuleFileSigningWorker {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$CertificateThumbprint,
    [Parameter(Mandatory)][uri]$TimestampServerUri
  )

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
  . (Join-Path $PSScriptRoot '..\public\Set-PSModuleFileSignature.ps1')
  $result = Set-PSModuleFileSignature `
    -Path $Path `
    -CertificateThumbprint $CertificateThumbprint `
    -TimestampServerUri $TimestampServerUri `
    -Confirm:$false
  'ATAP_SIGNING_RESULT:' + ($result | ConvertTo-Json -Depth 6 -Compress)
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-PSModuleFileSigningWorker @PSBoundParameters
}
