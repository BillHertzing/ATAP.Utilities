#############################################################################
#region New-DistinguishedNameHash
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

function New-DistinguishedNameHash {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern')]
  param(
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [alias('CommonName')]
    $CN
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $emailAddress
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [alias('Country')]
    $C
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [alias('StateOrTerritory')]
    $ST
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [alias('Locality')]
    $L
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [alias('Organization')]
    $O
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [alias('OrganizationUnit')]
    $OU
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Environment
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string[]]$KeyUseage
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $ExtendedKeyUseage
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, ParameterSetName = 'CustomFileNamePattern')]
    $DNAsFileNameReplacementPattern
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, ParameterSetName = 'CustomParameterPattern')]
    $SANAsParameterReplacementPattern
  )
  $outputHash = @{}
  # CommonName is mandatory and always present, so start both the filenams and the paramters with this DN element
  $outputHash['CN'] = $CN
  $DNAsFileName = "CN_$($PSBoundParameters['CN'])"
  $DNAsParameter = "/CN=$CN"
  # The list of the parameters that, if present, must be included in the DNAsfileName and the DNAsParameter
  $x = ('OU', 'O', 'L', 'ST', 'C')
  # ToDo: include DefaultBoundParameters preference variable
  # ToDo: Switch on ParamterSet and use a custom filename pattern and /or custom parameter pattern, but beware security implications
  switch ($PSCmdlet.ParameterSetName) {
    'DefaultParameterSetNameReplacementPattern' {
      $x | % {
        if (($PSBoundParameters.ContainsKey($_)) -and (-not [string]::IsNullOrEmpty($PSBoundParameters[$_]))) {
          $outputHash[$_] = $PSBoundParameters[$_]
          $DNAsFileName += "__$_" + "_$($PSBoundParameters[$_])"
          $DNAsParameter += "/$($_)=$($PSBoundParameters[$_])"
        }
      }
      # if $environment is present as a bound parameter, incorporate it into filename
      # ToDo: replace hardcoded 'production' with cross-platform I18N aware string
      if (($PSBoundParameters.ContainsKey('Environment')) -and (-not [string]::IsNullOrEmpty('Environment')) -and (-not $($PSBoundParameters['Environment'] -eq 'Production'))) {
        $outputHash['Environment'] = $PSBoundParameters['Environment']
        $DNAsFileName += "_$($PSBoundParameters['Environment'])"
      }
    }
    'CustomFileNamePattern'{
      throw "Not Implemented"
    }
  }

  $propertyHash =
  @{
    DNAsFileName   = $DNAsFileName
    DNAsParameter  = $DNAsParameter
    SANAsParameter = '"' + "subjectAltName=$EmailAddress" + '"'
    SANAsFilename  = "$SANAsParameterReplacementPattern -f $EmailAddress"
  }
  # Add optional properties
  if ($KeyUseage) {
    $propertyHash['KeyUseage'] = "keyUsage=$($KeyUseage -join ',')"
  }
  if ($ExtendedKeyUseage) {
    $propertyHash['ExtendedKeyUseage'] = "extendedKeyUsage=$($ExtendedKeyUseage -join ',')"
  }
  # return the hash as a PSObject
  New-Object PSObject -Property $($propertyHash + $outputHash)
}

#endregion New-DistinguishedNameHash
#############################################################################

# For testing
# $DNHash = New-Object PSObject -Property @{
#   CN                               = 'ATAPUtilities.org'
#   EmailAddress                     = 'SecurityAdminsList@ATAPUtilities.org'
#   Country                          = 'US'
#   StateOrTerritory                 = ''
#   Locality                         = ''
#   Organization                     = 'ATAPUtilities.org'
#   OrganizationUnit                 = ''
#   Environment                      = $Env:Environment
#   DNAsFileNameReplacementPattern   = 'CN="{$CN}",O="{$Organization}",C="{$Country}"'
#   SANAsParameterReplacementPattern = 'E="{0}"'
#   #KeyUseage                                = @('critical', 'cRLSign', 'digitalSignature', 'keyCertSign')
#   #ExtendedKeyUseage                        = 'CA:TRUE'
#   # ExtendedKeyUseage = @('critical','codeSigning')
# } | New-DistinguishedNameHash
