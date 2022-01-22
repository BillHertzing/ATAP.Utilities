
#############################################################################
#region Copy-FileTimeAttributes
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
  $sourceFiles = Get-ChildItem -r -path C:\Dropbox\Photo
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Copy-FileTimeAttributes {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [alias('source')]
    [parameter(
      Mandatory = $true
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $True
    )]
    [ValidateNotNullOrEmpty()]
    $sourceFiles
    , [alias('target')]
    [parameter(
      Mandatory = $true
      , ValueFromPipeline = $False
      , ValueFromPipelineByPropertyName = $True
    )]
    [ValidateNotNullOrEmpty()]
    $targetFiles
    , [alias('Attr')]
    [parameter(
      Mandatory = $false
      , ValueFromPipelineByPropertyName = $True
    )]
    $Attributes = @('CreationTimeUtc', 'LastWriteTimeUtc')
  )
  #endregion FunctionParameters

  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    ########################################
    #region local private function
    function Private:Get-FileInfo {
      [CmdletBinding(SupportsShouldProcess = $true)]
      param (
        $source
      )
      if ($source -is [string]) {
        Get-Item -Path $source
      }
      elseif ($source -is [System.IO.DirectoryInfo]) {
        Write-Warning "Copy-FileTimeAttributes  - Directories are not supported. Skipping $source."
        continue
      }
      elseif ($source -is [System.IO.FileInfo]) {
        $source
      }
      else {
        Write-Warning "Copy-FileTimeAttributes - Only files are supported. Skipping $source."
        continue
      }
    }

    function Private:Copy-Attrs {
      [CmdletBinding(SupportsShouldProcess = $true)]
      param (
        $sourceFileInfo
        , $targetFileInfo
        , $Attributes
      )
      if ($sourceFileInfo.CreationTimeUtc -ne $targetFileInfo.CreationTimeUtc) {
        if ($PSCmdlet.ShouldProcess("Would copy CreationTimeUTC from $sourceFileInfo.fullname to $targetFileInfo.fullname")) {
          $sourceFileInfo.CreationTimeUtc = $targetFileInfo.CreationTimeUtc
        }
      }
      if ($sourceFileInfo.LastWriteTimeUtc -ne $targetFileInfo.LastWriteTimeUtc) {
        if ($PSCmdlet.ShouldProcess("Would copy LastWriteTimeUtc from $sourceFileInfo.fullname to $targetFileInfo.fullname")) {
          $sourceFileInfo.LastWriteTimeUtc = $targetFileInfo.LastWriteTimeUtc
        }
      }
    }
    #endregion local private function

  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # ToDo: convert to a pipeline cmdlet
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    if ((($sourceFiles -is [String]) -or ($sourceFiles -is [System.IO.FileInfo])) -and (($targetFiles -is [String]) -or ($targetFiles -is [System.IO.FileInfo]))) {
      $sFileInfo = Get-FileInfo $sourceFiles
      $tFileInfo = Get-FileInfo $targetFiles
      copy-Attrs $sFileInfo $tFileInfo $Attributes
    }
    elseif (($sourceFiles -is [Object[]]) -and ($targetFiles -is [Object[]])) {
      $smaller = 0
      if ($targetFiles.Count -gt $sourceFiles.Count) { $smaller = $sourceFiles.Count } else { $smaller = $targetFiles.Count }
      for ($i = 0; $i -lt $smaller; $i++) {
        $sFileInfo = Get-FileInfo $sourceFiles[$i]
        $tFileInfo = Get-FileInfo $targetFiles[$i];
        copy-Attrs $sFileInfo $tFileInfo $Attributes
      }
    }
    else {
      # ToDo: improve warning, show what's what
      Write-Warning 'Copy-FileTimeAttributes source and target must both be strings or must both be arrays'
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Copy-FileTimeAttributes
#############################################################################

