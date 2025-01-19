#############################################################################
#region New-DocFilesIfNotPresent
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
Function New-DocFilesIfNotPresent {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  [parameter(mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DocsPath
  , [parameter(mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string[]]$DocFileNames
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  # PROCESS {
  #   #
  # }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock 
  ########################################
  END {
	   Write-Verbose "DocsPath is $DocsPath, error if not present"
    if (!Test-Path -Path $DocsPath) { throw "$DocsPath is not present" }
    $DocFileNames | ForEach-Object { $dfn = $_
      $dfp = Join-Path $DocsPath $dfn
      if (Test-Path -Path $dfp) {
        Write-Verbose "DocFullPath $dfp already exists"
      } else {
        if ($PSCmdlet.ShouldProcess("$dfp", 'Create')) {
          Write-Verbose "Creating empty file $dfp, utf-8 encoding, no BOM"
          [io.file]::WriteAllText($dfp, '', (New-Object System.Text.UTF8Encoding($false)))
        }
      }
    }

    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion New-DocFilesIfNotPresent
#############################################################################
