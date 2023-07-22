#############################################################################
#region New-SignedCertificate
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function New-SignedCertificate {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName ='DefaultParameterSetNameReplacementPattern' )]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CertificateRequestPath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CACertificatePath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CAEncryptedPrivateKeyPath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CAEncryptionKeyPassPhrasePath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CASigningCertificatesCertificatesIssuedDBPath

    # ToDo: figure out better validation for ValidityPeriod and ValidityRange
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateRange(1, 1000)]
    [int16] $ValidityPeriod
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateSet('days', 'weeks', 'years')]
    [string] $ValidityPeriodUnits
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType Container })]
    [string] $CertificatePath
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {
    # Convert vaility period/units into days
    $internalValidityDays =
    switch ($ValidityPeriodUnits) {
      'days' { $ValidityPeriod }
      'weeks' { $ValidityPeriod * 7 }
      'years' { $ValidityPeriod * 365 }
    }
    # SSL Certificates are capped at 398 days, enforce that here
    if ($internalValidityDays -gt 398) {
      Write-PSFMessage -Level Warning -Message "Certificate's validity periods are capped at 398 days, $internalValidityDays days is too long"
      $internalValidityDays = 398
    }
    # openssl must be in the path
    # get just the filename portion of the CertificatePath
    # $CertificateName = Split-Path -Path $CertificatePath -Leaf
    $CertificateDir = Split-Path -Path $CertificatePath -Parent
    Write-PSFMessage -Level Debug -Message "CertificatePath = $CertificatePath"
    Write-PSFMessage -Level Debug -Message "CertificateDir = $CertificateDir"
    # Write-PSFMessage -Level Debug -Message "CertificateName = $CertificateName"
    # ToDo: lots of error handling
    $env:OPENSSL_SIGNINGCERTIFICATES_CERTIFICATES_ISSUED_DB_PATH = $CASigningCertificatesCertificatesIssuedDBPath
    # openssl writes the -out filename to the current working directory, but we want to write it to the $CertificateDir
    #Push-Location
    #Set-Location $CertificateDir
    # Note the the STDERR output is redirected to $null. openssl is writing a bunch of informational messages to stderr!
    openssl ca -batch -in $CertificateRequestPath -cert $CACertificatePath -keyfile $CAEncryptedPrivateKeyPath -passin file:$CAEncryptionKeyPassPhrasePath -days $internalValidityDays -outdir $CertificateDir -out $CertificatePath 2>$null
    #openssl ca -batch -cert $CACertificatePath -keyfile $CAEncryptedPrivateKeyPath -passin file:$CAEncryptionKeyPassPhrasePath -days $internalValidityDays -in $CertificateRequestPath -outdir $CertificateDir -out $CertificateName 2>$null
    #Pop-Location
    #[Environment]::SetEnvironmentVariable('OPENSSL_SIGNINGCERTIFICATES_SERIAL_PATH',$null,"Process")
    [Environment]::SetEnvironmentVariable('OPENSSL_SIGNINGCERTIFICATES_CERTIFICATES_ISSUED_DB_PATH', $null, 'Process')
    #[Environment]::SetEnvironmentVariable('OPENSSL_SIGNINGCERTIFICATES_NEW_CERTS_PATH',$null,"Process")
    # Copy the new certificate to the full CertificatePath
    # copy-item $(Join-Path $CASigningCertificatesNewCertificatesPath $CertificateName) $CertificatePath
    # openssl seems to fail to updte the DB txt file if not paused for a bit
    Start-Sleep -Milliseconds 100

  }
  #endregion ProcessBlock
  #region EndBlock
  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion New-SignedCertificate
#############################################################################


