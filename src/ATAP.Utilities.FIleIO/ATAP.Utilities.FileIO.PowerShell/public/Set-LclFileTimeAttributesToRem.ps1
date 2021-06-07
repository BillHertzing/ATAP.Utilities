#############################################################################
#region Set-LclFileTimeAttributesToRem
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
  $remoteFiles = Get-ChildItem -r -path \\ncat016\Dropbox\Photo
  $localFiles = Get-ChildItem -r -path C:\Dropbox\Photo
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Set-LclFileTimeAttributesToRem {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $InDir
    , [alias('RemoteFiles')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $InFn1
    , [alias('LocalFiles')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $InFn2
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $OutDir
    , [alias('OutFNBusinessName1')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $OutFn1
    , [alias('OutFNBusinessName2')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $OutFn2
  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

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
    $smaller = 0
    if ($remoteFiles.length -gt $localFiles.length) { $smaller = $localFiles.length } else { $smaller = $remoteFiles.length }

    for ($i = 0; $i -lt $smaller; $i++) {
      if ($localFiles[$i].basename -eq $remoteFiles[$i].basename) {
        if ($localFiles[$i].CreationTimeUtc -ne $remoteFiles[$i].CreationTimeUtc) {
          if ($PSCmdlet.ShouldProcess("$remoteFiles[$i].name", 'Copy CreationTimeUTC ')) {
            $localFiles[$i].CreationTimeUtc = $remoteFiles[$i].CreationTimeUtc
          }
        }
        if ($localFiles[$i].LastWriteTimeUtc -ne $remoteFiles[$i].LastWriteTimeUtc) {
          if ($PSCmdlet.ShouldProcess("$remoteFiles[$i].name", 'Copy LastWriteTimeUtc ')) {
            $localFiles[$i].LastWriteTimeUtc = $remoteFiles[$i].LastWriteTimeUtc
          }
        }
      }
      else {
        Write-Verbose "at index $i, localFileBasename = $localFiles[$i].basename, remoteFileBasename = $remoteFiles[$i].basename"
      }
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Set-LclFileTimeAttributesToRem
#############################################################################



