function List-CodeSigningCertificates {
  <#
  .SYNOPSIS
  Lists usable code-signing certificates.
  .DESCRIPTION
  Returns non-expired certificates with private keys and the Code Signing EKU from selected Windows personal stores.
  .PARAMETER Path
  Certificate-store paths to inspect. Retained as Path for compatibility.
  .PARAMETER IncludeExpired
  Includes expired certificates.
  .OUTPUTS
  System.Security.Cryptography.X509Certificates.X509Certificate2
  .EXAMPLE
  List-CodeSigningCertificates
  .NOTES
  The nonstandard List verb is retained for compatibility per the approved deferred-rename decision.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding()]
  [OutputType([Security.Cryptography.X509Certificates.X509Certificate2])]
  param(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string[]] $Path = @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My'),
    [switch] $IncludeExpired
  )
  begin { $fn = 'List-CodeSigningCertificates'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    if (-not $IsWindows) { throw 'Windows certificate stores are required.' }
    foreach ($storePath in $Path) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Inspecting '$storePath'." -Tag 'Trace'
      Get-ChildItem -LiteralPath $storePath -ErrorAction Stop | Where-Object {
        $ekuOids = @($_.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object Value })
        $_.HasPrivateKey -and '1.3.6.1.5.5.7.3.3' -in $ekuOids -and ($IncludeExpired -or $_.NotAfter -gt [DateTime]::UtcNow)
      }
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
