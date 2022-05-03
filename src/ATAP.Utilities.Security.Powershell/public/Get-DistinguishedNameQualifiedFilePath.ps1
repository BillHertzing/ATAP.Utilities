#############################################################################
#region Get-DistinguishedNameQualifiedFilePath
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
Function Get-DistinguishedNameQualifiedFilePath {
  #region Parameters
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern')]
  param(
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [alias('DN', 'DNH')]
    $DistinguishedNameHash
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    # BaseFileName must include an extension
    [ValidateScript({ Split-Path $_ -Extension })]
    $BaseFileName
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $OutDirectory
    # ToDo: make the use of a crossreference path a different parameterset
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $false, ParameterSetName = 'CrossReferences')]
    [ValidateScript({ Test-Path $_ -PathType leaf })]
    [string] $CrossReferenceFilePath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # [Replace invalid filename chars](https://stackoverflow.com/questions/67884618/replace-invalid-filename-chars) accepted answer by
    $pattern = '[' + ([System.IO.Path]::GetInvalidFileNameChars() -join '').Replace('\', '\\') + ']+'
    $DNFileName = [regex]::Replace("$($DNHash.DNAsFileName)-$BaseFileName", $pattern, '-')
    $DNFileFullPath = ''
    # return either the escaped DNFilename or the obfuscated (guid) filename
    switch ($PSCmdlet.ParameterSetName) {
      'DefaultParameterSetNameReplacementPattern' {
        $DNFileFullPath = Join-Path $OutDirectory $DNFileName
      }
      'CrossReferences' {
        # ToDo: Add Force paramter, whatif, etc,
        # get the crossreferences from persistence
        $crossreferences = Get-Content -Path $CrossReferenceFilePath -Encoding $encoding | ConvertFrom-Json -AsHashtable
        # If the DNFilename already exist in the cross reference file, replace it, else add a new crossreference to a new guid
        # Associate a GUID to the DNFilename, and use the suffix from the BaseFileName
        $crossreferences[$DNFileName] = $(Join-Path $OutDirectory $(New-Guid)) + $(Split-Path $BaseFileName -Extension)
        # update the crossreferences in presistence
        $crossreferences | ConvertTo-Json | Out-File -FilePath $CrossReferenceFilePath -Encoding $Encoding
        # Return the obsfucated DNFilePath
        $DNFileFullPath = $crossreferences[$DNFileName]
      }
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $DNFileFullPath
  }
  #endregion EndBlock
}
#endregion Get-DistinguishedNameQualifiedFilePath
#############################################################################
