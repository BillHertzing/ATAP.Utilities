#############################################################################
#region Format-GroupLikeLines
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Path
  Specifies the path where searching should start. May be a string or an array in the form (p1[,p2][,p3]...)
.PARAMETER FileNamePattern
  Specifies the regex pattern to match filenames against. May be a string or an array in the form (r1[,r2][,r3]...)

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
Function Format-GroupLikeLines {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Parameter set to support LiteralPath
    [alias('InObj')]
    [parameter(Mandatory= $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] $InputObject
    # ToDo: Make this an array of property names, and validate the acceptable ones
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)][string] $FileGroupProperty
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    $DebugPreference = 'Continue'

    # default values for settings
    $settings = @{
      InputObject    = ''
      FileGroupProperty              = 'Line'
    }

    # Things to be initialized after settings are processed
    if ($InputObject) { $Settings.InputObject = $InputObject }
    if ($FileGroupProperty) { $Settings.FileGroupProperty = $FileGroupProperty }

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

  (
    (($settings.InputObject).results) |
    %{
        $FileTuple=$_.key;
        $ValueList = $_.value;
        $ValueList |
          %{Select-Object -InputObject $_ -property LineNumber,Line,@{name='FileName';expr={$FileTuple.fullname}}}
      } |
      Group-Object -Property Line |Sort-Object -Property Count -Descending
    ) | convertto-json -Depth 4
    #endregion FunctionEndBlock
  }
#endregion Format-GroupLikeLines
}
#############################################################################
