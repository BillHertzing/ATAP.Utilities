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
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet' )]
  param (
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]

    [string] $Subject
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [string] $SubjectAlternativeName
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
    if ($PSCmdlet.ShouldProcess($null, "Create new CertificateRequest '$CertificateRequestPath' from '$CertificateRequestConfigPath' using subject '$Subject' and ")) {
        (((Get-Content $CertificateRequestConfigPath) -replace 'Subject = .*', ('Subject = "' + $Subject + '"')) -replace '%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}.*', ('%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}' + $SubjectAlternativeName + '"')) |
      Out-File -Path $CertificateRequestPath -Encoding $Encoding
    }
    Write-PSFMessage -Level Debug -Message 'Ending Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion Name
#############################################################################


