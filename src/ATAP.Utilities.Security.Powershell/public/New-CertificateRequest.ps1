#############################################################################
#region New-CertificateRequest
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
Function New-CertificateRequest {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName ='DefaultParameterSetNameReplacementPattern'  )]
  param (
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [alias('DNHash')]
    [object] $DistinguishedNameHash
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType 'Container' })]
    [string] $CertificateRequestPath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string] $EncryptedPrivateKeyPath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string] $EncryptionKeyPassPhrasePath
    , [switch] $Force
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # $DebugPreference = 'SilentlyContinue'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {      # ToDo: validate Subject and SubjectAlternativeName
    if ($PSCmdlet.ShouldProcess($null, "Create new CertificateRequest '$CertificateRequestPath' from '$CertificateRequestConfigPath' using subject = '$($DistinguishedNameHash.DNAsParameter)' and ValidityPeriod = $ValidityPeriod and ValidityPeriodUnits = $ValidityPeriodUnits")) {
        # ToDo: Add SAN from DistinguishedNameHash
#$tmpfile = 'C:\Dropbox\Security\Certificates\temp\sanTemp.txt'
#$DistinguishedNameHash.SubjectAlternateName | Set-Content -Path $tmpfile -Encoding $Encoding
      #ToDo: figure out how to ceate a callable command and arguments passed on what parameters are not passed
      $command = "openssl req -new -batch -sha256 -subj ""$($DistinguishedNameHash.DNAsParameter)"" -addext ""$($DistinguishedNameHash.BasicConstraints)"" -addext ""$($DistinguishedNameHash.KeyUsage)"""
      if (-not [string]::IsNullOrEmpty($DistinguishedNameHash.ExtendedkeyUsage)) {
        $command = $Command + " -addext ""$($DistinguishedNameHash.ExtendedkeyUsage)"""
      }
      if (-not [string]::IsNullOrEmpty($DistinguishedNameHash.SubjectAlternateName)) {
        $command = $Command + " -addext ""$($DistinguishedNameHash.SubjectAlternateName)"""
      }
      if (-not [string]::IsNullOrEmpty($DistinguishedNameHash.FriendlyName)) {
        $command = $Command + " -addext ""$($DistinguishedNameHash.FriendlyName)"""
      }
      $command = $command + " -key ""$EncryptedPrivateKeyPath"" -passin file:""$EncryptionKeyPassPhrasePath"" -out ""$CertificateRequestPath""" #-passout file:""$EncryptionKeyPassPhrasePath""
      $command
      Invoke-Expression $command
      #openssl req -new -batch -sha256 -subj $($DistinguishedNameHash.DNAsParameter) -addext $($DistinguishedNameHash.BasicConstraints) -addext $($DistinguishedNameHash.KeyUsage) -addext $($DistinguishedNameHash.ExtendedkeyUsage) -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -passout file:$EncryptionKeyPassPhrasePath  -out $CertificateRequestPath
      #openssl req -new -batch -sha256 -subj $($DistinguishedNameHash.DNAsParameter) -addext $($DistinguishedNameHash.ExtendedkeyUsage) -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -passout file:$EncryptionKeyPassPhrasePath  -out $CertificateRequestPath
      #openssl req -new -batch -sha256  -subj $($DistinguishedNameHash.DNAsParameter) -config $CertificateRequestConfigPath -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificateRequestPath
      #openssl req -new -batch -sha256 -subj $($DistinguishedNameHash.DNAsParameter) -config $CertificateRequestConfigPath  -addext $($DistinguishedNameHash.ExtendedkeyUsage) -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificateRequestPath
      #ToDo:Fix this
      #(((Get-Content $CertificateRequestConfigPath) -replace 'Subject = .*', ('Subject = "' + $Subject + '"')) -replace '%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}.*', ('%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}' + $SubjectAlternativeName + '"')) |
      # Out-File -Path $CertificateRequestPath -Encoding $Encoding

    }
}
  #endregion ProcessBlock
  #region EndBlock
  END {
    Write-PSFMessage -Level Debug -Message 'Ending Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion New-CertificateRequest
#############################################################################


