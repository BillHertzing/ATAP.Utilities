#############################################################################
#region New-CACertificate
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
Function New-CACertificate {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $EncryptedPrivateKeyPath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $EncryptionKeyPassPhrasePath
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
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CertificateRequestConfigPath
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # Convert vaility period/units into days
    $internalValidityDays =
    switch ($ValidityPeriodUnits) {
      'days' { $ValidityPeriod }
      'weeks' { $ValidityPeriod * 7 }
      'years' { $ValidityPeriod * 365 }
    }
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # openssl must be in the path
    # ToDo: lots of error handling
    # Because process prameters are visiblle in Windows, locking down the directories with ACL control, and lockng the ACL lists, is critical to security
    openssl req -new -batch -sha256 -x509 -subj $($DNHash.DNAsParameter) -days $internalValidityDays -key $EncryptedPrivateKeyPath -keyout $EncryptedPrivateKeyPath -passout file:$EncryptionKeyPassPhrasePath -out $CertificatePath
    #openssl req -new -batch -sha256 -x509 -subj $($DNHash.DNAsParameter) -days $internalValidityDays -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificatePath
    # openssl req -batch -x509 -config $CertificateRequestConfigPath -extensions 'ca' -subj $($DNHash.DNAsParameter) -days $internalValidityDays -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificatePath
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion New-CACertificate
#############################################################################


