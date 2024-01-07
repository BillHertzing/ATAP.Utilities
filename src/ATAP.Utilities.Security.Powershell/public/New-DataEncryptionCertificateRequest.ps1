#############################################################################
#region New-DataEncryptionCertificateRequest
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
Function New-DataEncryptionCertificateRequest {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName ='DefaultParameterSetNameReplacementPattern'  )]
  param (
    [string] $Subject
    , [string] $SubjectAlternativeName
    , [ValidateScript({ Test-Path $_ })]
    [string] $DataEncryptionCertificateRequestConfigPath
    ,
    [string] $DataEncryptionCertificateRequestPath
    , [switch] $Force
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # $DebugPreference = 'SilentlyContinue'
    # $results = @{}
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    #
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    # ToDo: validate Subject and SubjectAlternativeName
    # Does the parent path for the new certificate path exist
    $parentPath = (Split-Path -Path $DataEncryptionCertificateRequestPath -Parent)
    if (-not (Test-Path $parentPath )) {
      if ($force) {
        if ($PSCmdlet.ShouldProcess($null, 'New-Item -ItemType Directory -Force -Path $parentPath')) {
          # If the parent path for the new certificate path does not exist at all, create it if -Force is true, else fail
          New-Item -ItemType Directory -Force -Path $parentPath >$null
        }
      }
      else {
        Throw "Part(s) of the parent of the DataEncryptionCertificateRequestPath do not exist, use -Force to create them: $parentPath"
      }
    }
    if ($PSCmdlet.ShouldProcess($null, "Create new CertificateRequest '$DataEncryptionCertificateRequestPath' from '$DataEncryptionCertificateRequestConfigPath' using subject '$Subject'")) {
        (((Get-Content $DataEncryptionCertificateRequestConfigPath) -replace 'Subject = .*', ('Subject = "' + $Subject + '"')) -replace '%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}.*', ('%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}' + $SubjectAlternativeName + '"')) |
      Set-Content -Path $DataEncryptionCertificateRequestPath # -Encoding [System.Text.Encoding]::UTF8  default value for my powershelll, but localization may affect this
    }
    Write-PSFMessage -Level Debug -Message 'Ending Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion FunctionName
#############################################################################


