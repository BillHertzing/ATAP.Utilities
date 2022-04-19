#function rotateCA {
#[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet' )]
#Param(
#$ValidityPeriod = 1
#, $ValidityPeriodUnits = 'year'
#, [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
#[string] $Encoding
#
#)
function Get-DNSubject {
  param(
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $CN
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $emailAddress
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $SubjectReplacementPattern
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $SubjectAlternativeNameReplacementPattern
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Country
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $StateOrTerritory
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Locality
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Organization
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $OrganizationUnit
  )
  New-Object PSObject -Property @{
    AsFileName     = $SubjectReplacementPattern -f $CN, $OrganizationUnit, $Organization, $StateOrTerritory, $Locality, $Country
    AsParameter    = "/CN=$CN/OU=$OrganizationUnit/O=$Organization/L=$Locality/ST=$StateOrTerritory/C=$Country"
    SANAsParameter = '"' + "subjectAltName=$EmailAddress" + '"'
    SANAsFilename  = "$SubjectAlternativeNameReplacementPattern -f $EmailAddress"
  }
}

function Get-CertificateSecurityDNFilePath {
  param(
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $DNSubject
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    # BaseFileName mustinclude an extension
    [ValidateScript({ Split-Path $_ -Extension })]
    $BaseFileName
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $OutDirectory
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType leaf })]
    [string] $CrossReferenceFilePath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
  )
  # [Replace invalid filename chars](https://stackoverflow.com/questions/67884618/replace-invalid-filename-chars) accepted answer by
  $pattern = '[' + ([System.IO.Path]::GetInvalidFileNameChars() -join '').Replace('\', '\\') + ']+'
  $DNFileName = [regex]::Replace("$($DNSubject.AsFileName)-$BaseFileName", $pattern, '-')
  # get the crossreferences from persistence
  # ToDo: Add Force paramter, whatif, etc,
  $crossreferences = Get-Content -Path $CrossReferenceFilePath -Encoding $encoding | ConvertFrom-Json -AsHashtable
  # If the DNFilename already exist in the cross reference file, replace it, else add a new crossreference to a new guid
  # Associate a GUID to the DNFilename, and use the suffix from the BaseFileName
  $crossreferences[$DNFileName] = $(Join-Path $OutDirectory $(New-Guid)) + $(Split-Path $BaseFileName -Extension)
  # update the crossreferences in presistence
  $crossreferences | ConvertTo-Json | Out-File -FilePath $CrossReferenceFilePath -Encoding $Encoding
  # return the obsfucated DNFilePath
  $crossreferences[$DNFileName]
}

Function New-EncryptionKeyPassPhraseFile {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType 'Container' })]
    [string] $PassPhrasePath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # ToDo: Put a much larger word list in the database and extract 100 possible words form the DB
    # Word list
    $words = @(
      'rabbit', 'peccary', 'colt', 'anteater',
      'meerkat', 'eagle', 'owl', 'cow', 'turtle', 'bull',
      'baselisk', 'snake', 'lizzard', 'panda', 'bear', 'pig',
      'lion', 'tiger', 'bunny', 'wolf', 'deer', 'pronghorn',
      'fish', 'rabbit', 'gorilla', 'puma', 'mustang', 'sheep',
      'wolverine', 'hyena', 'beaver', 'rooster', 'ox', 'frog'
    )
    $randomwords = @();
  }

  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # get 10 random words
    1..10 | % { $randomwords += Get-Random -InputObject $words }
    $randomwords | Out-File -Encoding $Encoding -FilePath $PassPhrasePath
    Write-PSFMessage -Level Debug -Message "RandomWords = $( $randomwords -join ' ')"
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion New-EncryptionKeyPassPhraseFile


Function New-EncryptedPrivateKey {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType 'Container' })]
    [string] $EncryptedPrivateKeyPath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType 'Container' })]
    [string] $EncryptionKeyPassPhrasePath
    , [ValidateSet(1024, 1536, 2048, 4096)]
    [int16] $KeySize
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
  }

  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # openssl must be in the path
    # ToDo: lots of error handling
    # ToDo: use DH encryption algorithm
    # ToDo: Output format in .pem
    openssl genpkey -quiet -algorithm RSA -pass file:$EncryptionKeyPassPhrasePath -pkeyopt rsa_keygen_bits:$KeySize -out $EncryptedPrivateKeyPath >$null
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}

Function New-CertificateRequest {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet' )]
  param (
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [object] $DNSubject
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string] $CertificateRequestConfigPath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType 'Container' })]
    [string] $CertificateRequestPath
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
  PROCESS {  }
  #endregion ProcessBlock
  #region EndBlock
  END {
    # ToDo: validate Subject and SubjectAlternativeName
    if ($PSCmdlet.ShouldProcess($null, "Create new CertificateRequest '$CertificateRequestPath' from '$CertificateRequestConfigPath' using subject '$($DNSubject.AsParameter)' and ")) {
       openssl req -new -batch -config $CertificateRequestConfigPath -sha256 -subj $($DNSubject.AsParameter)  -addext $($DNSubject.SANAsParameter) -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificateRequestPath
      # ToDo: add SAN
      # openssl req -new -batch -config $CertificateRequestConfigPath -sha256 -subj /CN=utat022/OU=Development/O=ATAPUtilities.org/L=HD/ST=UT/C=US  -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificateRequestPath
#      openssl req -new -batch -config $CertificateRequestConfigPath -subj $(($DNSubject).AsParameter) -sha256 -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificateRequestPath
      # openssl req -new -batch -config $CertificateRequestConfigPath -subj /CN=utat022/OU=Development/O=ATAPUtilities.org/L=HD/ST=UT/C=US -addext "subjectAltName=DNS:utat022" -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -out $CertificateRequestPath
      #ToDo:Fix this
      #(((Get-Content $CertificateRequestConfigPath) -replace 'Subject = .*', ('Subject = "' + $Subject + '"')) -replace '%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}.*', ('%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}' + $SubjectAlternativeName + '"')) |
      # Out-File -Path $CertificateRequestPath -Encoding $Encoding
    }
    Write-PSFMessage -Level Debug -Message 'Ending Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}

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
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CertificateRequestPath
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

    openssl req -x509 -new -subj $($DNSubject.AsParameter) -des3 -key $EncryptedPrivateKeyPath -passin file:$EncryptionKeyPassPhrasePath -passout file:$EncryptionKeyPassPhrasePath -sha256 -days $internalValidityDays -copy_extensions copyall -out $CertificatePath
    # openssl req -x509 -new -config $CertificateRequestPath -des3 -key  $EncryptedPrivateKeyPath -passout file:$EncryptionKeyPassPhrasePath -sha256 -days $internalValidityDays -out $CertificatePath
    #openssl req -x509 -in $CertificateRequestPath -des3 -key $EncryptedPrivateKeyPath -passout file:$EncryptionKeyPassPhrasePath -sha256 -days $internalValidityDays -out $CertificatePath
    #openssl genpkey -quiet -algorithm RSA -pass file:$EncryptionKeyPassPhrasePath -pkeyopt rsa_keygen_bits:$KeySize -out $EncryptedPrivateKeyPath >$null
    #openssl genrsa -des3 -passout file:$EncryptionKeyPassPhrasePath -pubout -outform PEM -out $EncryptedPrivateKeyPath $KeySize

    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}

$DNSubject = New-Object PSObject -Property @{
  CN                                       = 'utat022'
  EmailAddress                             = 'SecurityAdminsList@ATAPUtilities.org'
  Country                                  = 'US'
  StateOrTerritory                         = 'UT'
  Locality                                 = 'HD'
  Organization                             = 'ATAPUtilities.org'
  OrganizationUnit                         = 'Development'
  SubjectReplacementPattern                = 'CN="{0}",OU="{1}",O="{2}",L="{3}",ST="{4},C="{5}"'
  SubjectAlternativeNameReplacementPattern = 'E="{0}"'
} | Get-DNSubject

$KeySize = 2048
$ValidityPeriod = 1
$ValidityPeriodUnits = 'years'
$Encoding = 'UTF8'

$EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'RootCertificateAuthorityCertificatePassPhraseFile.txt' -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']]
New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath

# ToDO: DH Parameters

$EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificateEncryptedPrivateKey.pem' -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
New-EncryptedPrivateKey -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -KeySize $KeySize

$CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']] 'CATemplate.cnf'
$CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$CertificateRequestPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificateRequest.cer' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']]
# ToDo: Add ValidityPeriod and ValidityPeriodUnits
New-CertificateRequest -DNSubject $DNSubject -CertificateRequestConfigPath $CertificateRequestConfigPath -CertificateRequestPath $CertificateRequestPath
if (-not (Test-Path -Path $CertificateRequestPath -PathType Leaf)) {
  Write-PSFMessage -Level Important -Message "CertificateRequestPath = $CertificateRequestPath"
    throw "New-CertificateRequest failed to create the CertificateRequest at $CertificateRequestPath"
}
$CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$CertificatePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificate.crt' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']]

# ToDo: move ValidityPeriod and ValidityPeriodUnits into the CSR
Write-PSFMessage -Level Critical -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
      EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath
      EncryptedPrivateKeyPath     = $EncryptedPrivateKeyPath
      CertificateRequestPath      = $CertificateRequestPath
      CertificatePath             = $CertificatePath
    }))

New-CACertificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestPath $CertificateRequestPath -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -KeySize $Keysize -CertificatePath $CertificatePath


# Function New-Certificate {
#   #region Parameters
#   [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
#   param (
#     [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
#     [ValidateScript({ Test-Path $_ -PathType Leaf })]
#     [string] $EncryptedPrivateKeyPath
#     , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
#     [ValidateScript({ Test-Path $_ -PathType Leaf })]
#     [string] $EncryptionKeyPassPhrasePath
#     , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
#     [ValidateScript({ Test-Path $_ -PathType Leaf })]
#     [string] $CertificateRequestPath
#     # ToDo: figure out better validation for ValidityPeriod and ValidityRange
#     , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
#     [ValidateRange(1, 1000)]
#     [int16] $ValidityPeriod
#     , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
#     [ValidateSet('days', 'weeks', 'years')]
#     [string] $ValidityPeriodUnits
#     , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
#     [ValidateScript({ Test-Path $(Split-Path $_) -PathType Container })]
#     [string] $CertificatePath
#   )
#   #endregion Parameters
#   #region BeginBlock
#   BEGIN {
#     Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
#     # Convert vaility period/units into days
#     $internalValidityDays =
#     switch ($ValidityPeriodUnits) {
#       'days' { $ValidityPeriod }
#       'weeks' { $ValidityPeriod * 7 }
#       'years' { $ValidityPeriod * 365 }
#     }

#     # SSL Certificates are capped at 365 days, enforce that here
#     #if () {}
#     # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
#   }

#   #endregion BeginBlock
#   #region ProcessBlock
#   PROCESS {}
#   #endregion ProcessBlock
#   #region EndBlock
#   END {
#     # openssl must be in the path
#     # ToDo: lots of error handling
#     openssl req -x509 -in $CertificateRequestPath -des3 -key $EncryptedPrivateKeyPath -passout file:$EncryptionKeyPassPhrasePath -sha256 -days $internalValidityDays -out $CertificatePath
#     #openssl genpkey -quiet -algorithm RSA -pass file:$EncryptionKeyPassPhrasePath -pkeyopt rsa_keygen_bits:$KeySize -out $EncryptedPrivateKeyPath >$null
#     #openssl genrsa -des3 -passout file:$EncryptionKeyPassPhrasePath -pubout -outform PEM -out $EncryptedPrivateKeyPath $KeySize

#     Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
#   }
#   #endregion EndBlock
# }

### The SSL Certificate


# $Subject = New-Object PSObject -Property @{
#   CN                                       = 'WinRMHTTPS'
#   EmailAddress                             = 'SecurityAdminsList@ATAPUtilities.org'
#   Country                                  = 'US'
#   StateOrTerritory                         = 'UT'
#   Locailty                                 = 'HD'
#   Organization                             = 'ATAPUtilities.org'
#   OrganizationUnit                         = 'Development'
#   SubjectReplacementPattern                = 'CN="{0}",OU="{1}",O="{2}",L="{3}",ST="{4},C="{5}"'
#   SubjectAlternativeNameReplacementPattern = 'E="{0}"'
# } | Get-DNSubject


# $EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
# $EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'WinRMHTTPSCertificatePassPhraseFile.txt' -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']]
# New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath

# # ToDO: DH Parameters

# $EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
# $EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'WinRMHTTPSCertificateEncryptedPrivateKey.pem' -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
# New-EncryptedPrivateKey -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -KeySize $KeySize

# $CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']] 'SSLTemplate.cnf'
# $CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
# $CertificateRequestPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'WinRMHTTPSCertificateRequest.csr' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']]
# # ToDo: Add ValidityPeriod and ValidityPeriodUnits
# New-CertificateRequest -DNSubject $DNSubject -CertificateRequestConfigPath $CertificateRequestConfigPath -CertificateRequestPath $CertificateRequestPath

# $CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
# $CertificatePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'WinRMHTTPSCertificate.crt' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']]


# $EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]

# $EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'RootCertificateAuthorityCertificatePassPhraseFile.txt' -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']]

# New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath

# $KeySize = 2048
# $EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
# $EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'RootCertificateAuthorityCertificateEncryptedPrivateKey.pem' -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
# New-EncryptedPrivateKey -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -KeySize $KeySize


#}

$ValidityPeriod = 1
$ValidityPeriodUnits = 'years'

#. rotateCa -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits
